import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io' show Platform;

import '../../../../core/ads/admob_config.dart';
import '../../../../core/ads/admob_store.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/store/user_store.dart';
import '../../../../routes/app_routes.dart';
import '../../../../shared/widgets/layout/header_bar.dart';
import '../../data/models/indicator_model.dart';
import '../../data/services/signal_tool_service.dart';
import '../widgets/indicator_item_widget.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  late final SignalToolService _signalToolService;
  List<IndicatorModel> _singleIndicators = const [];
  // ignore: unused_field
  List<IndicatorModel> _confluenceIndicators = const [];
  bool _isLoading = true;
  String? _errorMessage;
  BannerAd? _bannerAd;
  // ignore: unused_field
  bool _isBannerLoaded = false;
  // ignore: unused_field
  bool _isBannerFailed = false;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _cards = const [
    {
      'title': 'Market Analysis',
      'subtitle': 'Real-time insights for better decisions.',
      'buttonText': 'View insights',
      'onTap': 'navigate_to_market_analysis',
    },
    {
      'title': 'Signal Alerts',
      'subtitle': 'Stay updated with latest signals.',
      'buttonText': 'Get alerts',
      'onTap': 'navigate_to_signal_alerts',
    },
  ];

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient()
      ..setAuthToken(context.read<UserStore>().state.accessToken);
    _signalToolService = SignalToolService(apiClient: apiClient);
    _loadSignalTools();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    if (kIsWeb) return;
    if (kDebugMode) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final adUnitId = context.read<AdmobStore>().resolveUnitId(
      adType: 'banner',
      debugFallback: Platform.isIOS
          ? AdMobConfig.testBannerIos
          : AdMobConfig.testBannerAndroid,
      releaseFallback: Platform.isIOS
          ? AdMobConfig.bannerAdUnitIdIos
          : AdMobConfig.bannerAdUnitIdAndroid,
    );

    _bannerAd?.dispose();

    final banner = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isBannerLoaded = true;
            _isBannerFailed = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _isBannerLoaded = false;
            _isBannerFailed = true;
            _bannerAd = null;
          });
        },
      ),
    );

    banner.load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _loadSignalTools() async {
    try {
      final tools = await _signalToolService.getSignalTools();

      if (!mounted) {
        return;
      }

      setState(() {
        _singleIndicators = tools.where((tool) => !tool.isConfluence).toList();
        _confluenceIndicators = tools
            .where((tool) => tool.isConfluence)
            .toList();
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load signal tools';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(color: const Color(0xFF0A1628), child: _buildBody());
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.blue),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.white),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _loadSignalTools();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background-banner.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HeaderBar(
                  title: 'Analysis',
                  onMenuTap: () => Scaffold.of(context).openDrawer(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 180,
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          itemCount: _cards.length,
                          itemBuilder: (context, index) {
                            final isActive = _currentPage == index;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Container(
                                decoration: isActive
                                    ? BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF3D98E7),
                                            Color(0xFF68B9FF),
                                            Color(0xFF0D4C83),
                                          ],
                                          stops: [0.0497, 0.5092, 0.8234],
                                        ),
                                      )
                                    : null,
                                padding: isActive
                                    ? const EdgeInsets.all(1)
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF0C1426,
                                    ).withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(
                                      isActive ? 15 : 16,
                                    ),
                                    border: isActive
                                        ? null
                                        : Border.all(
                                            color: const Color(
                                              0xFF0C1426,
                                            ).withOpacity(0.5),
                                            width: 1,
                                          ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              _cards[index]['title']!,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineSmall
                                                  ?.copyWith(
                                                    color: AppColors.white,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 18,
                                                    letterSpacing: 0,
                                                  ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              _cards[index]['subtitle']!,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color: AppColors.gray,
                                                  ),
                                            ),
                                            const SizedBox(height: 16),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Image.asset(
                                        'assets/images/image.png',
                                        height: 67,
                                        width: 75,
                                        fit: BoxFit.contain,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _cards.length,
                          (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? const Color(0xFF5BA3FF)
                                  : AppColors.white.withOpacity(0.3),
                              shape: BoxShape.circle,
                              boxShadow: _currentPage == index
                                  ? [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF5BA3FF,
                                        ).withOpacity(0.6),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Single Indicator'),
                const SizedBox(height: 16),
                ..._singleIndicators.map(
                  (indicator) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: IndicatorItemWidget(
                      indicator: indicator,
                      onTap: () => _handleIndicatorTap(indicator),
                    ),
                  ),
                ),
                // TODO: Confluence section hidden temporarily
                // const SizedBox(height: 32),
                // _buildSectionTitle('Confluence'),
                // const SizedBox(height: 16),
                // ..._confluenceIndicators.map(...),
                const SizedBox(height: 24),
                // TODO: AdMob banner hidden temporarily
                /*
                Builder(
                  builder: (context) {
                    final bannerHeight =
                        (MediaQuery.of(context).size.height * 0.06).clamp(
                          44.0,
                          72.0,
                        );

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Center(
                        child: SizedBox(
                          height: bannerHeight,
                          width: 320,
                          child: _isBannerLoaded && _bannerAd != null
                              ? AdWidget(ad: _bannerAd!)
                              : Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF151F3A),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.white.withOpacity(0.08),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _isBannerFailed
                                          ? 'Banner ad failed to load'
                                          : 'Loading banner ad...',
                                      style: TextStyle(
                                        color: AppColors.white.withOpacity(0.6),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    );
                  },
                ),
                */
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.white,
        letterSpacing: 0.3,
      ),
    );
  }

  void _handleIndicatorTap(IndicatorModel indicator) {
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.indicatorDetail, arguments: indicator);
  }
}
