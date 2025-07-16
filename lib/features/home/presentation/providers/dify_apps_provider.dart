import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/services/dify_app_service.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../shared/models/dify_app_model.dart';

// Dify应用状态
class DifyAppsState {
  final bool isLoading;
  final List<DifyApp> apps;
  final String? errorMessage;
  final bool hasLoaded; // 标记是否已经加载过，防止重复请求
  final bool isFromCache; // 标记数据是否来自缓存
  final DateTime? cacheTime; // 缓存时间

  const DifyAppsState({
    this.isLoading = false,
    this.apps = const [],
    this.errorMessage,
    this.hasLoaded = false,
    this.isFromCache = false,
    this.cacheTime,
  });

  DifyAppsState copyWith({
    bool? isLoading,
    List<DifyApp>? apps,
    String? errorMessage,
    bool? hasLoaded,
    bool? isFromCache,
    DateTime? cacheTime,
  }) {
    return DifyAppsState(
      isLoading: isLoading ?? this.isLoading,
      apps: apps ?? this.apps,
      errorMessage: errorMessage,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      isFromCache: isFromCache ?? this.isFromCache,
      cacheTime: cacheTime ?? this.cacheTime,
    );
  }
}

// Dify应用服务提供者
final difyAppServiceProvider = Provider<DifyAppService>((ref) {
  return DifyAppService();
});

// Dify应用状态管理
class DifyAppsNotifier extends StateNotifier<DifyAppsState> {
  final DifyAppService _difyAppService;

  DifyAppsNotifier(this._difyAppService) : super(const DifyAppsState());

  // 获取Dify应用列表（带缓存功能）
  Future<void> loadDifyApps() async {
    if (state.isLoading) return; // 防止重复请求

    // 先尝试加载缓存数据
    await _loadFromCache();
    
    // 然后在后台获取最新数据
    await _loadFromNetwork();
  }
  
  // 从缓存加载数据
  Future<void> _loadFromCache() async {
    try {
      final cachedAppsData = StorageService.getDifyAppsCache();
      final cacheTime = StorageService.getDifyAppsCacheTime();
      
      if (cachedAppsData != null && cachedAppsData.isNotEmpty) {
        // 将缓存的 Map 数据转换为 DifyApp 对象
        final cachedApps = cachedAppsData.map((appData) => DifyApp.fromJson(appData)).toList();
        
        state = state.copyWith(
          apps: cachedApps,
          isFromCache: true,
          cacheTime: cacheTime,
          hasLoaded: true,
          errorMessage: null,
        );
        
        print('📦 从缓存加载Dify应用列表成功，共${cachedApps.length}个应用');
        if (cacheTime != null) {
          print('📅 缓存时间: ${cacheTime.toString()}');
        }
      }
    } catch (e) {
      print('❌ 加载缓存数据失败: $e');
    }
  }
  
  // 从网络获取最新数据
  Future<void> _loadFromNetwork() async {
    // 只有在没有缓存数据时才显示加载状态
    final shouldShowLoading = state.apps.isEmpty;
    if (shouldShowLoading) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    } else {
      // 有缓存数据时，清除错误信息但不显示加载状态
      state = state.copyWith(errorMessage: null);
    }

    try {
      final response = await _difyAppService.getDifyApps();
      
      if (response.success) {
        // 保存到缓存
        final appsData = response.data.map((app) => app.toJson()).toList();
        await StorageService.saveDifyAppsCache(appsData);
        
        state = state.copyWith(
          isLoading: false,
          apps: response.data,
          errorMessage: null,
          hasLoaded: true,
          isFromCache: false,
          cacheTime: DateTime.now(),
        );
        print('✅ Dify应用列表网络加载成功，共${response.data.length}个应用，已更新缓存');
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: response.message.isNotEmpty ? response.message : '获取应用列表失败',
          hasLoaded: true,
        );
        print('❌ 获取应用列表失败: ${response.message}');
      }
    } catch (e) {
      String errorMessage = '获取应用列表失败，请重试';
      
      // 处理DioException，提取服务器返回的具体错误信息
      if (e is DioException && e.response != null) {
        final statusCode = e.response!.statusCode;
        final responseData = e.response!.data;
        
        if (responseData is Map<String, dynamic> && responseData['message'] != null) {
          errorMessage = responseData['message'];
        } else {
          switch (statusCode) {
            case 400:
              errorMessage = '请求参数错误';
              break;
            case 401:
              errorMessage = '登录已过期，请重新登录';
              break;
            case 403:
              errorMessage = '没有权限访问应用列表';
              break;
            case 404:
              errorMessage = '应用列表接口不存在';
              break;
            case 500:
              errorMessage = '服务器内部错误，请稍后重试';
              break;
            default:
              errorMessage = '获取应用列表失败，请重试';
          }
        }
      } else if (e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
        errorMessage = '网络连接失败，请检查网络设置';
      } else if (e.toString().contains('FormatException')) {
        errorMessage = '数据格式错误，请重试';
      }
      
      state = state.copyWith(
        isLoading: false,
        errorMessage: errorMessage,
        hasLoaded: true,
      );
      print('❌ 获取Dify应用列表异常: $e');
    }
  }

  // 处理登录成功时的应用列表加载
  Future<void> loadAppsAfterLogin() async {
    print('🔑 [DifyAppsNotifier] 处理登录成功，重新加载应用列表');
    // 完全重置状态，确保获取最新数据
    state = const DifyAppsState();
    await loadDifyApps();
  }

  // 强制刷新应用列表（清空当前数据和缓存重新加载）
  Future<void> forceRefresh() async {
    print('🔄 [DifyAppsNotifier] 强制刷新应用列表，清除所有状态和缓存');
    // 清除缓存
    await StorageService.clearDifyAppsCache();
    // 完全重置状态，包括清除错误信息
    state = const DifyAppsState();
    // 直接从网络加载，跳过缓存
    await _loadFromNetwork();
  }

  // 刷新应用列表（仅从网络获取最新数据）
  Future<void> refreshApps() async {
    print('🔄 [DifyAppsNotifier] 刷新应用列表，从网络获取最新数据');
    // 直接从网络加载最新数据，不清除缓存
    await _loadFromNetwork();
  }

  // 清除错误信息
  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }

  // 重置状态到初始状态
  void reset() {
    state = const DifyAppsState();
  }
}

// Dify应用状态提供者
final difyAppsProvider = StateNotifierProvider<DifyAppsNotifier, DifyAppsState>((ref) {
  final difyAppService = ref.read(difyAppServiceProvider);
  return DifyAppsNotifier(difyAppService);
});