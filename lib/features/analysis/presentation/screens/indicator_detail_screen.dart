import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/store/token_store.dart';
import '../../../../core/store/user_store.dart';
import '../../../../features/home/data/models/ohlcv_snapshot_model.dart';
import '../../../../features/home/data/models/token_list_item_model.dart';
import '../../../../features/home/data/models/token_model.dart';
import '../../../../features/home/data/services/price_socket_service.dart';
import '../../../../features/home/data/services/token_service.dart';
import '../../../../routes/app_routes.dart';
import '../../../../shared/widgets/layout/bottom_nav_bar.dart';
import '../../../../shared/widgets/layout/detail_header_bar.dart';
import '../../../../shared/widgets/token_selector_bottom_sheet.dart';
import '../../data/models/indicator_model.dart';
import '../widgets/adx_chart_section.dart';
import '../widgets/overbought_oversold_section.dart';
import '../widgets/rsi_heatmap_section.dart';
import '../widgets/token_price_section.dart';

class IndicatorDetailScreen extends StatefulWidget {
  final IndicatorModel indicator;

  const IndicatorDetailScreen({super.key, required this.indicator});

  @override
  State<IndicatorDetailScreen> createState() => _IndicatorDetailScreenState();
}

class _IndicatorDetailScreenState extends State<IndicatorDetailScreen> {
  late TokenService _tokenService;
  final PriceSocketService _socketService = PriceSocketService();
  StreamSubscription<OhlcvSnapshotMessage>? _socketSubscription;

  late TokenModel _selectedToken;
  bool _isFavorite = false;

  // Timeframe selector — supported values match the API.
  String _timeframe = '15m';

  // Heatmap RSI type selector: 'rsi14' | 'rsi7'
  String _heatmapRsiType = 'rsi14';

  // Token list — loaded from TokenStore cache or API.
  List<TokenModel> _availableTokens = [];

  // Placeholder shown while tokens are loading so the screen doesn't crash.
  static final TokenModel _placeholderToken = TokenModel(
    symbol: 'BTC',
    name: 'BTC',
    pair: 'BTCUSDT',
    imageUrl: '',
    currentPrice: 0,
    priceChange: 0,
    priceChangePercentage: 0,
    chartData: const [],
    lastUpdated: DateTime(2020),
  );

  @override
  void initState() {
    super.initState();
    _selectedToken = _placeholderToken;
    final apiClient = ApiClient()
      ..setAuthToken(context.read<UserStore>().state.accessToken);
    _tokenService = TokenService(apiClient: apiClient);
    _loadAvailableTokens();
    _connectSocket();
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _socketService.dispose();
    super.dispose();
  }

  // ── Token list ───────────────────────────────────────────────────────────────

  /// Loads the token list: uses the already-cached TokenStore if available,
  /// otherwise fetches from the API. After loading, triggers data + price history.
  Future<void> _loadAvailableTokens() async {
    final storeItems = context.read<TokenStore>().state.items;
    List<TokenModel> tokens;

    if (storeItems.isNotEmpty) {
      tokens = storeItems.map(_tokenFromListItem).toList();
    } else {
      try {
        final fetched = await _tokenService.getTokens(limit: 200);
        tokens = fetched.map(_tokenFromListItem).toList();
      } catch (_) {
        // Keep the placeholder so the screen stays usable.
        tokens = [_placeholderToken];
      }
    }

    if (!mounted) return;
    setState(() {
      _availableTokens = tokens;
      _selectedToken = tokens.first;
    });
    _loadPriceHistory();
  }

  /// Maps a [TokenListItemModel] (from store or API) to a [TokenModel].
  static TokenModel _tokenFromListItem(TokenListItemModel item) {
    return TokenModel(
      symbol: item.coin,
      name: item.coin,
      pair: item.symbol,
      imageUrl: item.image ?? '',
      currentPrice: item.price,
      decimals: item.decimals,
      priceChange: item.priceChange,
      priceChangePercentage: item.priceChangePercent,
      chartData: const [],
      lastUpdated: DateTime.now(),
    );
  }

  // ── Price history ────────────────────────────────────────────────────────────

  Future<void> _loadPriceHistory() async {
    try {
      final result = await _tokenService.getPriceHistory(
        symbol: _selectedToken.pair,
        timeframe: '1h',
        limit: 24,
      );
      if (!mounted) return;
      final close = result.close;
      final open = result.open;
      double priceChange = _selectedToken.priceChange;
      double priceChangePct = _selectedToken.priceChangePercentage;
      if (close != null && open != null && open != 0) {
        priceChange = close - open;
        priceChangePct = (priceChange / open) * 100;
      }
      setState(() {
        _selectedToken = _selectedToken.copyWith(
          currentPrice: close ?? _selectedToken.currentPrice,
          priceChange: priceChange,
          priceChangePercentage: priceChangePct,
          chartData: result.prices.isNotEmpty ? result.prices : _selectedToken.chartData,
        );
      });
    } catch (_) {
      // Non-critical — token still shows with initial values.
    }
  }

  // ── WebSocket ────────────────────────────────────────────────────────────────

  Future<void> _connectSocket() async {
    await _socketService.connect();
    _socketSubscription = _socketService.snapshotStream.listen(_onSnapshot);
  }

