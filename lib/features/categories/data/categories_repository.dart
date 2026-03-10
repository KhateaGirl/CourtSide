import 'package:supabase_flutter/supabase_flutter.dart';

import 'category_model.dart';

class CategoriesRepository {
  final SupabaseClient _client;

  CategoriesRepository(this._client);

  RealtimeChannel subscribeToCategoriesChanges(void Function() onChange) {
    final channel = _client
        .channel('public:categories:all')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'categories',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'categories',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'categories',
          callback: (_) => onChange(),
        )
        .subscribe();
    return channel;
  }

  Future<List<Category>> getCategories() async {
    final res = await _client
        .from('categories')
        .select()
        .order('name');
    return (res as List)
        .map((e) => Category.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createCategory(String name) async {
    await _client.from('categories').insert({'name': name.trim()});
  }

  Future<void> updateCategory(String id, String name) async {
    await _client
        .from('categories')
        .update({'name': name.trim()})
        .eq('id', id);
  }

  Future<void> deleteCategory(String id) async {
    await _client.from('categories').delete().eq('id', id);
  }
}
