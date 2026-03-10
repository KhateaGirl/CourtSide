import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/courts/presentation/courts_list_screen.dart';
import '../../features/reservations/presentation/player_reservations_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/admin_pending_reservations_screen.dart';
import '../../features/admin/presentation/admin_users_screen.dart';
import '../../features/admin/presentation/admin_courts_screen.dart';
import '../../features/admin/presentation/admin_schedule_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final supabase = Supabase.instance.client;

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final session = supabase.auth.currentSession;
      final loggingIn =
          state.matchedLocation == '/login' || state.matchedLocation == '/register';
      if (session == null && !loggingIn) {
        return '/login';
      }
      if (session != null && loggingIn) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const PlayerReservationsScreen(),
      ),
      GoRoute(
        path: '/courts',
        builder: (context, state) => const CourtsListScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/pending',
        builder: (context, state) => const AdminPendingReservationsScreen(),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const AdminUsersScreen(),
      ),
      GoRoute(
        path: '/admin/courts',
        builder: (context, state) => const AdminCourtsScreen(),
      ),
      GoRoute(
        path: '/admin/schedule',
        builder: (context, state) => const AdminScheduleScreen(),
      ),
    ],
  );
});

