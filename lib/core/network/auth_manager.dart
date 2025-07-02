import 'package:flutter/material.dart';

/// 全局认证管理器
/// 处理token过期、认证状态变化等全局认证事件
class AuthManager {
  static AuthManager? _instance;
  static AuthManager get instance => _instance ??= AuthManager._();
  
  AuthManager._();
  
  // 认证状态更新回调
  static void Function()? _onAuthStateChanged;
  
  /// 初始化认证管理器
  static void initialize({
    void Function()? onAuthStateChanged,
  }) {
    _onAuthStateChanged = onAuthStateChanged;
  }
  
  /// 处理token过期
  static void handleTokenExpired() {
    print('🔐 [AuthManager] 处理token过期事件');
    
    try {
      // 通知认证状态变化
      if (_onAuthStateChanged != null) {
        _onAuthStateChanged!();
        print('✅ [AuthManager] 认证状态更新回调已执行');
      } else {
        print('⚠️ [AuthManager] 未设置认证状态更新回调');
      }
      
    } catch (e) {
      print('❌ [AuthManager] 处理token过期失败: $e');
    }
  }
  
  /// 设置认证状态变化回调
  static void setAuthStateChangedCallback(void Function() callback) {
    _onAuthStateChanged = callback;
    print('✅ [AuthManager] 认证状态更新回调已设置');
  }
} 