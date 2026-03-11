# Zenit Perpetual DEX - Frontend

Giao diện web cho Perpetual DEX, lấy cảm hứng từ GMX Interface.

## Yêu cầu

- Node.js 18+
- Hardhat node đang chạy (cho localhost)

## Cài đặt

```bash
cd frontend
npm install
```

## Chạy

### 1. Khởi động Hardhat node (terminal 1)

```bash
cd ..
npm run node
```

### 2. Deploy contracts lên localhost (terminal 2)

```bash
npm run deploy -- --network localhost
```

Sau khi deploy, copy địa chỉ contracts vào file `.env`:

```
VITE_DEX_ADDRESS=0x...
VITE_TOKEN_ADDRESS=0x...
VITE_REWARD_ADDRESS=0x...
```

### 3. Chạy frontend (terminal 3)

```bash
cd frontend
npm run dev
```

Mở http://localhost:3010

## Cấu hình

- **WalletConnect**: Lấy projectId miễn phí tại https://cloud.walletconnect.com và thêm vào `.env`:
  ```
  VITE_WALLETCONNECT_PROJECT_ID=your_project_id
  ```

- **Contract addresses**: Mặc định dùng địa chỉ từ deploy mặc định. Khi deploy lên localhost, cập nhật trong `.env`.

## Tính năng

- **Trade**: Deposit, Withdraw, Open/Increase/Close Position (Long/Short)
- **Rewards**: Xem và claim reward theo volume giao dịch

## Tech Stack

- React 18 + TypeScript
- Vite
- wagmi + RainbowKit (ví)
- Tailwind CSS
- viem + ethers
