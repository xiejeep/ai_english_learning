import 'package:ai_english_learning/features/auth/presentation/pages/profile_page.dart';
import 'package:ai_english_learning/features/auth/presentation/pages/token_history_page.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/chat/presentation/pages/chat_page.dart';
import '../constants/app_constants.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppConstants.chatRoute,
    routes: [
      GoRoute(
        path: AppConstants.chatRoute,
        builder: (context, state) => const ChatPage(),
      ),
      GoRoute(
        path: AppConstants.loginRoute,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppConstants.registerRoute,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppConstants.forgotPasswordRoute,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
          path: AppConstants.profileRoute,
          builder: (context, state) => const ProfilePage(),
        ),
      GoRoute(
        path: AppConstants.creditsHistoryRoute,
        builder: (context, state) => const TokenHistoryPage(),
      ),
    ],
  );
}