import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io' show Platform;

import '../../../../core/ads/admob_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/store/token_store.dart';
import '../../../../core/store/user_store.dart';
import '../../../../routes/app_routes.dart';
import '../../../../shared/widgets/layout/header_bar.dart';
import '../../data/services/favorite_service.dart';
import '../../data/services/token_service.dart';
import '../bloc/price_bloc.dart';
import '../bloc/price_event.dart';
import '../bloc/price_state.dart';
import '../widgets/token_price_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;
  int _selectedTabIndex = 0;
  late PriceBloc _priceBloc;
  late FavoriteService _favoriteService;
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  bool _isBannerFailed = false;
  bool _isFavoriteLoading = false;
  Set<String> _favoriteSymbols = <String>{};

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient()
      ..setAuthToken(context.read<UserStore>().state.accessToken);
    _priceBloc = PriceBloc(
      tokenStore: context.read<TokenStore>(),
      tokenService: TokenService(apiClient: apiClient),
    );
    _favoriteService = FavoriteService(apiClient: apiClient);
    _priceBloc.add(const HydrateTokensFromStore());
    _scrollController.addListener(_onScroll);
    _loadBannerAd();
    // Connect to socket (optional - comment out if you don't have a socket server)
    // _priceBloc.add(const ConnectToPriceSocket());
  }

  void _loadBannerAd() {
    if (kIsWeb) {
      return;
    }

    String adUnitId;
    if (Platform.isAndroid) {
      adUnitId = kDebugMode
          ? 'ca-app-pub-3940256099942544/6300978111'
          : AdMobConfig.bannerAdUnitIdAndroid;
    } else if (Platform.isIOS) {
      adUnitId = kDebugMode
          ? 'ca-app-pub-3940256099942544/2934735716'
          : AdMobConfig.bannerAdUnitIdIos;
    } else {
      return;
    }

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

  void _onScroll() {
    if (_selectedTabIndex == 1) {
      return;
    }
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (current >= max * 0.85) {
      _priceBloc.add(const LoadMoreTokens());
    }
  }

  final List<Map<String, String>> _cards = const [
    {
      'title': 'Discover heatmap',
      'subtitle': 'Trade smarter, not harder.',
      'buttonText': 'Explore now',
    },
    {
      'title': 'Market Analysis',
      'subtitle': 'Real-time insights for better decisions.',
      'buttonText': 'View insights',
    },
    {
      'title': 'Signal Alerts',
      'subtitle': 'Stay updated with latest signals.',
      'buttonText': 'Get alerts',
    },
    {
      'title': 'Portfolio Tracker',
      'subtitle': 'Monitor your trades and performance.',
      'buttonText': 'Track now',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _bannerAd?.dispose();
    _priceBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        HeaderBar(
          title: 'Zenit',
          onMenuTap: () => Scaffold.of(context).openDrawer(),
        ),
        Expanded(
          child: Container(
            color: AppColors.dark,
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/background-banner.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
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
                                    padding: isActive ? const EdgeInsets.all(1) : null,
                                    child: Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0C1426).withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(isActive ? 15 : 16),
                                        border: isActive
                                            ? null
                                            : Border.all(
                                                color: const Color(0xFF0C1426).withOpacity(0.5),
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
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
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
                                                      ?.copyWith(color: AppColors.gray),
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  _cards[index]['buttonText']!,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: const Color(0xFF5BA3FF),
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 14,
                                                      ),
                                                ),
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
                                            color: const Color(0xFF5BA3FF).withOpacity(0.6),
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
                  ),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
                      final bannerHeight =
                          (MediaQuery.of(context).size.height * 0.06)
                              .clamp(44.0, 72.0);

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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    child: Row(
                      children: [
                        _buildTab('Popular', 0),
                        const SizedBox(width: 0),
                        _buildTab('Favorite', 1),
                        const SizedBox(width: 0),
                      ],
                    ),
                  ),
                  BlocBuilder<PriceBloc, PriceState>(
                    bloc: _priceBloc,
                    builder: (context, state) {
                      if (state.status == PriceStatus.error) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            state.errorMessage ?? 'Failed to load tokens',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        );
                      }

                      if (state.status == PriceStatus.loading &&
                          state.tokenList.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (state.tokenList.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No tokens available',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      final isLoadingMore =
                          state.status == PriceStatus.loading &&
                              state.tokenList.isNotEmpty;

                      final filteredTokens = _selectedTabIndex == 1
                          ? state.tokenList
                              .where((token) =>
                                  _favoriteSymbols.contains(token.symbol))
                              .toList()
                          : state.tokenList;

                      if (_selectedTabIndex == 1 && _isFavoriteLoading) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (_selectedTabIndex == 1 && filteredTokens.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No favorite tokens',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount:
                            filteredTokens.length +
                                (isLoadingMore && _selectedTabIndex == 0 ? 1 : 0),
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (isLoadingMore &&
                              _selectedTabIndex == 0 &&
                              index == filteredTokens.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final token = filteredTokens[index];
                          return TokenPriceCard(
                            token: token,
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                AppRoutes.tokenInfo,
                                arguments: token,
                              );
                            },
                            onVisible: () {
                              _priceBloc.add(
                                LoadTokenChartHistory(symbol: token.symbol),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () async {
        if (_selectedTabIndex == index) {
          return;
        }
        setState(() {
          _selectedTabIndex = index;
        });

        if (index == 1) {
          await _loadFavorites();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0B2D50) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: isSelected
              ? Border.all(color: const Color(0xFF5BA3FF), width: 1.5)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: AppColors.white,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isFavoriteLoading = true;
    });

    try {
      final favoriteSymbols = await _favoriteService.getFavorites();
      if (!mounted) return;

      setState(() {
        _favoriteSymbols = favoriteSymbols.toSet();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _favoriteSymbols = <String>{};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load favorites')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isFavoriteLoading = false;
      });
    }
  }
}
