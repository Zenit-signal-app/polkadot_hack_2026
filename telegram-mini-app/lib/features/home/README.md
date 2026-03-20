# Token Price Components

## Cấu trúc component

Hệ thống hiển thị giá token real-time được chia thành các component nhỏ như sau:

### 1. Models (`data/models/`)
- **TokenModel**: Model chứa thông tin token (symbol, name, price, chart data)
- **PriceUpdateModel**: Model cho price updates từ socket

### 2. Services (`data/services/`)
- **PriceSocketService**: Service quản lý WebSocket connection để nhận giá real-time
  - `connect()`: Kết nối đến socket server
  - `subscribeToToken()`: Subscribe một token
  - `subscribeToMultipleTokens()`: Subscribe nhiều tokens
  - `disconnect()`: Ngắt kết nối

### 3. Bloc State Management (`presentation/bloc/`)
- **PriceBloc**: Quản lý state của prices và token list
- **PriceEvent**: Các events (ConnectToPriceSocket, SubscribeToToken, PriceUpdated, etc.)
- **PriceState**: State chứa map tokens và connection status

### 4. UI Components (`presentation/widgets/`)

#### a. MiniChartWidget
Component hiển thị chart nhỏ với line chart
```dart
MiniChartWidget(
  data: [100, 102, 101, 105, 103],
  color: Colors.green,
  height: 50,
  width: 80,
)
```

#### b. PriceDisplayWidget
Component hiển thị giá và % thay đổi
```dart
PriceDisplayWidget(
  price: 69285.04,
  priceChangePercentage: -0.31,
  isPriceUp: false,
)
```

#### c. TokenInfoWidget
Component hiển thị icon và thông tin token
```dart
TokenInfoWidget(
  symbol: 'BTC',
  pair: 'BTC / USD',
  imageUrl: 'https://...',
)
```

#### d. TokenPriceCard (Main Component)
Component chính kết hợp tất cả components con
```dart
TokenPriceCard(
  token: tokenModel,
  onTap: () {
    // Handle tap
  },
)
```

## Cách sử dụng

### 1. Setup Bloc
```dart
class _HomeScreenState extends State<HomeScreen> {
  late PriceBloc _priceBloc;

  @override
  void initState() {
    super.initState();
    _priceBloc = PriceBloc();
    
    // Load dữ liệu ban đầu
    _priceBloc.add(const LoadInitialTokens());
    
    // Kết nối socket (optional)
    _priceBloc.add(const ConnectToPriceSocket());
    
    // Subscribe tokens
    _priceBloc.add(const SubscribeToMultipleTokens(['BTCUSDT', 'ETHUSDT']));
  }

  @override
  void dispose() {
    _priceBloc.close();
    super.dispose();
  }
}
```

### 2. Hiển thị UI với BlocBuilder
```dart
BlocBuilder<PriceBloc, PriceState>(
  bloc: _priceBloc,
  builder: (context, state) {
    return ListView.builder(
      itemCount: state.tokenList.length,
      itemBuilder: (context, index) {
        final token = state.tokenList[index];
        return TokenPriceCard(
          token: token,
          onTap: () {
            // Navigate to detail
          },
        );
      },
    );
  },
)
```

### 3. Cấu hình Socket Server

Mặc định socket service sử dụng socket.io protocol. Để kết nối với server của bạn:

```dart
// Trong price_socket_service.dart, thay đổi defaultSocketUrl
static const String defaultSocketUrl = 'wss://your-server.com';
```

Server cần emit event `price_update` với format:
```json
{
  "symbol": "BTCUSDT",
  "price": 69285.04,
  "priceChange": -214.34,
  "priceChangePercentage": -0.31,
  "timestamp": "2026-02-22T..."
}
```

### 4. Thêm/xóa tokens động

```dart
// Thêm token mới
_priceBloc.add(AddToken(newToken));

// Xóa token
_priceBloc.add(const RemoveToken('BTCUSDT'));
```

## Dependencies đã thêm

```yaml
socket_io_client: ^3.0.1  # WebSocket
fl_chart: ^0.70.2         # Chart
equatable: ^2.0.7         # Value equality
intl: ^0.20.0             # Number formatting
```

## Lưu ý

1. **Socket connection**: Hiện tại code đã comment out việc auto-connect socket. Uncomment khi bạn có socket server sẵn sàng.

2. **Mock data**: PriceBloc có sẵn mock data (BTC, ETH) trong `LoadInitialTokens` event để test UI.

3. **Real-time updates**: Khi socket connected và nhận được price_update, Bloc sẽ tự động cập nhật UI.

4. **Performance**: Sử dụng `BlocBuilder` đảm bảo chỉ rebuild khi state thay đổi.

5. **Token images**: Có thể sử dụng URL từ API hoặc assets local. Widget có fallback hiển thị chữ cái đầu nếu không load được image.
