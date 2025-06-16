import '../../domain/entities/auth_user.dart';

// 基础API响应模型
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final int? code;

  const ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.code,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse<T>(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null && fromJsonT != null 
          ? fromJsonT(json['data']) 
          : json['data'],
      code: json['code'],
    );
  }

  @override
  String toString() {
    return 'ApiResponse(success: $success, message: $message, data: $data, code: $code)';
  }
}

// 认证响应数据模型（根据API文档）
class AuthResponseData {
  final String accessToken;
  final AuthUserModel user;

  const AuthResponseData({
    required this.accessToken,
    required this.user,
  });

  factory AuthResponseData.fromJson(Map<String, dynamic> json) {
    return AuthResponseData(
      accessToken: json['access_token'] ?? '',
      user: AuthUserModel.fromJson(json['user'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'user': user.toJson(),
    };
  }

  @override
  String toString() {
    return 'AuthResponseData(accessToken: ${accessToken.length > 20 ? '${accessToken.substring(0, 20)}...' : accessToken}, user: $user)';
  }
}

// 用户数据模型（继承自领域实体）
class AuthUserModel extends AuthUser {
  const AuthUserModel({
    required super.id,
    required super.username,
    required super.email,
    super.phone,
    super.avatar,
    required super.createdAt,
    super.updatedAt,
  });

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    return AuthUserModel(
      id: json['id']?.toString() ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      avatar: json['avatar'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'phone': phone,
      'avatar': avatar,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // 从领域实体转换
  factory AuthUserModel.fromEntity(AuthUser user) {
    return AuthUserModel(
      id: user.id,
      username: user.username,
      email: user.email,
      phone: user.phone,
      avatar: user.avatar,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }

  // 转换为领域实体
  AuthUser toEntity() {
    return AuthUser(
      id: id,
      username: username,
      email: email,
      phone: phone,
      avatar: avatar,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

// 登录响应类型定义 - 直接使用AuthResponseData（根据API文档）
typedef LoginResponse = AuthResponseData;

// 注册响应类型定义 - 直接使用AuthResponseData（根据API文档）
typedef RegisterResponse = AuthResponseData;

// 验证码发送响应（根据API文档）
class VerificationCodeResponse {
  final String message;

  const VerificationCodeResponse({
    required this.message,
  });

  factory VerificationCodeResponse.fromJson(Map<String, dynamic> json) {
    return VerificationCodeResponse(
      message: json['message'] ?? '',
    );
  }

  @override
  String toString() {
    return 'VerificationCodeResponse(message: $message)';
  }
}

// 验证码验证响应
class VerificationCodeVerifyResponse {
  final bool success;
  final String message;
  final bool valid; // 验证码是否有效
  final String? token; // 验证通过后的临时token

  const VerificationCodeVerifyResponse({
    required this.success,
    required this.message,
    required this.valid,
    this.token,
  });

  factory VerificationCodeVerifyResponse.fromJson(Map<String, dynamic> json) {
    return VerificationCodeVerifyResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      valid: json['valid'] ?? false,
      token: json['token'],
    );
  }

  @override
  String toString() {
    return 'VerificationCodeVerifyResponse(success: $success, message: $message, valid: $valid, token: ${token?.substring(0, 20)}...)';
  }
}

// Token刷新响应
class RefreshTokenResponse {
  final bool success;
  final String message;
  final String? accessToken;
  final int? expiresIn;

  const RefreshTokenResponse({
    required this.success,
    required this.message,
    this.accessToken,
    this.expiresIn,
  });

  factory RefreshTokenResponse.fromJson(Map<String, dynamic> json) {
    return RefreshTokenResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      accessToken: json['access_token'],
      expiresIn: json['expires_in'],
    );
  }

  @override
  String toString() {
    return 'RefreshTokenResponse(success: $success, message: $message, accessToken: ${accessToken?.substring(0, 20)}..., expiresIn: $expiresIn)';
  }
} 