import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../features/home/data/models/token_model.dart';
import '../../../../routes/app_routes.dart';
import '../../../../shared/widgets/layout/bottom_nav_bar.dart';
import '../../../../shared/widgets/layout/detail_header_bar.dart';
import '../../../../shared/widgets/token_selector_bottom_sheet.dart';
import '../../data/models/indicator_model.dart';
import '../widgets/rsi_heatmap_chart.dart';
import '../widgets/rsi_line_chart.dart';
import '../widgets/rsi_tabs_with_signals.dart';
import '../widgets/token_price_section.dart';

class IndicatorDetailScreen extends StatefulWidget {
  final IndicatorModel indicator;

  const IndicatorDetailScreen({super.key, required this.indicator});

  @override
  State<IndicatorDetailScreen> createState() => _IndicatorDetailScreenState();
}

class _IndicatorDetailScreenState extends State<IndicatorDetailScreen> {
  late TokenModel _selectedToken;
  bool _isFavorite = false;

  // Mock token data
  final List<TokenModel> _availableTokens = [
    TokenModel(
      symbol: 'BTC',
      name: 'Bitcoin',
      pair: 'BTCUSDT',
      imageUrl: 'https://cryptologos.cc/logos/bitcoin-btc-logo.png',
      currentPrice: 69285.00,
      priceChange: 1045.00,
      priceChangePercentage: 1.53,
      chartData: List.generate(20, (i) => 65000 + (i * 200).toDouble()),
      lastUpdated: DateTime.now(),
    ),
    TokenModel(
      symbol: 'ETH',
      name: 'Ethereum',
      pair: 'ETHUSDT',
      imageUrl: 'https://cryptologos.cc/logos/ethereum-eth-logo.png',
      currentPrice: 3245.50,
      priceChange: -45.20,
      priceChangePercentage: -1.37,
      chartData: List.generate(20, (i) => 3200 + (i * 10).toDouble()),
      lastUpdated: DateTime.now(),
    ),
    TokenModel(
      symbol: 'BNB',
      name: 'Binance Coin',
      pair: 'BNBUSDT',
      imageUrl: 'https://cryptologos.cc/logos/bnb-bnb-logo.png',
      currentPrice: 425.80,
      priceChange: 12.30,
      priceChangePercentage: 2.97,
      chartData: List.generate(20, (i) => 420 + (i * 2).toDouble()),
      lastUpdated: DateTime.now(),
    ),
  ];

  // Mock signal data
  final List<Map<String, dynamic>> _signals = [
    {'pair': 'BTC/USDT', 'rsi': 23, 'date': '14.02.2026', 'time': '07:23:10'},
    {'pair': 'BTC/USDT', 'rsi': 23, 'date': '14.02.2026', 'time': '07:23:10'},
    {'pair': 'BTC/USDT', 'rsi': 23, 'date': '14.02.2026', 'time': '07:23:10'},
    {'pair': 'BTC/USDT', 'rsi': 23, 'date': '14.02.2026', 'time': '07:23:10'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedToken = _availableTokens[0];
  }

  void _showTokenSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TokenSelectorBottomSheet(
        tokens: _availableTokens,
        selectedToken: _selectedToken,
        onTokenSelected: (token) {
          setState(() {
            _selectedToken = token;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            DetailHeaderBar(title: widget.indicator.title),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Token selector and price
                  _buildTokenPriceSection(),

                  const SizedBox(height: 24),

                  // Header with indicator info
                  _buildTabs(),

                  const SizedBox(height: 24),

                  // Heatmap content
                  Expanded(child: _buildHeatmapTab()),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 1, // Analysis tab
        onTap: (index) {
          if (index == 1) return; // Already on Analysis

          // Navigate to HomeShell with selected tab or AI Chat
          switch (index) {
            case 0:
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
              break;
            case 2:
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(AppRoutes.news, (route) => false);
              break;
            case 3:
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(AppRoutes.aiChat, (route) => false);
              break;
          }
        },
      ),
    );
  }

  Widget _buildTokenPriceSection() {
    return TokenPriceSection(
      selectedToken: _selectedToken,
      isFavorite: _isFavorite,
      onTokenSelectorTap: _showTokenSelector,
      onFavoriteTap: () {
        setState(() {
          _isFavorite = !_isFavorite;
        });
      },
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Heatmap for RSI indicator',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(22, 30, 51, 1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'ADX14',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(22, 30, 51, 1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '30m',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapTab() {
    // Mock RSI token data
    final rsiTokens = [
      RsiTokenPoint(
        symbol: 'BTC',
        imageUrl: 'https://cryptologos.cc/logos/bitcoin-btc-logo.png',
        rsiValue: 85,
        xPosition: 0.3,
        color: const Color(0xFFF59E0B),
      ),
      RsiTokenPoint(
        symbol: 'ETH',
        imageUrl: 'https://cryptologos.cc/logos/ethereum-eth-logo.png',
        rsiValue: 78,
        xPosition: 0.55,
        color: const Color(0xFF627EEA),
      ),
      RsiTokenPoint(
        symbol: 'DOT',
        imageUrl: 'https://cryptologos.cc/logos/polkadot-new-dot-logo.png',
        rsiValue: 52,
        xPosition: 0.15,
        color: const Color(0xFFE6007A),
      ),
      RsiTokenPoint(
        symbol: 'LINK',
        imageUrl: 'https://cryptologos.cc/logos/chainlink-link-logo.png',
        rsiValue: 42,
        xPosition: 0.75,
        color: const Color(0xFF2A5ADA),
      ),
      RsiTokenPoint(
        symbol: 'MATIC',
        imageUrl: 'https://cryptologos.cc/logos/polygon-matic-logo.png',
        rsiValue: 38,
        xPosition: 0.68,
        color: const Color(0xFF8247E5),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // RSI Heatmap Chart
          RsiHeatmapChart(tokens: rsiTokens, height: 500),
          const SizedBox(height: 16),
          // RSI Line Chart
          RsiLineChart(
            rsiData: const [
              45,
              52,
              58,
              65,
              72,
              78,
              75,
              68,
              62,
              55,
              48,
              42,
              38,
              35,
              40,
              48,
              55,
              62,
              68,
              72,
            ],
            height: 180,
            lineColor: const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 16),
          // Over sold / Over bought tabs with signal list
          RsiTabsWithSignals(
            signals: _signals,
            tokenImageUrl: _selectedToken.imageUrl,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
