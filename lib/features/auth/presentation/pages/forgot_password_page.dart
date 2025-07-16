import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/forgot_password_provider.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  final String? initialEmail;
  
  const ForgotPasswordPage({super.key, this.initialEmail});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    // 如果有传入的邮箱，则初始化邮箱输入框
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
      // 延迟更新provider状态，确保widget已经构建完成
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(forgotPasswordProvider.notifier).updateEmail(widget.initialEmail!);
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final forgotPasswordState = ref.watch(forgotPasswordProvider);
    final forgotPasswordNotifier = ref.read(forgotPasswordProvider.notifier);

    // 监听错误信息
    ref.listen<ForgotPasswordState>(forgotPasswordProvider, (previous, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          '忘记密码',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                
                // 标题和描述
                const Text(
                  '重置密码',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  '请输入您的邮箱地址，我们将发送验证码到您的邮箱',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // 邮箱输入框
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: '邮箱地址',
                    hintText: '请输入您的邮箱地址',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).primaryColor),
                    ),
                  ),
                  onChanged: forgotPasswordNotifier.updateEmail,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入邮箱地址';
                    }
                    if (!forgotPasswordState.isEmailValid) {
                      return '请输入有效的邮箱地址';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // 发送验证码按钮
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: forgotPasswordState.isEmailValid && 
                               forgotPasswordState.countdown == 0 && 
                               !forgotPasswordState.isLoading
                        ? () async {
                            await forgotPasswordNotifier.sendResetCode();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: forgotPasswordState.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            forgotPasswordState.countdown > 0
                                ? '重新发送 (${forgotPasswordState.countdown}s)'
                                : forgotPasswordState.isCodeSent
                                    ? '重新发送验证码'
                                    : '发送验证码',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                // 如果验证码已发送，显示后续表单
                if (forgotPasswordState.isCodeSent) ..._buildResetForm(forgotPasswordState, forgotPasswordNotifier),

                const Spacer(),

                // 返回登录
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '想起密码了？',
                      style: TextStyle(color: Colors.grey),
                    ),
                    TextButton(
                      onPressed: () => context.pop(),
                      child:  Text(
                        '返回登录',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildResetForm(ForgotPasswordState state, ForgotPasswordNotifier notifier) {
    return [
      const SizedBox(height: 32),
      
      // 验证码输入框
      TextFormField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        maxLength: 6,
        decoration: InputDecoration(
          labelText: '验证码',
          hintText: '请输入6位验证码',
          prefixIcon: const Icon(Icons.security),
          counterText: '',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).primaryColor),
          ),
        ),
        onChanged: notifier.updateVerificationCode,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return '请输入验证码';
          }
          if (!state.isCodeValid) {
            return '请输入6位数字验证码';
          }
          return null;
        },
      ),
      const SizedBox(height: 20),

      // 新密码输入框
      TextFormField(
        controller: _newPasswordController,
        obscureText: !_isNewPasswordVisible,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: '新密码',
          hintText: '请输入新密码（至少6位）',
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(
              _isNewPasswordVisible ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () {
              setState(() {
                _isNewPasswordVisible = !_isNewPasswordVisible;
              });
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).primaryColor),
          ),
        ),
        onChanged: notifier.updateNewPassword,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return '请输入新密码';
          }
          if (!state.isPasswordValid) {
            return '密码至少需要6位字符';
          }
          return null;
        },
      ),
      const SizedBox(height: 20),

      // 确认密码输入框
      TextFormField(
        controller: _confirmPasswordController,
        obscureText: !_isConfirmPasswordVisible,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: '确认新密码',
          hintText: '请再次输入新密码',
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(
              _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () {
              setState(() {
                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
              });
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).primaryColor),
          ),
        ),
        onChanged: notifier.updateConfirmPassword,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return '请确认新密码';
          }
          if (!state.isConfirmPasswordValid) {
            return '两次输入的密码不一致';
          }
          return null;
        },
      ),
      const SizedBox(height: 32),

      // 重置密码按钮
      SizedBox(
        height: 50,
        child: ElevatedButton(
          onPressed: state.isFormValid && !state.isLoading
              ? () async {
                  if (_formKey.currentState!.validate()) {
                    final success = await notifier.resetPassword();
                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('密码重置成功，请使用新密码登录'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      context.pop();
                    }
                  }
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: state.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  '重置密码',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    ];
  }
}