import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/store/user_store.dart';
import '../../../../core/store/favorite_store.dart';
import '../../../../shared/widgets/trading_view_chart.dart';
import '../../data/models/token_model.dart';
import '../../data/services/favorite_service.dart';
import '../../data/services/token_service.dart';
import '../widgets/line_chart_widget.dart';
import '../widgets/price_section_widget.dart';
import '../widgets/stats_section_widget.dart';
import '../widgets/time_frame_buttons_widget.dart';
import '../widgets/token_detail_header.dart';

enum ChartType { line, candle }

class TokenInfoScreen extends StatefulWidget {
  final TokenModel token;

  const TokenInfoScreen({
    super.key,
    required this.token,
  });

  @override
  State<TokenInfoScreen> createState() => _TokenInfoScreenState();
}

class _TokenInfoScreenState extends State<TokenInfoScreen> {
  static const int _chartLimit = 50;
  
  late final TokenService _tokenService;
  final FavoriteService _favoriteService = FavoriteService();
  
  bool _isLoadingFavorite = false;
  bool _isLoadingChart = false;
  bool _isLoadingToken = false;
  String _selectedTimeFrame = '1D';
  String _selectedTradingViewTimeFrame = '1H';
  ChartType _selectedChartType = ChartType.line;
  List<double> _chartData = [];
  double _priceChange = 0;
  double _priceChangePercentage = 0;
  double _currentPrice = 0;
  
  // Stats from API
  double? _high;
  double? _low;
  double? _volume;
  double? _quoteVolume;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    final accessToken = context.read<UserStore>().state.accessToken;
    final apiClient = ApiClient()..setAuthToken(accessToken);
    _tokenService = TokenService(apiClient: apiClient);
    _favoriteService.setAuthToken(accessToken);
    _chartData = widget.token.chartData;
    _priceChange = widget.token.priceChange;
    _priceChangePercentage = widget.token.priceChangePercentage;
    _currentPrice = widget.token.currentPrice;

    _loadTokenData();
    _loadChartData();

