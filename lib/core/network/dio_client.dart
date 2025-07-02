import 'package:dio/dio.dart';
import 'package:get_storage/get_storage.dart';
import '../constants/app_constants.dart';
import '../storage/storage_service.dart';

class DioClient {
  static late Dio _dio;
  static final GetStorage _storage = GetStorage();
  
  // Token过期处理回调
  static void Function()? _onTokenExpired;
  
  static Dio get instance => _dio;
  
  static void initialize({void Function()? onTokenExpired}) {
    _onTokenExpired = onTokenExpired;
    
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(milliseconds: AppConstants.defaultTimeout),
      receiveTimeout: const Duration(milliseconds: AppConstants.defaultTimeout),
      sendTimeout: const Duration(milliseconds: AppConstants.defaultTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    _addInterceptors();
  }
  
  static void _addInterceptors() {
    // 请求拦截器
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // 添加认证token
        final token = _storage.read(AppConstants.tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        
        print('🚀 请求: ${options.method} ${options.uri}');
        print('📤 请求头: ${options.headers}');
        if (options.data != null) {
          print('📦 请求体: ${options.data}');
        }
        
        handler.next(options);
      },
      onResponse: (response, handler) {
        print('✅ 响应: ${response.statusCode} ${response.requestOptions.uri}');
        print('📥 响应数据: ${response.data}');
        handler.next(response);
      },
      onError: (error, handler) {
        print('❌ 错误: ${error.message}');
        print('📍 请求: ${error.requestOptions.uri}');
        if (error.response != null) {
          print('📦 错误响应体: ${error.response?.data}');
        }
        
        // 处理token过期
        if (error.response?.statusCode == 401) {
          _handleTokenExpired();
        }
        
        handler.next(error);
      },
    ));
    
    // 重试拦截器
    _dio.interceptors.add(RetryInterceptor());
  }
  
  static void _handleTokenExpired() {
    print('🔐 检测到Token过期，开始清理认证数据');
    
    // 使用StorageService同步清除所有认证数据
    try {
      StorageService.clearAuthDataSync();
      print('✅ 本地认证数据已清除');
    } catch (e) {
      print('❌ 清除认证数据失败: $e');
      // 即使清除失败也要继续执行回调
    }
    
    // 调用token过期处理回调
    if (_onTokenExpired != null) {
      _onTokenExpired!();
      print('✅ Token过期处理回调已执行');
    }
  }
  
  // 设置token过期处理回调
  static void setTokenExpiredCallback(void Function() callback) {
    _onTokenExpired = callback;
  }
}

class RetryInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldRetry(err)) {
      try {
        final response = await _retry(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (e) {
        // 重试失败，继续抛出原始错误
      }
    }
    
    handler.next(err);
  }
  
  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
           err.type == DioExceptionType.receiveTimeout ||
           err.type == DioExceptionType.sendTimeout ||
           (err.response?.statusCode != null && 
            err.response!.statusCode! >= 500);
  }
  
  Future<Response> _retry(RequestOptions requestOptions) async {
    final options = Options(
      method: requestOptions.method,
      headers: requestOptions.headers,
    );
    
    return DioClient.instance.request(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }
} 