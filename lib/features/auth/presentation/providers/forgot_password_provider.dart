import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../data/models/auth_request_model.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_provider.dart';

// 忘记密码状态
class ForgotPasswordState {
  final String email;
  final String verificationCode;
  final String newPassword;
  final String confirmPassword;
  final bool isEmailValid;
  final bool isCodeValid;
  final bool isPasswordValid;
  final bool isConfirmPasswordValid;
  final bool isFormValid;
  final bool isLoading;
  final String? errorMessage;
  final bool isCodeSent;
  final int countdown;

  const ForgotPasswordState({
    this.email = '',
    this.verificationCode = '',
    this.newPassword = '',
    this.confirmPassword = '',
    this.isEmailValid = false,
    this.isCodeValid = false,
    this.isPasswordValid = false,
    this.isConfirmPasswordValid = false,
    this.isFormValid = false,
    this.isLoading = false,
    this.errorMessage,
    this.isCodeSent = false,
    this.countdown = 0,
  });

  ForgotPasswordState copyWith({
    String? email,
    String? verificationCode,
    String? newPassword,
    String? confirmPassword,
    bool? isEmailValid,
    bool? isCodeValid,
    bool? isPasswordValid,
    bool? isConfirmPasswordValid,
    bool? isFormValid,
    bool? isLoading,
    String? errorMessage,
    bool? isCodeSent,
    int? countdown,
  }) {
    return ForgotPasswordState(
      email: email ?? this.email,
      verificationCode: verificationCode ?? this.verificationCode,
      newPassword: newPassword ?? this.newPassword,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      isEmailValid: isEmailValid ?? this.isEmailValid,
      isCodeValid: isCodeValid ?? this.isCodeValid,
      isPasswordValid: isPasswordValid ?? this.isPasswordValid,
      isConfirmPasswordValid: isConfirmPasswordValid ?? this.isConfirmPasswordValid,
      isFormValid: isFormValid ?? this.isFormValid,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isCodeSent: isCodeSent ?? this.isCodeSent,
      countdown: countdown ?? this.countdown,
    );
  }
}

// 忘记密码状态管理
class ForgotPasswordNotifier extends StateNotifier<ForgotPasswordState> {
  final AuthRepository _authRepository;

  ForgotPasswordNotifier(this._authRepository) : super(const ForgotPasswordState());

  // 邮箱验证规则
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // 密码验证规则
  bool _isValidPassword(String password) {
    return password.length >= 6;
  }

  // 验证码验证规则
  bool _isValidCode(String code) {
    return code.length == 6 && RegExp(r'^[0-9]{6}$').hasMatch(code);
  }

  // 更新表单验证状态
  void _updateFormValidation() {
    final isFormValid = state.isEmailValid &&
        state.isCodeValid &&
        state.isPasswordValid &&
        state.isConfirmPasswordValid;

    state = state.copyWith(isFormValid: isFormValid);
  }

  // 更新邮箱
  void updateEmail(String email) {
    final isValid = _isValidEmail(email);
    state = state.copyWith(
      email: email,
      isEmailValid: isValid,
      errorMessage: null,
    );
    _updateFormValidation();
  }

  // 更新验证码
  void updateVerificationCode(String code) {
    final isValid = _isValidCode(code);
    state = state.copyWith(
      verificationCode: code,
      isCodeValid: isValid,
      errorMessage: null,
    );
    _updateFormValidation();
  }

  // 更新新密码
  void updateNewPassword(String password) {
    final isValid = _isValidPassword(password);
    final isConfirmValid = password == state.confirmPassword;
    state = state.copyWith(
      newPassword: password,
      isPasswordValid: isValid,
      isConfirmPasswordValid: isConfirmValid,
      errorMessage: null,
    );
    _updateFormValidation();
  }

  // 更新确认密码
  void updateConfirmPassword(String password) {
    final isValid = password == state.newPassword && _isValidPassword(password);
    state = state.copyWith(
      confirmPassword: password,
      isConfirmPasswordValid: isValid,
      errorMessage: null,
    );
    _updateFormValidation();
  }

  // 发送重置验证码
  Future<void> sendResetCode() async {
    if (!state.isEmailValid) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final request = VerificationCodeRequest(email: state.email);
      await _authRepository.sendResetCode(request);
      
      state = state.copyWith(
        isLoading: false,
        isCodeSent: true,
        countdown: 60,
      );
      
      // 开始倒计时
      _startCountdown();
    } catch (e) {
      String errorMessage = '发送重置验证码失败';
      
      // 处理DioException，提取服务器返回的具体错误信息
      if (e is DioException && e.response != null) {
        final responseData = e.response!.data;
        if (responseData is Map<String, dynamic> && responseData['message'] != null) {
          errorMessage = responseData['message'];
        } else if (e.response!.statusCode == 400) {
          errorMessage = '该邮箱未注册，请先注册账号';
        }
      } else {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
      
      state = state.copyWith(
        isLoading: false,
        errorMessage: errorMessage,
      );
    }
  }

  // 重置密码
  Future<bool> resetPassword() async {
    if (!state.isFormValid) return false;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final request = ResetPasswordRequest(
        email: state.email,
        newPassword: state.newPassword,
        confirmPassword: state.confirmPassword,
        verificationCode: state.verificationCode,
      );
      
      await _authRepository.resetPassword(request);
      
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  // 开始倒计时
  void _startCountdown() {
    if (state.countdown > 0) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && state.countdown > 0) {
          state = state.copyWith(countdown: state.countdown - 1);
          _startCountdown();
        }
      });
    }
  }

  // 清除错误信息
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  // 重置状态
  void reset() {
    state = const ForgotPasswordState();
  }
}

// Provider
final forgotPasswordProvider = StateNotifierProvider<ForgotPasswordNotifier, ForgotPasswordState>((ref) {
  final authRepository = ref.read(authRepositoryProvider);
  return ForgotPasswordNotifier(authRepository);
});