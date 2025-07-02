import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/storage_service.dart';
import '../providers/auth_provider.dart';
import '../providers/auth_state.dart';
import '../widgets/auth_input_field.dart';
import '../widgets/auth_button.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberAccount = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedData();
  }

  // 加载记住的数据
  Future<void> _loadRememberedData() async {
    final loginFormNotifier = ref.read(loginFormProvider.notifier);
    
    // 加载记住账号状态
    final rememberAccount = await StorageService.getRememberAccount();
    
    // 加载最后登录的邮箱
    final lastEmail = await StorageService.getLastLoginEmail();
    
    setState(() {
      _rememberAccount = rememberAccount;
      if (lastEmail != null && lastEmail.isNotEmpty) {
        _emailController.text = lastEmail;
        // 手动触发表单验证更新
        loginFormNotifier.updateEmail(lastEmail);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final loginFormState = ref.watch(loginFormProvider);
    final loginFormNotifier = ref.read(loginFormProvider.notifier);

    // 监听认证状态变化
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated) {
        // 完成自动填充上下文
        TextInput.finishAutofillContext();
        // 保存记住账号的设置
        _saveRememberedAccount();
        // 登录成功，直接跳转到聊天页
        context.go(AppConstants.chatRoute);
      } else if (next.hasError) {
        // 显示错误信息
        _showErrorSnackBar(next.errorMessage ?? '登录失败');
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                
                // Logo和标题
                _buildHeader(),
                
                const SizedBox(height: 60),
                
                // 邮箱输入框
                AuthInputField(
                  controller: _emailController,
                  label: '邮箱',
                  hintText: '请输入您的邮箱地址',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  prefixIcon: Icons.email_outlined,
                  autofillHints: const [AutofillHints.email],
                  onChanged: loginFormNotifier.updateEmail,
                  onEditingComplete: () {
                    // 检查自动填充后的邮箱并更新表单状态
                    if (_emailController.text.isNotEmpty) {
                      loginFormNotifier.updateEmail(_emailController.text);
                    }
                  },
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return '请输入邮箱地址';
                    }
                    if (!loginFormState.isEmailValid) {
                      return '请输入有效的邮箱地址';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // 密码输入框
                AuthInputField(
                  controller: _passwordController,
                  label: '密码',
                  hintText: '请输入您的密码',
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  obscureText: _obscurePassword,
                  prefixIcon: Icons.lock_outlined,
                  autofillHints: const [AutofillHints.password],
                  onEditingComplete: () {
                    TextInput.finishAutofillContext();
                    // 检查自动填充后的密码并更新表单状态
                    final loginFormNotifier = ref.read(loginFormProvider.notifier);
                    if (_passwordController.text.isNotEmpty) {
                      loginFormNotifier.updatePassword(_passwordController.text);
                    }
                  },
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  onChanged: loginFormNotifier.updatePassword,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return '请输入密码';
                    }
                    if (value!.length < 6) {
                      return '密码至少需要6位字符';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 8),
                
                // 记住账号和忘记密码
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 记住账号复选框
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _rememberAccount,
                          onChanged: (value) {
                            setState(() {
                              _rememberAccount = value ?? false;
                            });
                          },
                          activeColor: AppConstants.primaryColor,
                        ),
                        const Text(
                          '记住账号',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    // 忘记密码
                    TextButton(
                      onPressed: () {
                        final email = _emailController.text.trim();
                        if (email.isNotEmpty) {
                          context.push('${AppConstants.forgotPasswordRoute}?email=${Uri.encodeComponent(email)}');
                        } else {
                          context.push(AppConstants.forgotPasswordRoute);
                        }
                      },
                      child: Text(
                        '忘记密码？',
                        style: TextStyle(
                          color: AppConstants.primaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // 登录按钮
                AuthButton(
                  text: '登录',
                  isLoading: authState.isLoading,
                  isEnabled: loginFormState.isFormValid,
                  onPressed: _handleLogin,
                ),
                
                const SizedBox(height: 24),
                
                // 错误信息显示
                if (loginFormState.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, 
                            color: Colors.red.shade600, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            loginFormState.errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // 注册提示
                _buildRegisterPrompt(),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Logo
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppConstants.primaryColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.chat_bubble_outline,
            color: Colors.white,
            size: 40,
          ),
        ),
        
        const SizedBox(height: 24),
        
        // 标题
        Text(
          '欢迎回来',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // 副标题
        Text(
          '登录您的账户继续学习英语',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '还没有账户？ ',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        TextButton(
          onPressed: () {
            context.push(AppConstants.registerRoute);
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            '立即注册',
            style: TextStyle(
              color: AppConstants.primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authNotifier = ref.read(authProvider.notifier);
    final success = await authNotifier.login(
      _emailController.text,
      _passwordController.text,
    );

    if (!success) {
      // 错误处理已在状态监听中处理
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  Future<void> _saveRememberedAccount() async {
    // 保存记住账号的设置
    await StorageService.saveRememberAccount(_rememberAccount);
    
    if (_rememberAccount && _emailController.text.isNotEmpty) {
      // 保存最后登录的邮箱
      await StorageService.saveLastLoginEmail(_emailController.text);
      // 添加到记住的账号列表
      await StorageService.addRememberedAccount(_emailController.text);
    } else if (!_rememberAccount) {
      // 如果取消记住账号，清除保存的邮箱
      await StorageService.saveLastLoginEmail('');
    }
  }
}