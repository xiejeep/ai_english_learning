import '../../../../core/storage/storage_service.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_request_model.dart';
import '../models/auth_response_model.dart';

// 认证Repository实现
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;

  AuthRepositoryImpl(this._remoteDataSource);

  @override
  Future<LoginResponse> login(LoginRequest request) async {
    try {
      final response = await _remoteDataSource.login(request);
      
      // 登录成功，保存认证数据
      await saveAuthData(response);
      
      return response;
    } catch (e) {
      // 重新抛出原始异常，让上层处理具体错误信息
      rethrow;
    }
  }

  @override
  Future<RegisterResponse> register(RegisterRequest request) async {
    try {
      final response = await _remoteDataSource.register(request);
      
      // 注册成功，保存认证数据
      await saveAuthData(response);
      
      return response;
    } catch (e) {
      // 重新抛出原始异常，让上层处理具体错误信息
      rethrow;
    }
  }

  @override
  Future<VerificationCodeResponse> sendVerificationCode(
    VerificationCodeRequest request,
  ) async {
    try {
      return await _remoteDataSource.sendVerificationCode(request);
    } catch (e) {
      // 重新抛出原始异常，让上层处理具体错误信息
      rethrow;
    }
  }

  @override
  Future<VerificationCodeResponse> sendResetCode(
    VerificationCodeRequest request,
  ) async {
    try {
      return await _remoteDataSource.sendResetCode(request);
    } catch (e) {
      // 重新抛出原始异常，让上层处理具体错误信息
      rethrow;
    }
  }

  @override
  Future<VerificationCodeResponse> resetPassword(
    ResetPasswordRequest request,
  ) async {
    try {
      return await _remoteDataSource.resetPassword(request);
    } catch (e) {
      // 重新抛出原始异常，让上层处理具体错误信息
      rethrow;
    }
  }

  // 注意：根据API文档，以下功能暂时不可用：
  // - 验证码验证
  // - 重置密码
  // - 刷新token
  // - 远程退出登录
  
  @override
  Future<AuthUser?> getCurrentUser() async {
    try {
      // 从本地存储获取用户信息
      final localUser = StorageService.getUser();
      if (localUser != null) {
        return AuthUserModel.fromJson(localUser).toEntity();
      }
      
      return null;
    } catch (e) {
      // 获取失败，返回null
      return null;
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    try {
      final token = await getAccessToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> saveAuthData(AuthResponseData authData) async {
    try {
      // 保存token
      await StorageService.saveAccessToken(authData.accessToken);
      
      // 保存用户信息
      await StorageService.saveUser(authData.user.toJson());
      
      print('✅ 认证数据保存成功');
    } catch (e) {
      print('❌ 保存认证数据失败: $e');
      // 本地存储失败，重新抛出原始异常
      rethrow;
    }
  }

  @override
  Future<void> clearAuthData() async {
    try {
      await StorageService.clearAuthData();
      print('✅ 认证数据清除成功');
    } catch (e) {
      print('❌ 清除认证数据失败: $e');
      // 本地存储失败，重新抛出原始异常
      rethrow;
    }
  }

  @override
  Future<String?> getAccessToken() async {
    try {
      return StorageService.getAccessToken();
    } catch (e) {
      print('❌ 获取访问token失败: $e');
      return null;
    }
  }

  @override
  Future<void> logout() async {
    try {
      // 只清除本地认证数据，不调用远程API
      await clearAuthData();
      print('✅ 退出登录成功');
    } catch (e) {
      print('❌ 退出登录失败: $e');
      // 退出登录失败，重新抛出原始异常
      rethrow;
    }
  }

  // 注意：由于API文档中没有刷新token接口，暂时移除自动刷新功能
}