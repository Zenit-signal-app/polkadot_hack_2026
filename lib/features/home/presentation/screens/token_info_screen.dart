import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/store/user_store.dart';
import '../../../../core/store/favorite_store.dart';
import '../../data/models/token_model.dart';
import '../../data/services/favorite_service.dart';
import '../../data/services/token_service.dart';
import '../widgets/candle_chart_widget.dart';
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
  String _selectedTimeFrame = '1D';
  ChartType _selectedChartType = ChartType.line;
  List<double> _chartData = [];
  double _priceChange = 0;
  double _priceChangePercentage = 0;
  
  // Stats from API
  double? _high;
  double? _low;
  double? _volume;

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

    _loadChartData();

    // Nếu FavoriteStore chưa được load (null), fetch từ API
    // Xảy ra khi user nhảy thẳng vào token detail mà chưa qua tab favorites
    if (!context.read<FavoriteStore>().state.isLoaded) {
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
              imageUrl: widget.token.imageUrl,
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
                    
                    // Chart Section (keep old data visible while loading)
                    Stack(
                      children: [
                        // Chart (always visible with current data)
                        _selectedChartType == ChartType.line
                            ? LineChartWidget(
                                chartData: currentToken.chartData,
                                isPriceUp: currentToken.isPriceUp,
                              )
                            : CandleChartWidget(
                                chartData: currentToken.chartData,
                              ),
                        // Loading overlay
                        if (_isLoadingChart)
                          Positioned.fill(
                            child: Container(
                              color: const Color(0xFF0A1628).withOpacity(0.6),
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
                    
                    // Time Frame Buttons
                    TimeFrameButtonsWidget(
                      selectedTimeFrame: _selectedTimeFrame,
                      onTimeFrameChanged: (timeFrame) {
                        setState(() {
                          _selectedTimeFrame = timeFrame;
                        });
                        _loadChartData();
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Stats Section
                    StatsSectionWidget(
                      token: currentToken,
                      high: _high,
                      low: _low,
                      volume: _volume,
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