    // Nếu FavoriteStore chưa được load (null), fetch từ API
    // Xảy ra khi user nhảy thẳng vào token detail mà chưa qua tab favorites
    final isLoggedIn = context.read<UserStore>().state.isLoggedIn;
    if (isLoggedIn && !context.read<FavoriteStore>().state.isLoaded) {
      _fetchFavorites();
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

  /// Load token data from API
  Future<void> _loadTokenData() async {
    if (_isLoadingToken) return;
    
    setState(() {
      _isLoadingToken = true;
    });
    
    try {
      final tokenData = await _tokenService.getTokenBySymbol(widget.token.symbol);
      
      if (mounted) {
        setState(() {
          _currentPrice = tokenData.price;
          _priceChange = tokenData.priceChange;
          _priceChangePercentage = tokenData.priceChangePercent;
          _volume = tokenData.volume;
          _quoteVolume = tokenData.quoteVolume;
          _imageUrl = tokenData.image;
          _isLoadingToken = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingToken = false;
        });
      }
    }
  }
  
  /// Maps UI timeframe to API timeframe
  String _mapTimeFrameToApi(String uiTimeFrame) {
    switch (uiTimeFrame) {
      case 'Live':
        return '1m';
      case '1H':
        return '1h';
      case '1D':
        return '1d';
      case '1W':
        return '1w';
      case '1M':
        return '1M';
      case '3M':
        return '3M';
      default:
        return '1d';
    }
  }
  
  /// Maps UI timeframe to TradingView minutes
  int _mapTradingViewTimeFrameToMinutes(String uiTimeFrame) {
    switch (uiTimeFrame) {
      case '1m':
        return 1;
      case '5m':
        return 5;
      case '15m':
        return 15;
      case '1H':
        return 60;
      case '4H':
        return 240;
      case '1D':
        return 1440;
      case '1W':
        return 10080;
      default:
        return 60;
    }
  }
  
  Future<void> _loadChartData() async {
    if (_isLoadingChart) return;
    
    setState(() {
      _isLoadingChart = true;
    });
    
    try {
      final result = await _tokenService.getPriceHistory(
        symbol: widget.token.symbol,
        timeframe: _mapTimeFrameToApi(_selectedTimeFrame),
        limit: _chartLimit,
      );
      
      if (mounted) {
        final chartData = result.prices;
        double priceChange = _priceChange;
        double priceChangePercentage = _priceChangePercentage;
        
        if (chartData.length >= 2) {
          final oldestPrice = chartData.first;
          final latestPrice = chartData.last;
          priceChange = latestPrice - oldestPrice;
          priceChangePercentage = oldestPrice == 0 
              ? 0 
              : (priceChange / oldestPrice) * 100;
        }
        
        setState(() {
          _chartData = chartData;
          _priceChange = priceChange;
          _priceChangePercentage = priceChangePercentage;
          _high = result.high;
          _low = result.low;
          _volume = result.volume;
          _isLoadingChart = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingChart = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentToken = widget.token.copyWith(
      currentPrice: _currentPrice,
      chartData: _chartData,
      priceChange: _priceChange,
      priceChangePercentage: _priceChangePercentage,
    );
    
    return BlocBuilder<FavoriteStore, FavoriteState>(
      builder: (context, favoriteState) {
        final isFavorite = favoriteState.isFavorite(widget.token.symbol);
        
        return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            TokenDetailHeader(
              symbol: widget.token.symbol,
              imageUrl: _imageUrl ?? widget.token.imageUrl,
              isFavorite: isFavorite,
              onFavoriteTap: () => _handleFavoriteTap(isFavorite),
              onBackTap: () => Navigator.of(context).pop(),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Price Section
                    PriceSectionWidget(
                      token: currentToken,
                      isLineChartSelected: _selectedChartType == ChartType.line,
                      onChartTypeChanged: (isLine) {
                        setState(() {
                          _selectedChartType =
                              isLine ? ChartType.line : ChartType.candle;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Chart Section
                    if (_selectedChartType == ChartType.candle) ...[
                      // TradingView Timeframe Buttons
                      _buildTradingViewTimeFrameButtons(),
                      const SizedBox(height: 16),
                      // TradingView chart
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TradingViewChart(
                          symbol: currentToken.symbol,
                          indicators: const [TradingViewIndicator.volume],
                          timeframe: _mapTradingViewTimeFrameToMinutes(_selectedTradingViewTimeFrame),
                          height: 400,
                        ),
                      ),
                    ] else
                      Stack(
                        children: [
                          LineChartWidget(
                            chartData: currentToken.chartData,
                            isPriceUp: currentToken.isPriceUp,
                          ),
                          if (_isLoadingChart)
                            Positioned.fill(
                              child: Container(
                                color: const Color(0xFF0A1628).withValues(alpha: 0.6),
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // Time Frame Buttons – hidden in TradingView mode
                    // (TradingView widget has its own built-in controls).
                    if (_selectedChartType != ChartType.candle)
                      TimeFrameButtonsWidget(
                        selectedTimeFrame: _selectedTimeFrame,
                        onTimeFrameChanged: (timeFrame) {
                          setState(() {
                            _selectedTimeFrame = timeFrame;
                          });
                          _loadChartData();
                        },
                      ),
                    
                    if (_selectedChartType != ChartType.candle)
                      const SizedBox(height: 24),
                    
                    // Stats Section
                    StatsSectionWidget(
                      token: currentToken,
                      high: _high,
                      low: _low,
                      volume: _volume,
                      quoteVolume: _quoteVolume,
                    ),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }
  
  Widget _buildTradingViewTimeFrameButtons() {
    final timeFrames = ['1m', '5m', '15m', '1H', '4H', '1D', '1W'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: timeFrames.map((timeFrame) {
          final isSelected = _selectedTradingViewTimeFrame == timeFrame;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedTradingViewTimeFrame = timeFrame;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1E3A8A)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? Border.all(color: const Color(0xFF3B82F6), width: 1)
                    : null,
              ),
              child: Text(
                timeFrame,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        }).toList(),
      ),
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
        // Remove from favorites - nếu API không throw exception là thành công
        await _favoriteService.removeFavorite(widget.token.symbol);
        // Update FavoriteStore after API success
        await favoriteStore.removeFavorite(widget.token.symbol);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed ${widget.token.symbol} from favorites'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // Add to favorites - nếu API không throw exception là thành công
        await _favoriteService.addFavorite(widget.token.symbol);
        // Update FavoriteStore after API success
        await favoriteStore.addFavorite(widget.token.symbol);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${widget.token.symbol} to favorites'),
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
}
