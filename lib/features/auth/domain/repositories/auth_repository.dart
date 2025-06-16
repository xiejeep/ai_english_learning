import '../entities/auth_user.dart';
import '../../data/models/auth_request_model.dart';
import '../../data/models/auth_response_model.dart';

// 认证Repository接口（根据API文档）
abstract class AuthRepository {
  // 登录
  Future<LoginResponse> login(LoginRequest request);
  
  // 注册
  Future<RegisterResponse> register(RegisterRequest request);
  
  // 发送验证码
  Future<VerificationCodeResponse> sendVerificationCode(VerificationCodeRequest request);
  
  // 发送密码重置验证码
  Future<VerificationCodeResponse> sendResetCode(VerificationCodeRequest request);
  
  // 重置密码
  Future<VerificationCodeResponse> resetPassword(ResetPasswordRequest request);
  
  // 检查登录状态
  Future<bool> isLoggedIn();
  
  // 本地保存认证信息
  Future<void> saveAuthData(AuthResponseData authData);
  
  // 清除本地认证信息
  Future<void> clearAuthData();
  
  // 获取本地保存的token
  Future<String?> getAccessToken();
  
  // 获取当前用户信息（从本地存储）
  Future<AuthUser?> getCurrentUser();
  
  // 退出登录（仅清除本地数据）
  Future<void> logout();
}