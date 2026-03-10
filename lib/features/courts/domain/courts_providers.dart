import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/courts_repository.dart';
import '../data/court_model.dart';

final courtsRepositoryProvider = Provider<CourtsRepository>((ref) {
  return CourtsRepository(Supabase.instance.client);
});

final courtsListProvider = FutureProvider<List<Court>>((ref) async {
  final repo = ref.read(courtsRepositoryProvider);
  return repo.getCourts();
});

