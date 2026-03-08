import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io' show Platform;

import '../../../core/constants/app_colors.dart';
import '../../../core/ads/admob_config.dart';
import '../../../core/ads/admob_store.dart';
import '../../../core/utils/ad_navigation_helper.dart';
import '../../../core/store/token_store.dart';
import '../../../core/store/user_store.dart';
import '../../../routes/app_routes.dart';
import '../../home/data/models/token_model.dart';
import '../data/models/signal_notification_model.dart';
import '../data/store/notification_store.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accessToken = context.read<UserStore>().state.accessToken;

    return BlocProvider(
      create: (context) => NotificationStore()
        ..setAuthToken(accessToken)
        ..loadInitial(),
      child: const _NotificationsScreenContent(),
    );
  }
}

class _NotificationsScreenContent extends StatefulWidget {
  const _NotificationsScreenContent();

  @override
  State<_NotificationsScreenContent> createState() =>
      _NotificationsScreenContentState();
}

class _NotificationsScreenContentState
    extends State<_NotificationsScreenContent> {
  late ScrollController _scrollController;
  bool _showScrollToTop = false;
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  bool _isBannerFailed = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadBannerAd();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _bannerAd?.dispose();
    super.dispose();
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
    // Show scroll to top button when scrolled down more than 300 pixels
    if (_scrollController.position.pixels > 300 && !_showScrollToTop) {
      setState(() {
        _showScrollToTop = true;
      });
    } else if (_scrollController.position.pixels <= 300 && _showScrollToTop) {
      setState(() {
        _showScrollToTop = false;
      });
    }

    // Load more when near bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<NotificationStore>().loadMore();
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  void _showSymbolFilterSheet(
    BuildContext context,
    List<String> availableSymbols,
    String? currentSymbol,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filter by Symbol',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(HugeIcons.strokeRoundedCancel01),
                      color: AppColors.gray,
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.gray, height: 1),
              const SizedBox(height: 8),
              // Scrollable list
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // All Symbols option
                    ListTile(
                      leading: currentSymbol == null
                          ? const Icon(
                              HugeIcons.strokeRoundedCheckmarkCircle02,
                              color: AppColors.blue,
                            )
                          : const Icon(
                              HugeIcons.strokeRoundedCircle,
                              color: AppColors.gray,
                            ),
                      title: const Text(
                        'All Symbols',
                        style: TextStyle(color: AppColors.white),
                      ),
                      onTap: () {
                        context.read<NotificationStore>().filterBySymbol(null);
                        Navigator.pop(sheetContext);
                      },
                    ),
                    // Symbol options
                    ...availableSymbols.map(
                      (symbol) => ListTile(
                        leading: currentSymbol == symbol
                            ? const Icon(
                                HugeIcons.strokeRoundedCheckmarkCircle02,
                                color: AppColors.blue,
                              )
                            : const Icon(
                                HugeIcons.strokeRoundedCircle,
                                color: AppColors.gray,
                              ),
                        title: Text(
                          symbol,
                          style: const TextStyle(color: AppColors.white),
                        ),
                        onTap: () {
                          context.read<NotificationStore>().filterBySymbol(
                            symbol,
                          );
                          Navigator.pop(sheetContext);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTimeframeFilterSheet(
    BuildContext context,
    String? currentTimeframe,
  ) {
    final timeframes = ['1m', '5m', '30m', '1h', '4h', '1d', '1w'];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filter by Timeframe',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(HugeIcons.strokeRoundedCancel01),
                      color: AppColors.gray,
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.gray, height: 1),
              const SizedBox(height: 8),
              // Scrollable list
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // All timeframes option
                    ListTile(
                      leading: currentTimeframe == null
                          ? const Icon(
                              HugeIcons.strokeRoundedCheckmarkCircle02,
                              color: AppColors.blue,
                            )
                          : const Icon(
                              HugeIcons.strokeRoundedCircle,
                              color: AppColors.gray,
                            ),
                      title: const Text(
                        'All Timeframes',
                        style: TextStyle(color: AppColors.white),
                      ),
                      onTap: () {
                        context.read<NotificationStore>().filterByTimeframe(null);
                        Navigator.pop(sheetContext);
                      },
                    ),
                    // Individual timeframe options
                    ...timeframes.map(
                      (timeframe) => ListTile(
                        leading: currentTimeframe == timeframe
                            ? const Icon(
                                HugeIcons.strokeRoundedCheckmarkCircle02,
                                color: AppColors.blue,
                              )
                            : const Icon(
                                HugeIcons.strokeRoundedCircle,
                                color: AppColors.gray,
                              ),
                        title: Text(
                          timeframe.toUpperCase(),
                          style: const TextStyle(color: AppColors.white),
                        ),
                        onTap: () {
                          context.read<NotificationStore>().filterByTimeframe(timeframe);
                          Navigator.pop(sheetContext);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokenStore = context.watch<TokenStore>();
    final availableSymbols = tokenStore.state.items
        .map((t) => t.symbol)
        .toList();

    return BlocBuilder<NotificationStore, NotificationStoreState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.black,
          appBar: AppBar(
            backgroundColor: AppColors.black,
            elevation: 0,
            titleSpacing: 0,
            shape: Border(
              bottom: BorderSide(
                color: AppColors.gray.withOpacity(0.2),
                width: 1,
              ),
            ),
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(HugeIcons.strokeRoundedArrowLeft01),
              color: AppColors.white,
            ),
            title: Text(
              'Notifications',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            actions: [
              // Timeframe filter button
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: TextButton.icon(
                  onPressed: () => _showTimeframeFilterSheet(
                    context,
                    state.selectedTimeframe,
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.white,
                    size: 18,
                  ),
                  label: Text(
                    state.selectedTimeframe?.toUpperCase() ?? 'All TF',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  iconAlignment: IconAlignment.end,
                ),
              ),
              // Symbol filter button
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton.icon(
                  onPressed: () => _showSymbolFilterSheet(
                    context,
                    availableSymbols,
                    state.selectedSymbol,
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.white,
                    size: 18,
                  ),
                  label: Text(
                    state.selectedSymbol ?? 'All',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  iconAlignment: IconAlignment.end,
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _buildNotificationsList(context, state),
          ),
          floatingActionButton: _showScrollToTop
              ? FloatingActionButton(
                  onPressed: _scrollToTop,
                  backgroundColor: AppColors.blue.withOpacity(0.1),
                  child: const Icon(
                    HugeIcons.strokeRoundedArrowUpDouble,
                    color: AppColors.white,
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildNotificationsList(
    BuildContext context,
    NotificationStoreState state,
  ) {
    if (state.isLoading && state.notifications.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.blue),
      );
    }

    if (state.error != null && state.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              HugeIcons.strokeRoundedAlert02,
              color: AppColors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error loading notifications',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                state.error!,
                style: const TextStyle(color: AppColors.gray, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.read<NotificationStore>().loadInitial(
                symbol: state.selectedSymbol,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              HugeIcons.strokeRoundedNotification03,
              color: AppColors.gray.withOpacity(0.5),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: TextStyle(color: AppColors.gray, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: state.notifications.length + 2, // +1 for banner, +1 for load more
      itemBuilder: (context, index) {
        // Banner ad at the top
        if (index == 0) {
          return _buildBannerAdWidget();
        }
        
        // Adjust index for notifications (offset by banner)
        final notificationIndex = index - 1;
        
        if (notificationIndex == state.notifications.length) {
          // Load more indicator
          if (state.isLoading) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.blue),
              ),
            );
          } else if (!state.hasMore) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No more notifications',
                  style: TextStyle(color: AppColors.gray, fontSize: 14),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }

        final notification = state.notifications[notificationIndex];
        return _NotificationCard(notification: notification);
      },
    );
  }

  Widget _buildBannerAdWidget() {
    final bannerHeight = 60.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
  }
}

class _NotificationCard extends StatelessWidget {
  final SignalNotificationModel notification;

  const _NotificationCard({required this.notification});

  Color _getTimeframeColor(String timeframe) {
    // Return different colors based on timeframe with diverse color palette
    switch (timeframe.toLowerCase()) {
      case '1m':
        return const Color(0xFFD32F2F); // Red
      case '5m':
        return const Color(0xFFE64A19); // Deep Orange
      case '15m':
        return const Color(0xFFF57C00); // Orange
      case '30m':
        return const Color(0xFFFBC02D); // Yellow
      case '1h':
        return const Color(0xFF7CB342); // Light Green
      case '4h':
        return const Color(0xFF00897B); // Teal
      case '1d':
        return const Color(0xFF1976D2); // Blue
      case '1w':
        return const Color(0xFF7B1FA2); // Purple
      default:
        return AppColors.darkBlue; // Default
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    final createdDate = DateTime.tryParse(notification.createdAt);
    final formattedDate = createdDate != null
        ? dateFormat.format(createdDate.toLocal())
        : notification.createdAt;

    final backgroundColor = _getTimeframeColor(notification.timeframe);

    return InkWell(
      onTap: () {
        // Create a basic TokenModel with symbol to navigate to token info
        final token = TokenModel(
          symbol: notification.symbol,
          name: notification.symbol,
          pair: 'USDT',
          imageUrl: notification.image ?? '',
          currentPrice: 0,
          priceChange: 0,
          priceChangePercentage: 0,
          chartData: [],
          lastUpdated: DateTime.now(),
        );
        
        // Use AdNavigationHelper to show interstitial ad before navigating
        AdNavigationHelper.navigateWithAd(
          context,
          routeName: AppRoutes.tokenInfo,
          arguments: token,
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkBlue.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gray.withOpacity(0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: backgroundColor.withOpacity(0.2),
              ),
              child: notification.image != null && notification.image!.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        notification.image!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              notification.symbol.isNotEmpty
                                  ? notification.symbol[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : Center(
                      child: Text(
                        notification.symbol.isNotEmpty
                            ? notification.symbol[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title: Symbol + Timeframe
                  Row(
                    children: [
                      Text(
                        notification.symbol,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: backgroundColor,
                        ),
                        child: Text(
                          notification.timeframe.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Message
                  Text(
                    notification.message,
                    style: TextStyle(
                      color: AppColors.white.withOpacity(0.8),
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  
                  // Timestamp
                  Row(
                    children: [
                      Icon(
                        HugeIcons.strokeRoundedClock01,
                        color: AppColors.white.withOpacity(0.5),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: AppColors.white.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
