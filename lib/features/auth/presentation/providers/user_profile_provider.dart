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

/// 用户Profile状态管理器
class UserProfileNotifier extends StateNotifier<AsyncValue<UserProfile>> {
  UserProfileNotifier() : super(const AsyncValue.loading()) {
    loadUserProfile();
  }
  
  /// 加载用户完整信息
  Future<void> loadUserProfile() async {
    state = const AsyncValue.loading();
    
    try {
      final dio = Dio();
      final token = StorageService.getUserToken();
      print('[UserProfile] 查询用户完整信息, token: ${token?.substring(0, 8) ?? 'null'}...');
      if (token == null) throw Exception('未登录，无法获取用户信息');
      
      final url = AppConstants.baseUrl + 'api/user/profile';
      print('[UserProfile] 请求url: $url');
      
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
      
      final profile = UserProfile(
        user: user,
        credits: credits,
        tokenBalance: tokenBalance,
      );
      
      state = AsyncValue.data(profile);
      
      // 同步更新本地存储
      await StorageService.saveCreditsBalance(credits);
      
    } catch (e) {
      print('[UserProfile] 异常: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
  
  /// 更新积分余额（乐观更新）
  void updateCredits(int newCredits) {
    state.whenData((profile) {
      final updatedProfile = profile.copyWith(credits: newCredits);
      state = AsyncValue.data(updatedProfile);
      
      // 同步更新本地存储
      StorageService.saveCreditsBalance(newCredits);
    });
  }
  
  /// 更新Token余额（乐观更新）
  void updateTokenBalance(int newTokenBalance) {
    state.whenData((profile) {
      final updatedProfile = profile.copyWith(tokenBalance: newTokenBalance);
      state = AsyncValue.data(updatedProfile);
    });
  }
  
  /// 同时更新积分和Token余额
  void updateCreditsAndTokens(int newCredits, int newTokenBalance) {
    print('[UserProfile] 更新积分和Token余额: credits=$newCredits, tokens=$newTokenBalance');
    state.whenData((profile) {
      print('[UserProfile] 当前状态: credits=${profile.credits}, tokens=${profile.tokenBalance}');
      final updatedProfile = profile.copyWith(
        credits: newCredits,
        tokenBalance: newTokenBalance,
      );
      state = AsyncValue.data(updatedProfile);
      print('[UserProfile] 更新后状态: credits=${updatedProfile.credits}, tokens=${updatedProfile.tokenBalance}');
      
      // 同步更新本地存储
      StorageService.saveCreditsBalance(newCredits);
    });
  }
  
  /// 刷新用户信息
  Future<void> refresh() async {
    await loadUserProfile();
  }
}

/// 全局用户Profile Provider
/// 统一管理用户基本信息、积分余额、token余额
final userProfileProvider = StateNotifierProvider<UserProfileNotifier, AsyncValue<UserProfile>>((ref) {
  return UserProfileNotifier();
});

/// 兼容性Provider - 用于只需要积分余额的地方
final creditsBalanceFromProfileProvider = Provider<AsyncValue<int>>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.when(
    data: (profile) => AsyncValue.data(profile.credits),
    loading: () => const AsyncValue.loading(),
    error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
  );
});

// 兼容性Provider - 用于只需要token余额的地方
final tokenBalanceFromProfileProvider = Provider<AsyncValue<int>>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.when(
    data: (profile) => AsyncValue.data(profile.tokenBalance),
    loading: () => const AsyncValue.loading(),
    error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
  );
});

// 简化的同步访问器（当数据已加载时）
final currentCreditsProvider = Provider<int?>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.maybeWhen(
    data: (profile) => profile.credits,
    orElse: () => null,
  );
});

final currentTokenBalanceProvider = Provider<int?>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.maybeWhen(
    data: (profile) => profile.tokenBalance,
    orElse: () => null,
  );
});