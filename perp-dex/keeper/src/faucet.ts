import { ethers } from "ethers";
import { config } from "./config.js";
import { log } from "./logger.js";
import { getTxManager } from "./txManager.js";

const TAG = "faucet";

const AMOUNT_ZUSDC = ethers.parseUnits("1000", 18);
const COOLDOWN_MS = 24 * 60 * 60 * 1000; // 24 hours
const RECEIPT_TIMEOUT_MS = 45_000;

// In-memory cooldown map: normalised wallet → timestamp of last claim
const claimCooldowns = new Map<string, number>();

const ERC20_ABI = [
  "function transfer(address to, uint256 amount) returns (bool)",
  "function balanceOf(address account) view returns (uint256)",
];

// Lazy-init provider/wallet/contract (reuse across calls)
let _provider: ethers.JsonRpcProvider | null = null;
let _wallet: ethers.Wallet | null = null;
let _token: ethers.Contract | null = null;
let _runExclusive: (<T>(fn: () => Promise<T>) => Promise<T>) | null = null;
let _nonceManager: import("./nonceManager.js").NonceManager | null = null;

function getInstances() {
  if (!_provider) {
    _provider = new ethers.JsonRpcProvider(config.rpcUrl, {
      chainId: config.chainId,
      name: "polkadot-hub-testnet",
    });
  }
  const faucetKey = (process.env.FAUCET_PRIVATE_KEY ?? config.keeperPrivateKey) as `0x${string}`;
  if (!_wallet) {
    // Use shared tx manager/queue to avoid nonce collisions if faucetKey is also keeper key.
    const mgr = getTxManager(faucetKey);
    _wallet = mgr.wallet.connect(_provider);
    _runExclusive = mgr.runExclusive;
    _nonceManager = mgr.nonceManager;
  }
  if (!_token) {
    _token = new ethers.Contract(config.tokenAddress, ERC20_ABI, _wallet);
  }
  return { provider: _provider, wallet: _wallet, token: _token, runExclusive: _runExclusive!, nonceManager: _nonceManager! };
}

/** Check cooldown for a wallet. Returns { ok, remainingMs }. */
export function checkCooldown(walletAddress: string): { ok: boolean; remainingMs: number } {
  const key = walletAddress.toLowerCase();
  const last = claimCooldowns.get(key);
  if (!last) return { ok: true, remainingMs: 0 };
  const elapsed = Date.now() - last;
  if (elapsed >= COOLDOWN_MS) return { ok: true, remainingMs: 0 };
  return { ok: false, remainingMs: COOLDOWN_MS - elapsed };
}

/** Transfer 1000 zUSDC to the target wallet. Enforces 24h cooldown. */
export async function sendZUSDC(toAddress: string): Promise<{
  txHash: string;
  amount: string;
  faucetWallet: string;
}> {
  const key = toAddress.toLowerCase();

  const cooldown = checkCooldown(key);
  if (!cooldown.ok) {
    const h = Math.ceil(cooldown.remainingMs / 3_600_000);
    throw new Error(`Rate limit: this wallet already claimed zUSDC within 24h. Try again in ~${h}h.`);
  }

  const { token, wallet } = getInstances();

  log.info(TAG, `Sending 1000 zUSDC`, { to: toAddress, from: wallet.address });

  // Validate that faucet wallet actually has enough balance
  const balance: bigint = await (token.balanceOf as (...args: unknown[]) => Promise<bigint>)(wallet.address);
  if (balance < AMOUNT_ZUSDC) {
    throw new Error("Faucet wallet has insufficient zUSDC balance. Please contact the admin.");
  }

  const { runExclusive, provider, nonceManager } = getInstances();

  const tx: ethers.TransactionResponse = await runExclusive(async () => {
    const baseGasPrice = BigInt(await provider.send("eth_gasPrice", []));

    // Polkadot EVM tx-pool can be strict; keep retrying with larger bumps.
    for (let attempt = 1; attempt <= 5; attempt++) {
      const bumpPct = 40n * BigInt(attempt - 1);
      const gasPrice = baseGasPrice + (baseGasPrice * bumpPct) / 100n;

      try {
        // Re-sync nonce on each attempt to avoid RPC pending-nonce inconsistencies.
        if (attempt > 1) await nonceManager.resetNonce();
        const nonce = await nonceManager.acquireNonce();
        return await (token.transfer as (...args: unknown[]) => Promise<ethers.TransactionResponse>)(toAddress, AMOUNT_ZUSDC, {
          nonce,
          gasLimit: 120_000n,
          gasPrice,
          type: 0,
        });
      } catch (err) {
        const msg = err instanceof Error ? err.message.toLowerCase() : String(err).toLowerCase();
        const shouldResyncNonce =
          msg.includes("priority is too low") ||
          msg.includes("invalid transaction") ||
          msg.includes("transaction already imported") ||
          msg.includes("already imported") ||
          msg.includes("temporarily banned") ||
          msg.includes("nonce too low");

        log.warn(TAG, `Faucet transfer attempt ${attempt}/5 failed`, {
          to: toAddress,
          gasPrice: gasPrice.toString(),
          error: err instanceof Error ? err.message : String(err),
        });

        // If this tx was rejected before broadcast, roll back nonce.
        nonceManager.rollback();

        if (shouldResyncNonce) {
          await nonceManager.resetNonce();
        }

        if (attempt === 5) throw err;
        await new Promise((r) => setTimeout(r, 2000 * attempt));
      }
    }

    throw new Error("Exhausted faucet retry attempts");
  });

  log.info(TAG, `zUSDC transfer broadcast`, { txHash: tx.hash, to: toAddress });

  const { provider: receiptProvider } = getInstances();
  const startedAt = Date.now();
  let receipt: ethers.TransactionReceipt | null = null;
  while (Date.now() - startedAt < RECEIPT_TIMEOUT_MS) {
    try {
      receipt = await receiptProvider.getTransactionReceipt(tx.hash);
      if (receipt) break;
    } catch {
      // keep polling
    }
    await new Promise((r) => setTimeout(r, 2500));
  }

  if (receipt && receipt.status !== 1) {
    throw new Error("Transfer transaction reverted on-chain.");
  }

  // Mark cooldown only after confirmed success
  // If receipt is still pending after timeout, we still set cooldown to avoid duplicate sends.
  claimCooldowns.set(key, Date.now());

  log.action(TAG, receipt ? `1000 zUSDC confirmed` : `1000 zUSDC broadcast (awaiting confirm)`, {
    to: toAddress,
    txHash: tx.hash,
    block: receipt?.blockNumber ?? "pending",
  });

  return {
    txHash: tx.hash,
    amount: "1000",
    faucetWallet: wallet.address,
  };
}
