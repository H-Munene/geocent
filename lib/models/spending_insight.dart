import 'package:flutter/cupertino.dart';

class SpendingInsight {
  final String? prefix;
  final String highlight;
  final String? suffix;
  final Color highlightColor;
  final dynamic icon;

  SpendingInsight({
    this.prefix,
    required this.highlight,
    this.suffix,
    required this.highlightColor,
    required this.icon,
  });

  String get key => '${prefix}_$highlight$suffix';
}
