import '../../domain/entities/auth_user.dart';

// 认证状态枚举
enum AuthStatus {
  initial,       // 初始状态
  loading,       // 加载中
  authenticated, // 已认证
  unauthenticated, // 未认证
  error,         // 错误状态
}

// 认证状态
class AuthState {
  final AuthStatus status;
  final AuthUser? user;
  final String? errorMessage;
  final bool isLoading;
  
  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
    this.isLoading = false,
  });

  // 初始状态
  const AuthState.initial()
      : status = AuthStatus.initial,
        user = null,
        errorMessage = null,
        isLoading = false;

  // 加载状态
  const AuthState.loading()
      : status = AuthStatus.loading,
        user = null,
        errorMessage = null,
        isLoading = true;

  // 已认证状态
  const AuthState.authenticated(this.user)
      : status = AuthStatus.authenticated,
        errorMessage = null,
        isLoading = false;

  // 未认证状态
  const AuthState.unauthenticated([this.errorMessage])
      : status = AuthStatus.unauthenticated,
        user = null,
        isLoading = false;

  // 错误状态
  const AuthState.error(this.errorMessage)
      : status = AuthStatus.error,
        user = null,
        isLoading = false;

  // 复制状态并更新指定字段
  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    String? errorMessage,
    bool? isLoading,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  // 便捷方法
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;
  bool get hasError => status == AuthStatus.error;
  bool get isInitial => status == AuthStatus.initial;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AuthState &&
        other.status == status &&
        other.user == user &&
        other.errorMessage == errorMessage &&
        other.isLoading == isLoading;
  }

  @override
  int get hashCode {
    return status.hashCode ^
        user.hashCode ^
        errorMessage.hashCode ^
        isLoading.hashCode;
  }

  @override
  String toString() {
    return 'AuthState(status: $status, user: $user, errorMessage: $errorMessage, isLoading: $isLoading)';
  }
}

// 登录表单状态
class LoginFormState {
  final String email;
  final String password;
  final bool isEmailValid;
  final bool isPasswordValid;
  final bool isFormValid;
  final bool isLoading;
  final String? errorMessage;

  const LoginFormState({
    this.email = '',
    this.password = '',
    this.isEmailValid = false,
    this.isPasswordValid = false,
    this.isFormValid = false,
    this.isLoading = false,
    this.errorMessage,
  });

  LoginFormState copyWith({
    String? email,
    String? password,
    bool? isEmailValid,
    bool? isPasswordValid,
    bool? isFormValid,
    bool? isLoading,
    String? errorMessage,
  }) {
    return LoginFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      isEmailValid: isEmailValid ?? this.isEmailValid,
      isPasswordValid: isPasswordValid ?? this.isPasswordValid,
      isFormValid: isFormValid ?? this.isFormValid,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  @override
  String toString() {
    return 'LoginFormState(email: $email, password: [HIDDEN], isEmailValid: $isEmailValid, isPasswordValid: $isPasswordValid, isFormValid: $isFormValid, isLoading: $isLoading, errorMessage: $errorMessage)';
  }
}

// 注册表单状态
class RegisterFormState {
  final String email;
  final String phone;
  final String password;
  final String confirmPassword;
  final String verificationCode;
  final bool isEmailValid;
  final bool isPasswordValid;
  final bool isPasswordMatching;
  final bool isVerificationCodeValid;
  final bool isFormValid;
  final bool isLoading; // For overall form submission
  final bool isSendingCode; // True when 'send code' API is in progress
  final bool isCodeSentSuccessfully; // True if code was sent and cooldown is active
  final int codeCooldownSeconds;
  final String? errorMessage;

  const RegisterFormState({
    this.email = '',
    this.phone = '',
    this.password = '',
    this.confirmPassword = '',
    this.verificationCode = '',
    this.isEmailValid = false,
    this.isPasswordValid = false,
    this.isPasswordMatching = false,
    this.isVerificationCodeValid = false,
    this.isFormValid = false,
    this.isLoading = false,
    this.isSendingCode = false, // Initialize isSendingCode
    this.isCodeSentSuccessfully = false, // Rename and initialize
    this.codeCooldownSeconds = 0,
    this.errorMessage,
  });

  RegisterFormState copyWith({
    String? email,
    String? phone,
    String? password,
    String? confirmPassword,
    String? verificationCode,
    bool? isEmailValid,
    bool? isPasswordValid,
    bool? isPasswordMatching,
    bool? isVerificationCodeValid,
    bool? isFormValid,
    bool? isLoading,
    bool? isSendingCode, // Add isSendingCode to copyWith
    bool? isCodeSentSuccessfully, // Rename in copyWith
    int? codeCooldownSeconds,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return RegisterFormState(
      email: email ?? this.email,
      phone: phone ?? this.phone,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      verificationCode: verificationCode ?? this.verificationCode,
      isEmailValid: isEmailValid ?? this.isEmailValid,
      isPasswordValid: isPasswordValid ?? this.isPasswordValid,
      isPasswordMatching: isPasswordMatching ?? this.isPasswordMatching,
      isVerificationCodeValid: isVerificationCodeValid ?? this.isVerificationCodeValid,
      isFormValid: isFormValid ?? this.isFormValid,
      isLoading: isLoading ?? this.isLoading,
      isSendingCode: isSendingCode ?? this.isSendingCode, // Update copyWith
      isCodeSentSuccessfully: isCodeSentSuccessfully ?? this.isCodeSentSuccessfully, // Update copyWith
      codeCooldownSeconds: codeCooldownSeconds ?? this.codeCooldownSeconds,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() {
    return 'RegisterFormState(email: $email, phone: $phone, password: [HIDDEN], confirmPassword: [HIDDEN], verificationCode: $verificationCode, isEmailValid: $isEmailValid, isPasswordValid: $isPasswordValid, isPasswordMatching: $isPasswordMatching, isVerificationCodeValid: $isVerificationCodeValid, isFormValid: $isFormValid, isLoading: $isLoading, isSendingCode: $isSendingCode, isCodeSentSuccessfully: $isCodeSentSuccessfully, codeCooldownSeconds: $codeCooldownSeconds, errorMessage: $errorMessage)';
  }
}