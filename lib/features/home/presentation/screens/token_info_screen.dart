import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/store/user_store.dart';
import '../../data/models/token_model.dart';
import '../../data/services/favorite_service.dart';
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
  final FavoriteService _favoriteService = FavoriteService();
  bool _isFavorite = false;
  bool _isLoadingFavorite = false;
  String _selectedTimeFrame = '1D';
  ChartType _selectedChartType = ChartType.line;

  @override
  void initState() {
    super.initState();
    _favoriteService.setAuthToken(context.read<UserStore>().state.accessToken);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            TokenDetailHeader(
              symbol: widget.token.symbol,
              imageUrl: widget.token.imageUrl,
              isFavorite: _isFavorite,
              onFavoriteTap: _handleFavoriteTap,
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
                      token: widget.token,
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
                    _selectedChartType == ChartType.line
                        ? LineChartWidget(
                            chartData: widget.token.chartData,
                            isPriceUp: widget.token.isPriceUp,
                          )
                        : CandleChartWidget(
                            chartData: widget.token.chartData,
                          ),
                    
                    const SizedBox(height: 24),
                    
                    // Time Frame Buttons
                    TimeFrameButtonsWidget(
                      selectedTimeFrame: _selectedTimeFrame,
                      onTimeFrameChanged: (timeFrame) {
                        setState(() {
                          _selectedTimeFrame = timeFrame;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Stats Section
                    StatsSectionWidget(token: widget.token),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleFavoriteTap() async {
    if (_isLoadingFavorite) return;

    setState(() {
      _isLoadingFavorite = true;
    });

    try {
      if (_isFavorite) {
        final response = await _favoriteService.removeFavorite(widget.token.symbol);
        final deletedSymbols = (response['deleted_symbols'] as List<dynamic>?)
                ?.map((item) => item.toString())
                .toList() ??
            const <String>[];
        if (!deletedSymbols.contains(widget.token.symbol)) {
          throw StateError('Token was not removed from favorites');
        }
        if (mounted) {
          setState(() {
            _isFavorite = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed ${widget.token.symbol} from favorites'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        final response = await _favoriteService.addFavorite(widget.token.symbol);
        final addedSymbols = response
            .map((item) => (item['symbol'] ?? '').toString())
            .where((symbol) => symbol.isNotEmpty)
            .toList();
        if (!addedSymbols.contains(widget.token.symbol)) {
          throw StateError('Token was not added to favorites');
        }
        if (mounted) {
          setState(() {
            _isFavorite = true;
          });
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
