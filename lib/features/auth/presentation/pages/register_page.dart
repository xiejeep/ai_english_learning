import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/models/auth_request_model.dart';
import '../providers/auth_provider.dart';
import '../providers/auth_state.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_input_field.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _codeController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final registerFormState = ref.watch(registerFormProvider);
    final registerFormNotifier = ref.read(registerFormProvider.notifier);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated) {
        context.go(AppConstants.homeRoute);
      } else if (next.hasError) {
        _showErrorSnackBar(next.errorMessage ?? '注册失败');
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('创建账户'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.grey.shade800,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                
                AuthInputField(
                  controller: _usernameController,
                  label: '用户名',
                  hintText: '3-20位，字母、数字或下划线',
                  prefixIcon: Icons.person_outline,
                  onChanged: registerFormNotifier.updateUsername,
                  validator: (value) {
                    if (value == null || value.isEmpty) return '请输入用户名';
                    if (!registerFormState.isUsernameValid) return '用户名格式不正确';
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                AuthInputField(
                  controller: _emailController,
                  label: '邮箱',
                  hintText: '请输入您的邮箱地址',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  onChanged: registerFormNotifier.updateEmail,
                  validator: (value) {
                    if (value == null || value.isEmpty) return '请输入邮箱';
                    if (!registerFormState.isEmailValid) return '邮箱格式不正确';
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                _buildVerificationCodeField(),
                
                const SizedBox(height: 16),
                
                AuthInputField(
                  controller: _passwordController,
                  label: '密码',
                  hintText: '至少8位，包含字母和数字',
                  obscureText: _obscurePassword,
                  prefixIcon: Icons.lock_outline,
                  onChanged: registerFormNotifier.updatePassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return '请输入密码';
                    if (!registerFormState.isPasswordValid) return '密码格式不正确';
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                AuthInputField(
                  controller: _confirmPasswordController,
                  label: '确认密码',
                  hintText: '请再次输入您的密码',
                  obscureText: _obscureConfirmPassword,
                  prefixIcon: Icons.lock_person_outlined,
                  onChanged: (value) {
                    // 仅用于UI验证，实际状态在notifier中处理
                    setState(() {});
                  },
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return '请确认密码';
                    if (_passwordController.text != value) return '两次输入的密码不一致';
                    return null;
                  },
                ),
                
                const SizedBox(height: 32),
                
                AuthButton(
                  text: '注册',
                  isLoading: authState.isLoading,
                  onPressed: _handleRegister,
                ),
                
                const SizedBox(height: 24),
                
                _buildLoginPrompt(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Text(
      '加入我们，开始您的AI英语学习之旅！',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 18,
        color: Colors.grey.shade700,
      ),
    );
  }

  Widget _buildVerificationCodeField() {
    final registerFormState = ref.watch(registerFormProvider);
    final registerFormNotifier = ref.read(registerFormProvider.notifier);
    
    final bool canSendCode = registerFormState.isEmailValid && 
                             !registerFormState.isSendingCode && 
                             !registerFormState.isCodeSentSuccessfully;

    String buttonText = '发送验证码';
    if (registerFormState.isSendingCode) {
      buttonText = '发送中...';
    } else if (registerFormState.isCodeSentSuccessfully) {
      buttonText = '${registerFormState.codeCooldownSeconds}秒后重发';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AuthInputField(
            controller: _codeController,
            label: '验证码',
            hintText: '6位数字',
            keyboardType: TextInputType.number,
            prefixIcon: Icons.pin_outlined,
            onChanged: registerFormNotifier.updateVerificationCode,
            validator: (value) {
              if (value == null || value.isEmpty) return '请输入验证码';
              if (!registerFormState.isVerificationCodeValid) return '验证码格式不正确';
              return null;
            },
          ),
        ),
        const SizedBox(width: 16),
        Container(
          height: 56,
          margin: const EdgeInsets.only(top: 28),
          child: OutlinedButton(
            onPressed: canSendCode ? _handleSendCode : null,
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: canSendCode ? Theme.of(context).primaryColor : Colors.grey.shade400,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              buttonText,
              style: TextStyle(
                color: canSendCode ? Theme.of(context).primaryColor : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('已有账户？', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        AuthTextButton(
          text: '立即登录',
          onPressed: () => context.go(AppConstants.loginRoute),
        ),
      ],
    );
  }

  Future<void> _handleSendCode() async {
    if (_emailController.text.isEmpty) {
      _showErrorSnackBar('请输入邮箱地址');
      return;
    }

    final registerFormNotifier = ref.read(registerFormProvider.notifier);
    registerFormNotifier.startSendingCode();
    
    final success = await ref.read(authProvider.notifier).sendVerificationCode(_emailController.text);
    
    if (success) {
      registerFormNotifier.setCodeSentSuccessfully();
      _showSuccessSnackBar('验证码已发送，请注意查收');
    } else {
      // Error message is handled by the AuthNotifier, but we need to update form state
      final authState = ref.read(authProvider);
      final errorMessage = authState.errorMessage ?? '发送验证码失败';
      registerFormNotifier.setCodeSendingFailed(errorMessage);
      
      // 如果是邮箱已注册的错误，显示特殊的错误处理
      if (errorMessage.contains('该邮箱已注册')) {
        _showEmailAlreadyRegisteredDialog();
      } else {
        _showErrorSnackBar(errorMessage);
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    final request = RegisterRequest(
      username: _usernameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      code: _codeController.text,
    );
    
    await ref.read(authProvider.notifier).register(request);
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showEmailAlreadyRegisteredDialog() {
    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('邮箱已注册'),
            content: Text('邮箱 ${_emailController.text} 已经注册过了。\n\n您可以直接登录，或者如果忘记密码可以重置密码。'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('取消'),
              ),
              TextButton(
                 onPressed: () {
                   Navigator.of(context).pop();
                   final email = _emailController.text.trim();
                   if (email.isNotEmpty) {
                     context.go('${AppConstants.forgotPasswordRoute}?email=${Uri.encodeComponent(email)}');
                   } else {
                     context.go(AppConstants.forgotPasswordRoute);
                   }
                 },
                 child: const Text('忘记密码'),
               ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go(AppConstants.loginRoute);
                },
                child: const Text('去登录'),
              ),
            ],
          );
        },
      );
    }
  }
}