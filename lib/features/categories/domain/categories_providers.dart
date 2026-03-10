import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/categories_repository.dart';
import '../data/category_model.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepository(Supabase.instance.client);
});

final categoriesListProvider =
    FutureProvider.autoDispose<List<Category>>((ref) async {
  final repo = ref.read(categoriesRepositoryProvider);
  return repo.getCategories();
});
