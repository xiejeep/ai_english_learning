// 登录请求模型
class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }

  @override
  String toString() {
    return 'LoginRequest(email: $email, password: [HIDDEN])';
  }
}

// 注册请求模型（根据API文档）
class RegisterRequest {
  final String username;
  final String email;
  final String password;
  final String code; // 验证码，根据API文档是必需的

  const RegisterRequest({
    required this.username,
    required this.email,
    required this.password,
    required this.code,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'password': password,
      'code': code,
    };
  }

  // 验证邮箱格式
  bool get isEmailValid {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // 验证密码强度（至少8位，包含字母和数字）
  bool get isPasswordValid {
    return password.length >= 8 && 
           RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(password);
  }

  // 验证用户名（3-20位，字母数字下划线）
  bool get isUsernameValid {
    return username.length >= 3 && 
           username.length <= 20 && 
           RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username);
  }

  // 验证验证码（6位数字）
  bool get isCodeValid {
    return code.length == 6 && RegExp(r'^[0-9]{6}$').hasMatch(code);
  }

  @override
  String toString() {
    return 'RegisterRequest(username: $username, email: $email, password: [HIDDEN], code: $code)';
  }
}

// 验证码发送请求模型（根据API文档）
class VerificationCodeRequest {
  final String email;

  const VerificationCodeRequest({
    required this.email,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
    };
  }

  @override
  String toString() {
    return 'VerificationCodeRequest(email: $email)';
  }
}

// 验证码验证请求模型
class VerificationCodeVerifyRequest {
  final String email;
  final String code;
  final String type;

  const VerificationCodeVerifyRequest({
    required this.email,
    required this.code,
    required this.type,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'code': code,
      'type': type,
    };
  }

  @override
  String toString() {
    return 'VerificationCodeVerifyRequest(email: $email, code: $code, type: $type)';
  }
}

// 重置密码请求模型
class ResetPasswordRequest {
  final String email;
  final String newPassword;
  final String confirmPassword;
  final String verificationCode;

  const ResetPasswordRequest({
    required this.email,
    required this.newPassword,
    required this.confirmPassword,
    required this.verificationCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'newPassword': newPassword,
      'code': verificationCode,
    };
  }

  bool get passwordsMatch => newPassword == confirmPassword;

  @override
  String toString() {
    return 'ResetPasswordRequest(email: $email, newPassword: [HIDDEN], confirmPassword: [HIDDEN], verificationCode: $verificationCode)';
  }
}