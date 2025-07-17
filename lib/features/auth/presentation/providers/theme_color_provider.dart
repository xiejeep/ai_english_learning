import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/storage_service.dart';

class ThemeColorNotifier extends ChangeNotifier {
  Color _themeColor;
  ThemeColorNotifier(this._themeColor);
  Color get themeColor => _themeColor;
  void update(Color color) {
    _themeColor = color;
    notifyListeners();
  }
}

final themeColorProvider = ChangeNotifierProvider<ThemeColorNotifier>((ref) {
  final settings = StorageService.getChatBubbleSettings();
  final color = Color(settings['themeColor'] ?? AppConstants.primaryColor.value);
  return ThemeColorNotifier(color);
}); 