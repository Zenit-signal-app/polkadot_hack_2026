import { ethers } from "ethers";
import { log } from "./logger.js";

const TAG = "nonce";

/**
 * Thread-safe nonce manager that prevents nonce collisions when multiple
 * transactions are submitted concurrently from the keeper wallet.
 *
 * Strategy:
 * 1. Fetch on-chain nonce on first use (or after a reset)
 * 2. Increment locally for each subsequent tx
 * 3. If a tx fails with "nonce too low", re-sync from chain
 * 4. Mutex ensures only one tx acquires a nonce at a time
 */
export class NonceManager {
  private currentNonce: number | null = null;
  private mutex: Promise<void> = Promise.resolve();
  private provider: ethers.JsonRpcProvider;
  private address: string;

  constructor(provider: ethers.JsonRpcProvider, address: string) {
    this.provider = provider;
    this.address = address;
  }

  async acquireNonce(): Promise<number> {
    return new Promise<number>((resolve, reject) => {
      this.mutex = this.mutex.then(async () => {
        try {
          if (this.currentNonce === null) {
            this.currentNonce = await this.provider.getTransactionCount(
              this.address,
              "pending",
            );
            log.info(TAG, `Synced nonce from chain`, {
              address: this.address.slice(0, 10) + "...",
              nonce: this.currentNonce,
            });
          }

          const nonce = this.currentNonce;
          this.currentNonce++;
          resolve(nonce);
        } catch (err) {
          reject(err);
        }
      });
    });
  }

  /**
   * Call when a tx fails with "nonce too low" or similar.
   * Forces a re-sync from the chain on next acquireNonce().
   */
  async resetNonce(): Promise<void> {
    return new Promise<void>((resolve) => {
      this.mutex = this.mutex.then(async () => {
        try {
          this.currentNonce = await this.provider.getTransactionCount(
            this.address,
            "pending",
          );
          log.warn(TAG, `Nonce reset – re-synced from chain`, {
            nonce: this.currentNonce,
          });
        } catch {
          this.currentNonce = null;
          log.error(TAG, `Nonce reset failed – will re-sync on next acquire`);
        }
        resolve();
      });
    });
  }

  /**
   * Roll back the local nonce by 1 (e.g. when a tx was never broadcast).
   */
  rollback(): void {
    if (this.currentNonce !== null && this.currentNonce > 0) {
      this.currentNonce--;
      log.info(TAG, `Nonce rolled back`, { nonce: this.currentNonce });
    }
  }

  getCurrentNonce(): number | null {
    return this.currentNonce;
  }
}
