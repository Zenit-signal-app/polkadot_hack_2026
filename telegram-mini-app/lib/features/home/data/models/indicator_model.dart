import 'package:flutter/material.dart';

enum IndicatorType {
  rsiHeatmap,
  psarIndicator,
  adxIndicator,
  radar,
}

class IndicatorModel {
  final String id;
  final String title;
  final String description;
  final IndicatorType type;
  final IconData icon;
  final Color iconColor;

  const IndicatorModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.icon,
    required this.iconColor,
  });
}
