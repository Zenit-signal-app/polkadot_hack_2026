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

### 3. Cập nhật `.env` phía frontend

Sau khi deploy xong, chỉnh file `.env` trong thư mục `frontend` để dùng địa chỉ mới:

```
VITE_PERP_DEX_ADDRESS=0x...
VITE_TOKEN_ADDRESS=0x...
VITE_REWARD_ADDRESS=0x...
VITE_WALLETCONNECT_PROJECT_ID=your_project_id
```

> Mặc định bộ frontend đang đồ mặt `VITE_PERP_DEX_ADDRESS=0xa8de3e548054417e4d918FAC46E990aF623AC7BA`, `VITE_TOKEN_ADDRESS=0x277E42B9454fB36A7Eaa52D4cE332bEF71dd017a`, và `VITE_REWARD_ADDRESS=0x5b218Bf85172a3df8017A3f29322B93B05a4C3C9`.

### 4. Chạy frontend (terminal 3)

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

- **Trade đa thị trường**: Mở, tăng, đóng vị thế Long/Short trên BTCUSD, ETHUSD và DOTUSD mà không ghi đè các thị trường khác; `Position (zUSDC)` tự động tổng hợp margin khi dữ liệu refetch sau giao dịch thành công.
- **Rewards**: Xem và claim reward theo volume giao dịch

## Tech Stack

- React 18 + TypeScript
- Vite
- wagmi + RainbowKit (ví)
- Tailwind CSS
- viem + ethers
