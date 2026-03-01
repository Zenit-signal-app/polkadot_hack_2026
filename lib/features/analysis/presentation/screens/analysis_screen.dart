import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  List<IndicatorModel> _confluenceIndicators = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient()
      ..setAuthToken(context.read<UserStore>().state.accessToken);
    _signalToolService = SignalToolService(apiClient: apiClient);
    _loadSignalTools();
  }

  Future<void> _loadSignalTools() async {
    try {
      final tools = await _signalToolService.getSignalTools();

      if (!mounted) {
        return;
      }

      setState(() {
        _singleIndicators = tools.where((tool) => !tool.isConfluence).toList();
        _confluenceIndicators = tools.where((tool) => tool.isConfluence).toList();
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
    return Column(
      children: [
        // Header
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0A1628),
                const Color(0xFF0A1628).withOpacity(0.8),
              ],
            ),
          ),
          child: HeaderBar(
            title: 'Analysis',
            onMenuTap: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        
        // Content
        Expanded(
          child: Container(
            color: const Color(0xFF0A1628),
            child: _buildBody(),
          ),
        ),
      ],
    );
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
          const SizedBox(height: 32),
          _buildSectionTitle('Confluence'),
          const SizedBox(height: 16),
          ..._confluenceIndicators.map(
            (indicator) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: IndicatorItemWidget(
                indicator: indicator,
                onTap: () => _handleIndicatorTap(indicator),
              ),
            ),
          ),
          const SizedBox(height: 24),
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
    Navigator.of(context).pushNamed(
      AppRoutes.indicatorDetail,
      arguments: indicator,
    );
  }
}
