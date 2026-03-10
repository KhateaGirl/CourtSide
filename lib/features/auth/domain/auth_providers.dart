import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

enum AuthState { signedIn, signedOut }

final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = Supabase.instance.client;
  return client.auth.onAuthStateChange.map(
    (event) =>
        event.session != null ? AuthState.signedIn : AuthState.signedOut,
  );
});

/// Current user's profile from `users` table (includes role). Use to show Admin UI.
final currentUserProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return null;
  final res = await client.from('users').select().eq('id', uid).maybeSingle();
  return res;
});

