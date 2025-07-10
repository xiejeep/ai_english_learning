import 'package:ai_english_learning/features/auth/presentation/pages/profile_page.dart';
import 'package:ai_english_learning/features/auth/presentation/pages/token_history_page.dart';
import 'package:ai_english_learning/features/auth/presentation/pages/credits_history_page.dart';
import 'package:ai_english_learning/features/auth/presentation/pages/settings_page.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/chat/presentation/pages/chat_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../constants/app_constants.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppConstants.homeRoute,
    routes: [
      GoRoute(
        path: AppConstants.homeRoute,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: AppConstants.chatRoute,
        builder: (context, state) {
          final type = state.uri.queryParameters['type'];
          final appId = state.uri.queryParameters['appId'];
          final appName = state.uri.queryParameters['appName'];
          return ChatPage(type: type, appId: appId, appName: appName);
        },
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
        builder: (context, state) => const CreditsHistoryPage(),
      ),
      GoRoute(
        path: AppConstants.tokenUsageRoute,
        builder: (context, state) => const TokenHistoryPage(),
      ),
      GoRoute(
        path: AppConstants.settingsRoute,
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
}