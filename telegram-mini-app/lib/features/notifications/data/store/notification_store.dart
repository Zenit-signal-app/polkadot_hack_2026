import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/signal_notification_model.dart';
import '../services/notification_api_service.dart';

class NotificationStoreState {
  const NotificationStoreState({
    this.notifications = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.selectedSymbol,
    this.selectedTimeframe,
  });

  final List<SignalNotificationModel> notifications;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final String? selectedSymbol;
  final String? selectedTimeframe;

  NotificationStoreState copyWith({
    List<SignalNotificationModel>? notifications,
    bool? isLoading,
    bool? hasMore,
    String? error,
    String? selectedSymbol,
    String? selectedTimeframe,
    bool clearError = false,
    bool clearSymbol = false,
    bool clearTimeframe = false,
  }) {
    return NotificationStoreState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      selectedSymbol: clearSymbol ? null : (selectedSymbol ?? this.selectedSymbol),
      selectedTimeframe: clearTimeframe ? null : (selectedTimeframe ?? this.selectedTimeframe),
    );
  }
}

class NotificationStore extends Cubit<NotificationStoreState> {
  final NotificationApiService _apiService;

  NotificationStore({NotificationApiService? apiService})
      : _apiService = apiService ?? NotificationApiService(),
        super(const NotificationStoreState());

  void setAuthToken(String? token) {
    _apiService.setAuthToken(token);
  }

  /// Initial load - fetches first 20 notifications
  Future<void> loadInitial({String? symbol, String? timeframe}) async {
    emit(state.copyWith(
      isLoading: true,
      clearError: true,
      selectedSymbol: symbol,
      clearSymbol: symbol == null,
      selectedTimeframe: timeframe,
      clearTimeframe: timeframe == null,
    ));

    try {
      final notifications = await _apiService.getNotifications(
        symbol: symbol,
        timeframe: timeframe,
        limit: 20,
        offset: 0,
      );

      emit(state.copyWith(
        notifications: notifications,
        isLoading: false,
        hasMore: notifications.length >= 20,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  /// Load more - fetches next 10 notifications
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final newNotifications = await _apiService.getNotifications(
        symbol: state.selectedSymbol,
        timeframe: state.selectedTimeframe,
        limit: 10,
        offset: state.notifications.length,
      );

      final updatedList = [...state.notifications, ...newNotifications];

      emit(state.copyWith(
        notifications: updatedList,
        isLoading: false,
        hasMore: newNotifications.length >= 10,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  /// Filter by symbol
  Future<void> filterBySymbol(String? symbol) async {
    await loadInitial(symbol: symbol, timeframe: state.selectedTimeframe);
  }

  /// Filter by timeframe
  Future<void> filterByTimeframe(String? timeframe) async {
    await loadInitial(symbol: state.selectedSymbol, timeframe: timeframe);
  }

  /// Apply both filters
  Future<void> applyFilters({String? symbol, String? timeframe}) async {
    await loadInitial(symbol: symbol, timeframe: timeframe);
  }

  /// Clear all notifications and reset state
  void clear() {
    emit(const NotificationStoreState());
  }
}
