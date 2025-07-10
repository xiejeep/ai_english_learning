import 'package:dio/dio.dart';
import '../network/dio_client.dart';
import '../constants/app_constants.dart';
import '../../shared/models/dify_app_model.dart';

// Dify应用服务
class DifyAppService {
  final Dio _dio;

  DifyAppService() : _dio = DioClient.instance;

  // 获取用户的Dify应用列表
  Future<DifyAppsResponse> getDifyApps() async {
    try {
      print('🔄 开始获取Dify应用列表...');
      
      final response = await _dio.get(AppConstants.difyAppsPath);
      
      print('✅ 成功获取Dify应用列表');
      return DifyAppsResponse.fromJson(response.data);
    } catch (e) {
      print('❌ 获取Dify应用列表失败: $e');
      // 重新抛出原始异常，让上层处理具体错误信息
      rethrow;
    }
  }
}