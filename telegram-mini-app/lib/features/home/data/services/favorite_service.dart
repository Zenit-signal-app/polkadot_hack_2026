import '../../../../core/network/api_client.dart';

class FavoriteService {
  final ApiClient _apiClient;

  FavoriteService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  void setAuthToken(String? token) {
    _apiClient.setAuthToken(token);
  }

  Future<List<Map<String, dynamic>>> addFavorite(String symbol) async {
    final response = await _apiClient.post(
      'favorites',
      body: {
        'symbols': [symbol],
      },
    );

    final List<dynamic> items;
    if (response is List) {
      items = response;
    } else if (response is Map<String, dynamic> && response['data'] is List) {
      items = response['data'] as List<dynamic>;
    } else {
      return const [];
    }

    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> removeFavorite(String symbol) async {
    final response = await _apiClient.delete(
      'favorites',
      body: {
        'symbols': [symbol],
      },
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    return const {};
  }

  Future<List<String>> getFavorites() async {
    final response = await _apiClient.get('favorites');

    final List<dynamic> favoriteItems;
    if (response is List) {
      favoriteItems = response;
    } else if (response is Map<String, dynamic> && response['data'] is List) {
      favoriteItems = response['data'] as List<dynamic>;
    } else {
      return const [];
    }

    return favoriteItems
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map((item) => (item['symbol'] ?? '').toString())
        .where((symbol) => symbol.isNotEmpty)
        .toList();
  }
}
