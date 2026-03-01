import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../features/home/data/models/token_model.dart';
import 'token_list_item.dart';

class TokenSelectorBottomSheet extends StatefulWidget {
  final List<TokenModel> tokens;
  final TokenModel? selectedToken;
  final Function(TokenModel) onTokenSelected;

  const TokenSelectorBottomSheet({
    super.key,
    required this.tokens,
    this.selectedToken,
    required this.onTokenSelected,
  });

  @override
  State<TokenSelectorBottomSheet> createState() =>
      _TokenSelectorBottomSheetState();
}

class _TokenSelectorBottomSheetState extends State<TokenSelectorBottomSheet> {
  late TextEditingController _searchController;
  List<TokenModel> _filteredTokens = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredTokens = widget.tokens;
    _searchController.addListener(_filterTokens);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterTokens() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredTokens = widget.tokens;
      } else {
        _filteredTokens = widget.tokens
            .where((token) =>
                token.symbol.toLowerCase().contains(query) ||
                token.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A1628),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Select Token',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: AppColors.white,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.white),
              decoration: InputDecoration(
                hintText: 'Search token...',
                hintStyle: TextStyle(
                  color: AppColors.white.withOpacity(0.5),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.white.withOpacity(0.5),
                ),
                filled: true,
                fillColor: AppColors.darkBlue.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Token list
          Flexible(
            child: _filteredTokens.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No tokens found',
                        style: TextStyle(
                          color: AppColors.white.withOpacity(0.5),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredTokens.length,
                    itemBuilder: (context, index) {
                      final token = _filteredTokens[index];
                      final isSelected =
                          widget.selectedToken?.symbol == token.symbol;
                      return TokenListItem(
                        token: token,
                        isSelected: isSelected,
                        onTap: () {
                          widget.onTokenSelected(token);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  static Future<TokenModel?> show({
    required BuildContext context,
    required List<TokenModel> tokens,
    TokenModel? selectedToken,
  }) {
    return showModalBottomSheet<TokenModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TokenSelectorBottomSheet(
        tokens: tokens,
        selectedToken: selectedToken,
        onTokenSelected: (token) {},
      ),
    );
  }
}
