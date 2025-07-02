import 'package:flutter/material.dart';

class AppConstants {
  // 应用信息
  static const String appName = 'AI English Learning';
  static const String appVersion = '1.0.0';
  
  // API配置
  // static const String baseUrl = 'https://api.classhorse.top/';
  static const String baseUrl = 'http://192.168.0.61:3000/';
  static const String apiVersion = 'v1';
  
  // API路径
  static const String authSendCodePath = '/api/auth/send-code';
  static const String authRegisterPath = '/api/auth/register';
  static const String authLoginPath = '/api/auth/login';
  static const String authSendResetCodePath = '/api/auth/send-reset-code';
  static const String authResetPasswordPath = '/api/auth/reset-password';
  static const String creditsBalancePath = '/api/credits/balance';
  static const String creditsHistoryPath = '/api/credits/history';
  static const String checkinPath = '/api/checkin';
  static const String difychatPath = '/api/dify/chat-messages';
  static const String difyTtsPath = '/api/dify/text-to-audio';
  static const String difyConversationsPath = '/api/dify/conversations';
  
  // Dify标准API配置（参考dify_flutter项目）
  static const String difyAppId = '你的实际AppId'; // 需要从服务器获取正确的AppId
  static const String difyApiPrefix = '/console/api';
  static const String difyStandardTtsPath = '$difyApiPrefix/installed-apps/$difyAppId/text-to-audio';
  
  // 主题颜色
  static const Color primaryColor = Color(0xFF4A6FFF);
  static const Color primaryLightColor = Color(0xFF7B93FF);
  static const Color primaryDarkColor = Color(0xFF2C5BFF);
  
  // 路由路径
  static const String splashRoute = '/';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String forgotPasswordRoute = '/forgot-password';
  static const String homeRoute = '/home';
  static const String chatRoute = '/chat';
  static const String profileRoute = '/profile';
  static const String creditsRoute = '/credits';
  static const String checkinRoute = '/checkin';
  static const String settingsRoute = '/settings';
  static const String voiceSettingsRoute = '/voice-settings';
  
  // 存储键名
  static const String tokenKey = 'user_token';
  static const String userInfoKey = 'user_info';
  static const String conversationsKey = 'conversations';
  static const String creditsBalanceKey = 'credits_balance';
  static const String lastCheckinDateKey = 'last_checkin_date';
  static const String appSettingsKey = 'app_settings';
  static const String ttsAutoPlayKey = 'tts_auto_play';
  static const String rememberedAccountsKey = 'remembered_accounts';
  static const String lastLoginEmailKey = 'last_login_email';
  static const String rememberAccountKey = 'remember_account';
  
  // 默认值
  static const int defaultTimeout = 30000; // 30秒
  static const int maxRetryCount = 3;
  static const bool defaultAutoPlay = true;
  
  // 积分相关
  static const int dailyCheckinReward = 10;
  static const int chatMessageReward = 5;
  static const int weeklyStreakReward = 20;
  static const int monthlyStreakReward = 50;
}