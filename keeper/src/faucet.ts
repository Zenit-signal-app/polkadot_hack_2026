import { ethers } from "ethers";
import { config } from "./config.js";
import { log } from "./logger.js";

const TAG = "faucet";

const AMOUNT_ZUSDC = ethers.parseUnits("1000", 18);
const COOLDOWN_MS = 24 * 60 * 60 * 1000; // 24 hours

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

function getInstances() {
  if (!_provider) {
    _provider = new ethers.JsonRpcProvider(config.rpcUrl, {
      chainId: config.chainId,
      name: "polkadot-hub-testnet",
    });
  }
  const faucetKey = (process.env.FAUCET_PRIVATE_KEY ?? config.keeperPrivateKey) as `0x${string}`;
  if (!_wallet) {
    _wallet = new ethers.Wallet(faucetKey, _provider);
  }
  if (!_token) {
    _token = new ethers.Contract(config.tokenAddress, ERC20_ABI, _wallet);
  }
  return { provider: _provider, wallet: _wallet, token: _token };
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

  const tx: ethers.TransactionResponse = await (token.transfer as (...args: unknown[]) => Promise<ethers.TransactionResponse>)(toAddress, AMOUNT_ZUSDC, {
    gasLimit: 120_000n,
  });

  log.info(TAG, `zUSDC transfer broadcast`, { txHash: tx.hash, to: toAddress });

  const receipt = await tx.wait(1);
  if (!receipt || receipt.status !== 1) {
    throw new Error("Transfer transaction reverted on-chain.");
  }

  // Mark cooldown only after confirmed success
  claimCooldowns.set(key, Date.now());

  log.action(TAG, `1000 zUSDC confirmed`, {
    to: toAddress,
    txHash: receipt.hash,
    block: receipt.blockNumber,
  });

  return {
    txHash: receipt.hash,
    amount: "1000",
    faucetWallet: wallet.address,
  };
}
