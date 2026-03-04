import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/store/user_store.dart';
import '../data/models/token_list_item_model.dart';
import '../data/models/token_model.dart';
import '../data/services/token_service.dart';
import '../../../routes/app_routes.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const int _pageSize = 20;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  late TokenService _tokenService;

  String _searchQuery = '';
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String? _errorMessage;
  final List<TokenListItemModel> _results = [];

  TokenModel _toTokenModel(TokenListItemModel item) {
    final millis = item.time > 1000000000000 ? item.time : item.time * 1000;
    return TokenModel(
      symbol: item.symbol,
      name: item.coin,
      pair: '${item.coin} / USD',
      imageUrl: item.image ?? '',
      currentPrice: item.price,
      decimals: item.decimals,
      priceChange: item.priceChange,
      priceChangePercentage: item.priceChangePercent,
      chartData: const <double>[],
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(millis),
    );
  }

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient()
      ..setAuthToken(context.read<UserStore>().state.accessToken);
    _tokenService = TokenService(apiClient: apiClient);

    // Auto focus khi màn hình mở
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
    _searchController.addListener(() {
      final nextQuery = _searchController.text;
      if (nextQuery == _searchQuery) {
        return;
      }
      setState(() {
        _searchQuery = nextQuery;
      });
      _searchTokens(reset: true);
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || _isLoading || !_hasMore) {
      return;
    }
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (current >= max * 0.85) {
      _searchTokens(reset: false);
    }
  }

  Future<void> _searchTokens({required bool reset}) async {
    final query = _searchQuery.trim();
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _results.clear();
        _offset = 0;
        _hasMore = true;
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = null;
      });
      return;
    }

    if (reset) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _offset = 0;
        _hasMore = true;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
        _errorMessage = null;
      });
    }

    try {
      final tokens = await _tokenService.getTokens(
        offset: reset ? 0 : _offset,
        limit: _pageSize,
        key: query,
      );

      if (!mounted) return;
      setState(() {
        if (reset) {
          _results
            ..clear()
            ..addAll(tokens);
        } else {
          _results.addAll(tokens);
        }
        _offset = _results.length;
        _hasMore = tokens.length >= _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.dark, AppColors.darkBlue],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(HugeIcons.strokeRoundedArrowLeft01),
                    color: AppColors.white,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: TextStyle(
                          color: AppColors.white.withOpacity(0.5),
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) {
                        // Search logic is handled by listener
                      },
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        _searchController.clear();
                      },
                      icon: const Icon(HugeIcons.strokeRoundedCancel01),
                      color: AppColors.white,
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            Expanded(
              child: _searchQuery.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            HugeIcons.strokeRoundedSearch01,
                            size: 56,
                            color: AppColors.white.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Start searching',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  color: AppColors.gray,
                                ),
                          ),
                        ],
                      ),
                    )
                  : _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Failed to search tokens',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.redAccent,
                ),
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(
              HugeIcons.strokeRoundedSearch01,
              color: AppColors.gray,
            ),
            title: Text(
              'No results found',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.white),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _results.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (_isLoadingMore && index == _results.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final token = _results[index];
        return GestureDetector(
          onTap: () {
            Navigator.of(context).pushNamed(
              AppRoutes.tokenInfo,
              arguments: _toTokenModel(token),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF121D33),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                const Icon(
                  HugeIcons.strokeRoundedCoinsDollar,
                  color: AppColors.gray,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        token.symbol,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        token.coin,
                        style: TextStyle(
                          color: AppColors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
