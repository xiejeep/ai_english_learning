import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/models/auth_request_model.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

// 依赖注入提供者
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remoteDataSource = ref.read(authRemoteDataSourceProvider);
  return AuthRepositoryImpl(remoteDataSource);
});

// 认证状态管理
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(const AuthState.initial()) {
    _checkAuthStatus();
  }

  // 检查认证状态
  Future<void> _checkAuthStatus() async {
    try {
      state = const AuthState.loading();
      
      final isLoggedIn = await _authRepository.isLoggedIn();
      if (isLoggedIn) {
        final user = await _authRepository.getCurrentUser();
        if (user != null) {
          state = AuthState.authenticated(user);
        } else {
          state = const AuthState.unauthenticated();
        }
      } else {
        state = const AuthState.unauthenticated();
      }
    } catch (e) {
      // 认证状态检查失败时，默认设为未认证状态，避免显示错误信息
      state = const AuthState.unauthenticated();
    }
  }

  // 登录
  Future<bool> login(String email, String password) async {
    try {
      state = const AuthState.loading();
      
      final request = LoginRequest(email: email, password: password);
      final response = await _authRepository.login(request);
      
      final user = response.user.toEntity();
      state = AuthState.authenticated(user);
      return true;
    } catch (e) {
      String errorMessage = '登录失败，请检查邮箱和密码';
      
      // 处理DioException，提取服务器返回的具体错误信息
      if (e is DioException && e.response != null) {
        final statusCode = e.response!.statusCode;
        final responseData = e.response!.data;
        
        if (responseData is Map<String, dynamic> && responseData['message'] != null) {
          errorMessage = responseData['message'];
        } else {
          switch (statusCode) {
            case 400:
              errorMessage = '请求参数错误，请检查输入信息';
              break;
            case 401:
              errorMessage = '邮箱或密码错误，请重新输入';
              break;
            case 403:
              errorMessage = '账号已被禁用，请联系客服';
              break;
            case 404:
              errorMessage = '用户不存在，请检查邮箱地址';
              break;
            case 429:
              errorMessage = '登录尝试过于频繁，请稍后再试';
              break;
            case 500:
              errorMessage = '服务器错误，请稍后重试';
              break;
            default:
              errorMessage = '登录失败，请稍后重试';
          }
        }
      } else if (e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
        errorMessage = '网络连接失败，请检查网络设置';
      } else if (e.toString().contains('FormatException')) {
        errorMessage = '数据格式错误，请重试';
      }
      
      state = AuthState.error(errorMessage);
      return false;
    }
  }

  // 注册
  Future<bool> register(RegisterRequest request) async {
    try {
      state = const AuthState.loading();
      
      final response = await _authRepository.register(request);
      
      final user = response.user.toEntity();
      state = AuthState.authenticated(user);
      return true;
    } catch (e) {
      String errorMessage = '注册失败，请重试';
      
      // 处理DioException，提取服务器返回的具体错误信息
      if (e is DioException && e.response != null) {
        final statusCode = e.response!.statusCode;
        final responseData = e.response!.data;
        
        if (responseData is Map<String, dynamic> && responseData['message'] != null) {
          errorMessage = responseData['message'];
        } else {
          switch (statusCode) {
            case 400:
              errorMessage = '请求参数错误，请检查输入信息';
              break;
            case 409:
              errorMessage = '该邮箱已被注册，请使用其他邮箱';
              break;
            case 422:
              errorMessage = '输入信息格式不正确，请检查后重试';
              break;
            case 429:
              errorMessage = '注册请求过于频繁，请稍后再试';
              break;
            case 500:
              errorMessage = '服务器错误，请稍后重试';
              break;
            default:
              errorMessage = '注册失败，请稍后重试';
          }
        }
      } else if (e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
        errorMessage = '网络连接失败，请检查网络设置';
      } else if (e.toString().contains('FormatException')) {
        errorMessage = '数据格式错误，请重试';
      }
      
      state = AuthState.error(errorMessage);
      return false;
    }
  }

  // 发送验证码
  Future<bool> sendVerificationCode(String email) async {
    try {
      final request = VerificationCodeRequest(email: email);
      await _authRepository.sendVerificationCode(request);
      
      // 发送成功，无需更新状态
      return true;
    } catch (e) {
      String errorMessage = '发送验证码失败';
      
      // 处理DioException，提取服务器返回的具体错误信息
      if (e is DioException && e.response != null) {
        final responseData = e.response!.data;
        final statusCode = e.response!.statusCode;
        
        if (responseData is Map<String, dynamic> && responseData['message'] != null) {
          errorMessage = responseData['message'];
        } else {
          switch (statusCode) {
            case 400:
              errorMessage = '邮箱格式不正确，请检查后重试';
              break;
            case 409:
              errorMessage = '该邮箱已注册，请直接登录或使用密码重置功能';
              break;
            case 429:
              errorMessage = '发送过于频繁，请稍后再试';
              break;
            case 500:
              errorMessage = '服务器错误，请稍后重试';
              break;
            default:
              errorMessage = '发送验证码失败，请稍后重试';
          }
        }
      } else if (e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
        errorMessage = '网络连接失败，请检查网络设置';
      } else if (e.toString().contains('FormatException')) {
        errorMessage = '数据格式错误，请重试';
      }
      
      state = AuthState.error(errorMessage);
      return false;
    }
  }

  // 退出登录（仅清除本地数据）
  Future<void> logout() async {
    try {
      await _authRepository.logout();
    } catch (e) {
      print('❌ 退出登录失败: $e');
    } finally {
      state = const AuthState.unauthenticated();
    }
  }

  // 清除错误状态
  void clearError() {
    if (state.hasError) {
      state = const AuthState.unauthenticated();
    }
  }

  // 获取当前用户
  Future<void> getCurrentUser() async {
    try {
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        state = AuthState.authenticated(user);
      } else {
        state = const AuthState.unauthenticated();
      }
    } catch (e) {
      // 获取用户信息失败时，设为未认证状态
      state = const AuthState.unauthenticated();
    }
  }
}

