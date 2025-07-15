import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/services/dify_app_service.dart';
import '../../../../shared/models/dify_app_model.dart';

// Dify应用状态
class DifyAppsState {
  final bool isLoading;
  final List<DifyApp> apps;
  final String? errorMessage;
  final bool hasLoaded; // 标记是否已经加载过，防止重复请求

  const DifyAppsState({
    this.isLoading = false,
    this.apps = const [],
    this.errorMessage,
    this.hasLoaded = false,
  });

  DifyAppsState copyWith({
    bool? isLoading,
    List<DifyApp>? apps,
    String? errorMessage,
    bool? hasLoaded,
  }) {
    return DifyAppsState(
      isLoading: isLoading ?? this.isLoading,
      apps: apps ?? this.apps,
      errorMessage: errorMessage,
      hasLoaded: hasLoaded ?? this.hasLoaded,
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

  // 获取Dify应用列表
  Future<void> loadDifyApps() async {
    if (state.isLoading) return; // 防止重复请求

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _difyAppService.getDifyApps();
      
      if (response.success) {
        state = state.copyWith(
          isLoading: false,
          apps: response.data,
          errorMessage: null,
          hasLoaded: true,
        );
        print('✅ Dify应用列表加载成功，共${response.data.length}个应用');
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

  // 强制刷新应用列表（清空当前数据重新加载）
  Future<void> forceRefresh() async {
    print('🔄 [DifyAppsNotifier] 强制刷新应用列表，清除所有状态');
    // 完全重置状态，包括清除错误信息
    state = const DifyAppsState();
    await loadDifyApps();
  }

  // 刷新应用列表
  Future<void> refreshApps() async {
    // 重置加载状态，允许重新加载
    state = state.copyWith(hasLoaded: false);
    await loadDifyApps();
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