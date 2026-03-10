import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  Future<AuthResponse> signIn(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp(
    String email,
    String password,
    String name,
    String contactNumber,
  ) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'contact_number': contactNumber},
    );

    final userId = res.user?.id;
    if (userId != null) {
      await _client.from('users').insert({
        'id': userId,
        'name': name,
        'email': email,
        'contact_number': contactNumber,
        'role': 'player',
      });
    }
    return res;
  }

  Future<void> signOut() => _client.auth.signOut();
}