// 认证状态提供者
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.read(authRepositoryProvider);
  return AuthNotifier(authRepository);
});

// 登录表单状态管理
class LoginFormNotifier extends StateNotifier<LoginFormState> {
  LoginFormNotifier() : super(const LoginFormState());

  // 更新邮箱
  void updateEmail(String email) {
    final isValid = _validateEmail(email);
    state = state.copyWith(
      email: email,
      isEmailValid: isValid,
      isFormValid: isValid && state.isPasswordValid,
      errorMessage: null,
    );
  }

  // 更新密码
  void updatePassword(String password) {
    final isValid = _validatePassword(password);
    state = state.copyWith(
      password: password,
      isPasswordValid: isValid,
      isFormValid: state.isEmailValid && isValid,
      errorMessage: null,
    );
  }

  // 设置加载状态
  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  // 设置错误信息
  void setError(String? error) {
    state = state.copyWith(errorMessage: error, isLoading: false);
  }

  // 清除表单
  void clearForm() {
    state = const LoginFormState();
  }

  // 验证邮箱
  bool _validateEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // 验证密码
  bool _validatePassword(String password) {
    return password.length >= 6; // 简单验证，至少6位
  }
}

// 登录表单提供者
final loginFormProvider = StateNotifierProvider<LoginFormNotifier, LoginFormState>((ref) {
  return LoginFormNotifier();
});

// 注册表单状态管理
class RegisterFormNotifier extends StateNotifier<RegisterFormState> {
  Timer? _cooldownTimer;

  RegisterFormNotifier() : super(const RegisterFormState());

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // 更新用户名
  void updateUsername(String username) {
    final isValid = _validateUsername(username);
    state = state.copyWith(
      username: username,
      isUsernameValid: isValid,
      isFormValid: _isFormValid(),
      errorMessage: null,
    );
  }

  // 更新邮箱
  void updateEmail(String email) {
    final isValid = _validateEmail(email);
    state = state.copyWith(
      email: email,
      isEmailValid: isValid,
      isFormValid: _isFormValid(),
      errorMessage: null,
    );
  }

  // 更新手机号
  void updatePhone(String phone) {
    state = state.copyWith(
      phone: phone,
      errorMessage: null,
    );
  }

  // 更新密码
  void updatePassword(String password) {
    final isValid = _validatePassword(password);
    final isMatching = password == state.confirmPassword;
    state = state.copyWith(
      password: password,
      isPasswordValid: isValid,
      isPasswordMatching: isMatching,
      isFormValid: _isFormValid(),
      errorMessage: null,
    );
  }

  // 更新确认密码
  void updateConfirmPassword(String confirmPassword) {
    final isMatching = confirmPassword == state.password;
    state = state.copyWith(
      confirmPassword: confirmPassword,
      isPasswordMatching: isMatching,
      isFormValid: _isFormValid(),
      errorMessage: null,
    );
  }

  // 更新验证码
  void updateVerificationCode(String code) {
    final isValid = code.length == 6; // 假设验证码是6位
    state = state.copyWith(
      verificationCode: code,
      isVerificationCodeValid: isValid,
      isFormValid: _isFormValid(),
      errorMessage: null,
    );
  }

  // 开始发送验证码
  void startSendingCode() {
    state = state.copyWith(
      isSendingCode: true,
      errorMessage: null,
      clearErrorMessage: true,
    );
  }

  // 设置验证码发送成功
  void setCodeSentSuccessfully([int cooldownSeconds = 60]) {
    state = state.copyWith(
      isSendingCode: false,
      isCodeSentSuccessfully: true,
      codeCooldownSeconds: cooldownSeconds,
      errorMessage: null,
      clearErrorMessage: true,
    );
    
    _startCooldownTimer(cooldownSeconds);
  }

  // 设置验证码发送失败
  void setCodeSendingFailed(String error) {
    state = state.copyWith(
      isSendingCode: false,
      isCodeSentSuccessfully: false,
      errorMessage: error,
    );
  }

  // 开始倒计时
  void _startCooldownTimer(int seconds) {
    _cooldownTimer?.cancel();
    
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final newSeconds = state.codeCooldownSeconds - 1;
      if (newSeconds <= 0) {
        timer.cancel();
        state = state.copyWith(
          isCodeSentSuccessfully: false,
          codeCooldownSeconds: 0,
        );
      } else {
        state = state.copyWith(codeCooldownSeconds: newSeconds);
      }
    });
  }

  // 设置加载状态
  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  // 设置错误信息
  void setError(String? error) {
    state = state.copyWith(errorMessage: error, isLoading: false);
  }

  // 清除表单
  void clearForm() {
    _cooldownTimer?.cancel();
    state = const RegisterFormState();
  }

  // 验证用户名
  bool _validateUsername(String username) {
    return username.length >= 3 && 
           username.length <= 20 && 
           RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username);
  }

  // 验证邮箱
  bool _validateEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // 验证密码
  bool _validatePassword(String password) {
    return password.length >= 8 && 
           RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(password);
  }

  // 检查表单是否有效
  bool _isFormValid() {
    return state.isUsernameValid &&
           state.isEmailValid &&
           state.isPasswordValid &&
           state.isVerificationCodeValid;
  }
}

// 注册表单提供者
final registerFormProvider = StateNotifierProvider<RegisterFormNotifier, RegisterFormState>((ref) {
  return RegisterFormNotifier();
});