  void _onSnapshot(OhlcvSnapshotMessage msg) {
    final symbolData = msg.data[_selectedToken.pair];
    if (symbolData == null) return;
    final close = symbolData.closePrice;
    if (close == null) return;
    if (!mounted) return;
    // Derive price change from candle open→close (1d preference).
    final candles = symbolData.candles;
    double priceChange = _selectedToken.priceChange;
    double priceChangePct = _selectedToken.priceChangePercentage;
    if (candles != null) {
      const priority = ['1d', '4h', '1h', '30m', '5m', '1m'];
      for (final tf in priority) {
        final candle = candles[tf];
        if (candle != null && candle.open != 0) {
          priceChange = candle.close - candle.open;
          priceChangePct = (priceChange / candle.open) * 100;
          break;
        }
      }
    }
    setState(() {
      _selectedToken = _selectedToken.copyWith(
        currentPrice: close,
        priceChange: priceChange,
        priceChangePercentage: priceChangePct,
        lastUpdated: DateTime.now(),
      );
    });
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
          _loadPriceHistory();
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
            // Fixed header
            DetailHeaderBar(title: widget.indicator.title),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTokenPriceSection(),
                    const SizedBox(height: 24),
                    _buildToolbar(),
                    const SizedBox(height: 24),
                    _buildContent(),
                  ],
                ),
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
      onFavoriteTap: () => setState(() => _isFavorite = !_isFavorite),
    );
  }

  Widget _buildToolbar() {
    final showHeatmap = widget.indicator.uses.contains('rsi_heatmap');
    final rsiLabel = _heatmapRsiType == 'rsi14' ? 'RSI14' : 'RSI7';

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
            showHeatmap ? 'Heatmap for RSI indicator' : 'RSI indicator',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              if (showHeatmap)
                _RsiTypeDropdown(
                  selected: _heatmapRsiType,
                  label: rsiLabel,
                  onChanged: (value) => setState(() => _heatmapRsiType = value),
                ),
              if (showHeatmap) const SizedBox(width: 8),
              _TimeframeDropdown(
                selected: _timeframe,
                onChanged: (value) => setState(() => _timeframe = value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Renders the correct section components based on [indicator.uses].
  Widget _buildContent() {
    final uses = widget.indicator.uses
        .where((u) => u != 'default_length')
        .toSet();

    final showHeatmap = uses.contains('rsi_heatmap');
    final showAdx = uses.contains('adx');
    // RSI oversold/overbought shown for default indicators and heatmap indicators.
    final showRsi = uses.isEmpty || showHeatmap;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // ── RSI Heatmap bubbles ──────────────────────────────────────────
          if (showHeatmap) ...[
            RsiHeatmapSection(
              timeframe: _timeframe,
              heatmapRsiType: _heatmapRsiType,
            ),
            const SizedBox(height: 24),
          ],

          // ── RSI line charts + oversold/overbought signal list ────────────
          if (showRsi)
            OverboughtOversoldSection(
              symbol: _selectedToken.pair,
              timeframe: _timeframe,
              indicatorCode: widget.indicator.code,
              tokenImageUrl: _selectedToken.imageUrl,
              tokenShortSymbol: _selectedToken.symbol,
            ),

          // ── ADX chart ────────────────────────────────────────────────────
          if (showAdx) ...[
            if (showRsi) const SizedBox(height: 24),
            AdxChartSection(
              symbol: _selectedToken.pair,
              timeframe: _timeframe,
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Toolbar dropdown widgets ─────────────────────────────────────────────────

class _TimeframeDropdown extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _TimeframeDropdown({
    required this.selected,
    required this.onChanged,
  });

  static const _options = ['1m', '5m', '15m', '1h', '4h', '1D'];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showMenu(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(22, 30, 51, 1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.white,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;

    showMenu<String>(
      context: context,
      color: const Color(0xFF1A2332),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height + 4,
        offset.dx + size.width,
        0,
      ),
      items: _options
          .map((tf) => _menuItem(tf, tf == selected))
          .toList(),
    ).then((value) {
      if (value != null && value != selected) {
        onChanged(value);
      }
    });
  }

  PopupMenuItem<String> _menuItem(String value, bool isSelected) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            value,
            style: TextStyle(
              color: isSelected ? const Color(0xFF3B82F6) : Colors.white,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          if (isSelected)
            const Icon(
              Icons.check_rounded,
              color: Color(0xFF3B82F6),
              size: 16,
            ),
        ],
      ),
    );
  }
}

class _RsiTypeDropdown extends StatelessWidget {
  final String selected;
  final String label;
  final ValueChanged<String> onChanged;

  const _RsiTypeDropdown({
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showMenu(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(22, 30, 51, 1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF3B82F6),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF3B82F6),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;

    showMenu<String>(
      context: context,
      color: const Color(0xFF1A2332),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height + 4,
        offset.dx + size.width,
        0,
      ),
      items: [
        _menuItem('rsi14', 'RSI14', selected == 'rsi14'),
        _menuItem('rsi7', 'RSI7', selected == 'rsi7'),
      ],
    ).then((value) {
      if (value != null && value != selected) {
        onChanged(value);
      }
    });
  }

  PopupMenuItem<String> _menuItem(String value, String text, bool isSelected) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: TextStyle(
              color: isSelected ? const Color(0xFF3B82F6) : Colors.white,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          if (isSelected)
            const Icon(
              Icons.check_rounded,
              color: Color(0xFF3B82F6),
              size: 16,
            ),
        ],
      ),
    );
  }
}
