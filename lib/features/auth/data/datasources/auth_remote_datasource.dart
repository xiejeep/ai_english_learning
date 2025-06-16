import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/auth_request_model.dart';
import '../models/auth_response_model.dart';

// 认证远程数据源
class AuthRemoteDataSource {
  final Dio _dio;

  AuthRemoteDataSource() : _dio = DioClient.instance;

  // 登录
  Future<LoginResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post(
        AppConstants.authLoginPath,
        data: request.toJson(),
      );

      return AuthResponseData.fromJson(response.data);
    } catch (e) {
      // 重新抛出原始异常，让上层处理具体错误信息
      rethrow;
    }
  }

  // 注册
  Future<RegisterResponse> register(RegisterRequest request) async {
    try {
      final response = await _dio.post(
        AppConstants.authRegisterPath,
        data: request.toJson(),
      );

      return AuthResponseData.fromJson(response.data);
    } catch (e) {
      // 重新抛出原始异常，让上层处理具体错误信息
      rethrow;
    }
  }

  // 发送验证码
  Future<VerificationCodeResponse> sendVerificationCode(
    VerificationCodeRequest request,
  ) async {
    try {
      final response = await _dio.post(
        AppConstants.authSendCodePath,
        data: request.toJson(),
      );

      return VerificationCodeResponse.fromJson(response.data);
    } catch (e) {
      // 重新抛出原始异常，让上层处理具体错误信息
      rethrow;
    }
  }

  // 发送密码重置验证码
  Future<VerificationCodeResponse> sendResetCode(
    VerificationCodeRequest request,
  ) async {
    try {
      final response = await _dio.post(
        AppConstants.authSendResetCodePath,
        data: request.toJson(),
      );

      return VerificationCodeResponse.fromJson(response.data);
    } catch (e) {
      // 重新抛出原始异常，让上层处理具体错误信息
      rethrow;
    }
  }

  // 重置密码
  Future<VerificationCodeResponse> resetPassword(
    ResetPasswordRequest request,
  ) async {
    try {
      final response = await _dio.post(
        AppConstants.authResetPasswordPath,
        data: request.toJson(),
      );

      return VerificationCodeResponse.fromJson(response.data);
    } catch (e) {
      // 重新抛出原始异常，让上层处理具体错误信息
      rethrow;
    }
  }

  // 注意：根据API文档，暂时不提供以下功能：
  // - 验证码验证接口
  // - 刷新token接口
  // - 退出登录接口
  // - 获取当前用户信息接口
  // 这些功能可能需要在后续版本中实现
}