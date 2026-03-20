import '../../../../core/network/api_client.dart';

enum SignalToolType {
  indicator,
  confluence,
  unknown;

  factory SignalToolType.fromApiValue(String value) {
    switch (value.toLowerCase()) {
      case 'indicator':
        return SignalToolType.indicator;
      case 'confluence':
        return SignalToolType.confluence;
      default:
        return SignalToolType.unknown;
    }
  }

  int get sortOrder {
    switch (this) {
      case SignalToolType.indicator:
        return 0;
      case SignalToolType.confluence:
        return 1;
      case SignalToolType.unknown:
        return 2;
    }
  }
}

class IndicatorModel {
  final String id;
  final String code;
  final String title;
  final String description;
  final SignalToolType type;
  final String iconPath;
  final int displayOrder;
  final Map<String, dynamic> metadata;
  final String createdAt;
  final String updatedAt;

  const IndicatorModel({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.type,
    required this.iconPath,
    required this.displayOrder,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isConfluence => type == SignalToolType.confluence;

  /// List of tool codes declared in metadata["uses"], e.g. ["rsi_heatmap"].
  List<String> get uses {
    final raw = metadata['uses'];
    if (raw is List) {
      return raw.whereType<String>().toList();
    }
    return const [];
  }

  String get resolvedIconPath {
    if (iconPath.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(iconPath);
    if (uri != null && uri.hasScheme) {
      return iconPath;
    }

    return Uri.parse(ApiClient.baseUrl).resolve(iconPath).toString();
  }

  factory IndicatorModel.fromJson(Map<String, dynamic> json) {
    final metadataRaw = json['metadata'];

    return IndicatorModel(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      title: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      type: SignalToolType.fromApiValue((json['type'] ?? '').toString()),
      iconPath: (json['icon_path'] ?? '').toString(),
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      metadata: metadataRaw is Map
          ? Map<String, dynamic>.from(metadataRaw)
          : const {},
      createdAt: (json['created_at'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
    );
  }
}
