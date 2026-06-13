import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/providers/auth_provider.dart';
import 'package:mobile/core/widgets/main_shell.dart';
import 'package:mobile/features/auth/view/forgot_password_screen.dart';
import 'package:mobile/features/auth/view/login_screen.dart';
import 'package:mobile/features/auth/view/signup_screen.dart';
import 'package:mobile/features/booking/view/contracts_screen.dart';
import 'package:mobile/features/home/view/home_screen.dart';
import 'package:mobile/features/profile/view/profile_screen.dart';
import 'package:mobile/features/room/view/room_list_screen.dart';

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<bool>>(authProvider, (prev, next) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authProvider);
    if (authState.isLoading) return null;

    final isLoggedIn = authState.asData?.value ?? false;
    final location = state.matchedLocation;

    final isAuthPage = location == '/login' ||
        location == '/signup' ||
        location == '/forgot-password';

    if (!isLoggedIn && !isAuthPage) return '/login';
    if (isLoggedIn && isAuthPage) return '/home';
    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    debugLogDiagnostics: false,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, _) => const SignupScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => const HomeScreen(),
          ),
          GoRoute(
            path: '/rooms',
            builder: (_, _) => const RoomListScreen(),
          ),
          GoRoute(
            path: '/bookings',
            builder: (_, _) => const ContractsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, _) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});
