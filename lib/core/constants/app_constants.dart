class AppConstants {
  // 应用信息
  static const String appName = 'AI English Learning';
  static const String appVersion = '1.0.0';
  
  // API配置
  static const String baseUrl = 'https://your-api-domain.com'; // TODO: 替换为实际的API地址
  static const String apiVersion = 'v1';
  
  // 路由路径
  static const String splashRoute = '/';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
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