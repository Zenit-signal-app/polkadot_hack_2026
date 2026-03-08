import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/store/favorite_store.dart';
import '../../../../core/store/token_store.dart';
import '../../../../core/store/user_store.dart';
import '../../../../features/home/data/models/ohlcv_snapshot_model.dart';
import '../../../../features/home/data/models/token_list_item_model.dart';
import '../../../../features/home/data/models/token_model.dart';
import '../../../../features/home/data/services/favorite_service.dart';
import '../../../../features/home/data/services/price_socket_service.dart';
import '../../../../features/home/data/services/token_service.dart';
import '../../../../routes/app_routes.dart';
import '../../../../shared/widgets/layout/bottom_nav_bar.dart';
import '../../../../shared/widgets/layout/detail_header_bar.dart';
import '../../../../shared/widgets/token_selector_bottom_sheet.dart';
import '../../../../shared/widgets/trading_view_chart.dart';
import '../../data/models/indicator_model.dart';
import '../widgets/adx_chart_section.dart';
import '../widgets/overbought_oversold_section.dart';
import '../widgets/rsi_heatmap_section.dart';
import '../widgets/rsi_tabs_with_signals.dart';
import '../widgets/token_price_section.dart';

class IndicatorDetailScreen extends StatefulWidget {
  final IndicatorModel indicator;

  const IndicatorDetailScreen({super.key, required this.indicator});

  @override
  State<IndicatorDetailScreen> createState() => _IndicatorDetailScreenState();
}

class _IndicatorDetailScreenState extends State<IndicatorDetailScreen> {
  late TokenService _tokenService;
  final FavoriteService _favoriteService = FavoriteService();
  final PriceSocketService _socketService = PriceSocketService();
  StreamSubscription<OhlcvSnapshotMessage>? _socketSubscription;

  late TokenModel _selectedToken;
  bool _isLoadingFavorite = false;

  // Timeframe selector — supported values match the API.
  String _timeframe = '15m';

  /// Converts timeframe string to minutes for TradingViewChart.
  int _timeframeToMinutes(String tf) {
    switch (tf) {
      case '1m':
        return 1;
      case '5m':
        return 5;
      case '15m':
        return 15;
      case '1h':
        return 60;
      case '4h':
        return 240;
      case '1D':
        return 1440;
      default:
        return 15; // Default fallback
    }
  }

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
    final accessToken = context.read<UserStore>().state.accessToken;
    final apiClient = ApiClient()..setAuthToken(accessToken);
    _tokenService = TokenService(apiClient: apiClient);
    _favoriteService.setAuthToken(accessToken);
    _loadAvailableTokens();
    _connectSocket();

