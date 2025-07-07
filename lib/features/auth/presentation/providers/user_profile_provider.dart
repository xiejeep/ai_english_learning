import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../shared/models/user_model.dart';

/// 用户完整信息模型
class UserProfile {
  final UserModel user;
  final int credits;
  final int tokenBalance;
  
  const UserProfile({
    required this.user,
    required this.credits,
    required this.tokenBalance,
  });
  
  UserProfile copyWith({
    UserModel? user,
    int? credits,
    int? tokenBalance,
  }) {
    return UserProfile(
      user: user ?? this.user,
      credits: credits ?? this.credits,
      tokenBalance: tokenBalance ?? this.tokenBalance,
    );
  }
}

/// 全局用户Profile Provider
/// 统一管理用户基本信息、积分余额、token余额
final userProfileProvider = AutoDisposeFutureProvider<UserProfile>((ref) async {
  final dio = Dio();
  final token = StorageService.getUserToken();
  print('[UserProfile] 查询用户完整信息, token: ${token?.substring(0, 8) ?? 'null'}...');
  if (token == null) throw Exception('未登录，无法获取用户信息');
  
  final url = AppConstants.baseUrl + 'api/user/profile';
  print('[UserProfile] 请求url: $url');
  
  try {
    final response = await dio.get(
      url,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    print('[UserProfile] 响应: ${response.data}');
    final data = response.data;
    
    // 解析用户基本信息
    final userMap = data['user'] ?? data;
    final user = UserModel.fromJson(userMap);
    
    // 获取积分和token余额
    final credits = data['credits'] ?? 0;
    final tokenBalance = data['tokenBalance'] ?? 0;
    
    return UserProfile(
      user: user,
      credits: credits,
      tokenBalance: tokenBalance,
    );
  } catch (e) {
    print('[UserProfile] 异常: $e');
    rethrow;
  }
});

/// 兼容性Provider - 从userProfileProvider中提取积分余额
final creditsBalanceFromProfileProvider = AutoDisposeFutureProvider<int>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  return profile.credits;
});

/// 兼容性Provider - 从userProfileProvider中提取token余额
final tokenBalanceFromProfileProvider = AutoDisposeFutureProvider<int>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  return profile.tokenBalance;
});