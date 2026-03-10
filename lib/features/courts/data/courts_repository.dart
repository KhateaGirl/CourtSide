import 'package:supabase_flutter/supabase_flutter.dart';

import 'court_model.dart';

class CourtsRepository {
  final SupabaseClient _client;

  CourtsRepository(this._client);

  Future<List<Court>> getCourts() async {
    final res = await _client.from('courts').select().order('name');
    return (res as List)
        .map((e) => Court.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createCourt(
    String name,
    String sportType,
    String description,
  ) async {
    await _client.from('courts').insert({
      'name': name,
      'sport_type': sportType,
      'description': description,
    });
  }

  Future<void> updateCourt(
    String id,
    String name,
    String sportType,
    String description,
  ) async {
    await _client
        .from('courts')
        .update({
          'name': name,
          'sport_type': sportType,
          'description': description,
        })
        .eq('id', id);
  }

  Future<void> deleteCourt(String id) async {
    await _client.from('courts').delete().eq('id', id);
  }
}

