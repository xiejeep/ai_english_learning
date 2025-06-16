import 'package:get_storage/get_storage.dart';
import '../constants/app_constants.dart';

class StorageService {
  static final GetStorage _storage = GetStorage();
  
  // 初始化存储
  static Future<void> initialize() async {
    await GetStorage.init();
  }
  
  // 用户认证相关
  static Future<void> saveUserToken(String token) async {
    await _storage.write(AppConstants.tokenKey, token);
  }
  
  static String? getUserToken() {
    return _storage.read(AppConstants.tokenKey);
  }
  
  static Future<void> saveUserInfo(Map<String, dynamic> userInfo) async {
    await _storage.write(AppConstants.userInfoKey, userInfo);
  }
  
  static Map<String, dynamic>? getUserInfo() {
    return _storage.read(AppConstants.userInfoKey);
  }
  
  static Future<void> clearUserData() async {
    await _storage.remove(AppConstants.tokenKey);
    await _storage.remove(AppConstants.userInfoKey);
  }
  
  // 聊天会话相关
  static Future<void> saveConversations(List<Map<String, dynamic>> conversations) async {
    await _storage.write(AppConstants.conversationsKey, conversations);
  }
  
  static List<Map<String, dynamic>> getConversations() {
    final data = _storage.read(AppConstants.conversationsKey);
    if (data != null && data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }
  
  // 积分相关
  static Future<void> saveCreditsBalance(int balance) async {
    await _storage.write(AppConstants.creditsBalanceKey, balance);
  }
  
  static int getCreditsBalance() {
    return _storage.read(AppConstants.creditsBalanceKey) ?? 0;
  }
  
  // 签到相关
  static Future<void> saveLastCheckinDate(String date) async {
    await _storage.write(AppConstants.lastCheckinDateKey, date);
  }
  
  static String? getLastCheckinDate() {
    return _storage.read(AppConstants.lastCheckinDateKey);
  }
  
  // TTS设置
  static Future<void> saveTTSAutoPlay(bool autoPlay) async {
    await _storage.write(AppConstants.ttsAutoPlayKey, autoPlay);
  }
  
  static bool getTTSAutoPlay() {
    return _storage.read(AppConstants.ttsAutoPlayKey) ?? AppConstants.defaultAutoPlay;
  }
  
  // 应用设置
  static Future<void> saveAppSettings(Map<String, dynamic> settings) async {
    await _storage.write(AppConstants.appSettingsKey, settings);
  }
  
  static Map<String, dynamic> getAppSettings() {
    final data = _storage.read(AppConstants.appSettingsKey);
    if (data != null && data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }
  
  // 通用存储方法
  static Future<void> save<T>(String key, T value) async {
    await _storage.write(key, value);
  }
  
  static T? get<T>(String key) {
    return _storage.read<T>(key);
  }
  
  static Future<void> remove(String key) async {
    await _storage.remove(key);
  }
  
  static Future<void> clear() async {
    await _storage.erase();
  }
  
  // 检查键是否存在
  static bool hasKey(String key) {
    return _storage.hasData(key);
  }
  
  // 获取所有键
  static Iterable<String> getKeys() {
    return _storage.getKeys();
  }
} 