import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io' show Platform;

import '../../../../core/ads/admob_config.dart';
import '../../../../core/ads/admob_store.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/store/favorite_store.dart';
import '../../../../core/store/token_store.dart';
import '../../../../core/store/chain_store.dart';
import '../../../../core/store/user_store.dart';
import '../../../../shared/widgets/layout/header_bar.dart';
import '../../data/services/favorite_service.dart';
import '../../data/services/token_service.dart';
import '../bloc/price_bloc.dart';
import '../bloc/price_event.dart';
import '../widgets/token_price_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _ChainInfo {
  final String key;
  final String name;
  final String imageUrl;

  const _ChainInfo({
    required this.key,
    required this.name,
    required this.imageUrl,
  });
}

class _HomeScreenState extends State<HomeScreen> {
  static const _chains = [
    _ChainInfo(
      key: 'hedera',
      name: 'Hedera',
      imageUrl: 'assets/images/hedera.png',
    ),
    _ChainInfo(
      key: 'polkadot',
      name: 'Polkadot',
      imageUrl: 'assets/images/polkadot.png',
    ),
    _ChainInfo(
      key: 'solana',
      name: 'Solana',
      imageUrl: 'assets/images/solana.png',
    ),
  ];

  final ScrollController _scrollController = ScrollController();
  int _selectedTabIndex = 0;
  late PriceBloc _priceBloc;
  late FavoriteService _favoriteService;
  BannerAd? _bannerAd;
  // ignore: unused_field
  bool _isBannerLoaded = false;
  // ignore: unused_field
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
  }

  void _loadBannerAd() {
    if (kIsWeb) return;
    if (kDebugMode) return; // Only show ads in release builds.
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

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _bannerAd?.dispose();
    _priceBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
      color: AppColors.dark,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
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
                    title: 'Zenit',
                    onMenuTap: () => Scaffold.of(context).openDrawer(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildCexCard()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildChainCard()),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // TODO: AdMob banner hidden temporarily
            // const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10.0,
              ),
              child: Row(
                children: [
                  _buildTab('Popular', 0),
                  const SizedBox(width: 0),
                  _buildTab('Favorite', 1),
                  const SizedBox(width: 0),
                ],
              ),
            ),
            TokenPriceList(
              priceBloc: _priceBloc,
              selectedTabIndex: _selectedTabIndex,
              favoriteSymbols: _favoriteSymbols,
              isFavoriteLoading: _isFavoriteLoading,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
        ),
        BlocBuilder<ChainStore, ChainState>(
          builder: (context, chainState) {
            if (!chainState.isLoading) return const SizedBox.shrink();
            return Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: const Color(0xFF0F1C2E).withOpacity(0.92),
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF5BA3FF),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCexCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1426).withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Centralized Exchange',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.white.withOpacity(0.4),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Image.asset(
              'assets/images/binance.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChainCard() {
    final chainState = context.watch<ChainStore>().state;
    final selected = _chains.firstWhere(
      (c) => c.key == chainState.selectedKey,
      orElse: () => _chains.first,
    );
    return GestureDetector(
      onTap: chainState.isLoading ? null : _showChainSelector,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0C1426).withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF5BA3FF), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Select Chain',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF5BA3FF).withOpacity(0.3),
                ),
              ),
              child: Image.asset(
                      selected.imageUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChainSelector() {
    final chainStore = context.read<ChainStore>();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1C2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return BlocBuilder<ChainStore, ChainState>(
          bloc: chainStore,
          builder: (_, chainState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Select Chain',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ..._chains.map((chain) {
                  final isSelected = chainState.selectedKey == chain.key;
                  return GestureDetector(
                    onTap: () {
                      chainStore.selectChain(chain.key);
                      Navigator.of(ctx).pop();
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF5BA3FF).withOpacity(0.12)
                            : const Color(0xFF1A2744),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF5BA3FF)
                              : Colors.white.withOpacity(0.1),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Image.asset(
                        chain.imageUrl,
                        height: 40,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 32),
              ],
            );
          },
        );
      },
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
          final isLoggedIn = context.read<UserStore>().state.isLoggedIn;
          if (isLoggedIn) {
            await _loadFavorites();
          }
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

      // Sync to FavoriteStore so token_info_screen gets updated too
      await context.read<FavoriteStore>().syncFavorites(favoriteSymbols);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _favoriteSymbols = <String>{};
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to load favorites')));
    } finally {
      if (!mounted) return;
      setState(() {
        _isFavoriteLoading = false;
      });
    }
  }
}
