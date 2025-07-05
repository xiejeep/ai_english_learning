import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/storage_service.dart';

/// 全局积分余额Provider
final creditsBalanceProvider = AutoDisposeFutureProvider<int>((ref) async {
  final dio = Dio();
  final token = StorageService.getUserToken();
  print('[Credits] 查询积分余额, token: \\${token?.substring(0, 8) ?? 'null'}...');
  if (token == null) throw Exception('未登录，无法获取token');
  final url = AppConstants.baseUrl + 'api/credits/balance';
  print('[Credits] 请求url: $url');
  try {
    final response = await dio.get(
      url,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    print('[Credits] 响应: \\${response.data}');
    final data = response.data;
    return data['credits'] ?? 0;
  } catch (e) {
    print('[Credits] 异常: $e');
    rethrow;
  }
}); 

/// 全局token余额Provider
final tokenBalanceProvider = AutoDisposeFutureProvider<int>((ref) async {
  final dio = Dio();
  final token = StorageService.getUserToken();
  print('[Token] 查询token余额, token: \\${token?.substring(0, 8) ?? 'null'}...');
  if (token == null) throw Exception('未登录，无法获取token');
  final url = AppConstants.baseUrl + 'api/credits/token-balance';
  print('[Token] 请求url: $url');
  try {
    final response = await dio.get(
      url,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    print('[Token] 响应: \\${response.data}');
    final data = response.data;
    return data['tokenBalance'] ?? 0;
  } catch (e) {
    print('[Token] 异常: $e');
    rethrow;
  }
}); 