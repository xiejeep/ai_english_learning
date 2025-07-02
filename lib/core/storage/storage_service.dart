import 'package:get_storage/get_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  
  // 新增：访问token管理
  static Future<void> saveAccessToken(String token) async {
    await _storage.write(AppConstants.tokenKey, token);
  }
  
  static String? getAccessToken() {
    return _storage.read(AppConstants.tokenKey);
  }
  
  // 新增：刷新token管理
  static Future<void> saveRefreshToken(String refreshToken) async {
    await _storage.write('${AppConstants.tokenKey}_refresh', refreshToken);
  }
  
  static String? getRefreshToken() {
    return _storage.read('${AppConstants.tokenKey}_refresh');
  }
  
  // 新增：token过期时间管理
  static Future<void> saveTokenExpiry(String expiryTime) async {
    await _storage.write('${AppConstants.tokenKey}_expiry', expiryTime);
  }
  
  static String? getTokenExpiry() {
    return _storage.read('${AppConstants.tokenKey}_expiry');
  }
  
  static Future<void> saveUserInfo(Map<String, dynamic> userInfo) async {
    await _storage.write(AppConstants.userInfoKey, userInfo);
  }
  
  static Map<String, dynamic>? getUserInfo() {
    return _storage.read(AppConstants.userInfoKey);
  }
  
  // 新增：用户信息别名方法
  static Future<void> saveUser(Map<String, dynamic> userInfo) async {
    await saveUserInfo(userInfo);
  }
  
  static Map<String, dynamic>? getUser() {
    return getUserInfo();
  }
  
  static Future<void> clearUserData() async {
    await _storage.remove(AppConstants.tokenKey);
    await _storage.remove(AppConstants.userInfoKey);
  }
  
  // 新增：清除所有认证数据
  static Future<void> clearAuthData() async {
    await _storage.remove(AppConstants.tokenKey);
    await _storage.remove('${AppConstants.tokenKey}_refresh');
    await _storage.remove('${AppConstants.tokenKey}_expiry');
    await _storage.remove(AppConstants.userInfoKey);
  }
  
  // 新增：同步清除所有认证数据（用于拦截器）
  static void clearAuthDataSync() {
    _storage.remove(AppConstants.tokenKey);
    _storage.remove('${AppConstants.tokenKey}_refresh');
    _storage.remove('${AppConstants.tokenKey}_expiry');
    _storage.remove(AppConstants.userInfoKey);
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
  
  // 记住账号功能
  static Future<void> saveRememberAccount(bool remember) async {
    await _storage.write(AppConstants.rememberAccountKey, remember);
  }
  
  static bool getRememberAccount() {
    return _storage.read(AppConstants.rememberAccountKey) ?? false;
  }
  
  static Future<void> saveLastLoginEmail(String email) async {
    await _storage.write(AppConstants.lastLoginEmailKey, email);
  }
  
  static String? getLastLoginEmail() {
    return _storage.read(AppConstants.lastLoginEmailKey);
  }
  
  static Future<void> saveRememberedAccounts(List<String> accounts) async {
    await _storage.write(AppConstants.rememberedAccountsKey, accounts);
  }
  
  static List<String> getRememberedAccounts() {
    final accounts = _storage.read(AppConstants.rememberedAccountsKey);
    if (accounts is List) {
      return accounts.cast<String>();
    }
    return [];
  }
  
  static Future<void> addRememberedAccount(String email) async {
    final accounts = getRememberedAccounts();
    if (!accounts.contains(email)) {
      accounts.insert(0, email); // 最新的账号放在前面
      // 最多保存10个账号
      if (accounts.length > 10) {
        accounts.removeRange(10, accounts.length);
      }
      await saveRememberedAccounts(accounts);
    }
  }
  
  static Future<void> removeRememberedAccount(String email) async {
    final accounts = getRememberedAccounts();
    accounts.remove(email);
    await saveRememberedAccounts(accounts);
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

// Provider定义
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});