    final isLoggedIn = context.read<UserStore>().state.isLoggedIn;
    if (isLoggedIn && !context.read<FavoriteStore>().state.isLoaded) {
      _fetchFavorites();
    }
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _socketService.dispose();
    super.dispose();
  }

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
          chartData: result.prices.isNotEmpty
              ? result.prices
              : _selectedToken.chartData,
        );
      });
    } catch (_) {
      // Non-critical — token still shows with initial values.
    }
  }

  /// Fetch danh sách favorites từ API và sync vào FavoriteStore
  Future<void> _fetchFavorites() async {
    try {
      final symbols = await _favoriteService.getFavorites();
      if (mounted) {
        await context.read<FavoriteStore>().syncFavorites(symbols);
      }
    } catch (_) {
      // Non-critical: nếu lỗi thì hiển thị icon mặc định (không favorite)
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
    return BlocBuilder<FavoriteStore, FavoriteState>(
      builder: (context, favoriteState) {
        final isFavorite = favoriteState.isFavorite(_selectedToken.pair);

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
                        _buildTokenPriceSection(isFavorite),
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
                  ).pushNamedAndRemoveUntil(AppRoutes.aiChat, (route) => false);
                  break;
                case 3:
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil(AppRoutes.news, (route) => false);
                  break;
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildTokenPriceSection(bool isFavorite) {
    return TokenPriceSection(
      selectedToken: _selectedToken,
      isFavorite: isFavorite,
      onTokenSelectorTap: _showTokenSelector,
      onFavoriteTap: () => _handleFavoriteTap(isFavorite),
    );
  }

  Future<void> _handleFavoriteTap(bool isFavorite) async {
    if (_isLoadingFavorite) return;

    setState(() {
      _isLoadingFavorite = true;
    });

    final favoriteStore = context.read<FavoriteStore>();

    try {
      if (isFavorite) {
        // Remove from favorites
        await _favoriteService.removeFavorite(_selectedToken.pair);
        await favoriteStore.removeFavorite(_selectedToken.pair);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed ${_selectedToken.symbol} from favorites'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // Add to favorites
        await _favoriteService.addFavorite(_selectedToken.pair);
        await favoriteStore.addFavorite(_selectedToken.pair);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${_selectedToken.symbol} to favorites'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update favorite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFavorite = false;
        });
      }
    }
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
                onChanged: (value) {
                  setState(() => _timeframe = value);
                },
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
        .toList();

    final widgets = <Widget>[];

    // Collect all TradingView indicators from uses to avoid duplicate webviews
    final tradingViewIndicators = <TradingViewIndicator>[];
    final otherWidgets = <Widget>[];

    for (final use in uses) {
      switch (use) {
        case 'adx':
          tradingViewIndicators.add(TradingViewIndicator.adx);
          // Add ADX line chart section separately
          otherWidgets.add(AdxChartSection(
            symbol: _selectedToken.pair,
            timeframe: _timeframe,
          ));
          break;
        case 'psar':
          tradingViewIndicators.add(TradingViewIndicator.psar);
          break;
        case 'rsi_heatmap':
        case 'heatmap':
          otherWidgets.add(RsiHeatmapSection(
            timeframe: _timeframe,
            heatmapRsiType: _heatmapRsiType,
          ));
          break;
        case 'adx_line':
          otherWidgets.add(AdxChartSection(
            symbol: _selectedToken.pair,
            timeframe: _timeframe,
          ));
          break;
        case 'candle_chart':
          // Will be handled by TradingView chart with no indicators
          break;
        default:
          break;
      }
    }

    // Render single TradingView chart with all indicators if any
    if (tradingViewIndicators.isNotEmpty || uses.contains('candle_chart')) {
      widgets.add(
        TradingViewChart(
          symbol: _selectedToken.pair,
          indicators: tradingViewIndicators,
          timeframe: _timeframeToMinutes(_timeframe),
          height: 400,
        ),
      );
    }

    // Add other widgets
    for (final widget in otherWidgets) {
      if (widgets.isNotEmpty) {
        widgets.add(const SizedBox(height: 24));
      }
      widgets.add(widget);
    }

    // RSI oversold/overbought shown for default indicators or rsi_heatmap
    if (uses.isEmpty || uses.contains('rsi_heatmap')) {
      if (widgets.isNotEmpty) {
        widgets.add(const SizedBox(height: 24));
      }
      widgets.add(
        OverboughtOversoldSection(
          symbol: _selectedToken.pair,
          timeframe: _timeframe,
          indicatorCode: widget.indicator.code,
          tokenImageUrl: _selectedToken.imageUrl,
          tokenShortSymbol: _selectedToken.symbol,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          ...widgets,
          const SizedBox(height: 24),
          _buildRsiSignalsSection(),
        ],
      ),
    );
  }

  /// RSI signals tabs displayed at the bottom for all indicators
  Widget _buildRsiSignalsSection() {
    return Column(
      children: [
        RsiTabsWithSignals(
          symbol: _selectedToken.pair,
          timeframe: _timeframe,
          tokenImageUrl: _selectedToken.imageUrl,
          code: widget.indicator.code,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Toolbar dropdown widgets ─────────────────────────────────────────────────

class _TimeframeDropdown extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _TimeframeDropdown({required this.selected, required this.onChanged});

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
      items: _options.map((tf) => _menuItem(tf, tf == selected)).toList(),
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
            const Icon(Icons.check_rounded, color: Color(0xFF3B82F6), size: 16),
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
            const Icon(Icons.check_rounded, color: Color(0xFF3B82F6), size: 16),
        ],
      ),
    );
  }
}
