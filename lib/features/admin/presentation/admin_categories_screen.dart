import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../categories/data/category_model.dart';
import '../../categories/domain/categories_providers.dart';

class AdminCategoriesScreen extends ConsumerStatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  ConsumerState<AdminCategoriesScreen> createState() =>
      _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends ConsumerState<AdminCategoriesScreen> {
  RealtimeChannel? _channel;

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_channel == null) {
      final repo = ref.read(categoriesRepositoryProvider);
      _channel = repo.subscribeToCategoriesChanges(() {
        ref.invalidate(categoriesListProvider);
      });
    }

    final categoriesAsync = ref.watch(categoriesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showEditDialog(),
          ),
        ],
      ),
      body: categoriesAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.category_outlined,
              title: 'No categories yet',
              subtitle: 'Tap + to add your first category (e.g. Basketball, Volleyball).',
            );
          }
          return ListView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.isNarrow(context)
                  ? AppSpacing.sm
                  : AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final c = list[index];
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.blue100,
                    child: Text(
                      c.name.isNotEmpty ? c.name[0] : '?',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.blue700,
                      ),
                    ),
                  ),
                  title: Text(
                    c.name,
                    style: AppTypography.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        color: AppColors.blue600,
                        onPressed: () => _showEditDialog(category: c),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        color: AppColors.rejected,
                        onPressed: () => _confirmDeleteCategory(c),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _showEditDialog({Category? category}) async {
    final nameCtrl = TextEditingController(text: category?.name ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category == null ? 'Add category' : 'Edit category'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'e.g. Basketball, Volleyball',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final confirmed = await ConfirmDialog.show(
                context,
                title: category == null ? 'Add this category?' : 'Save changes?',
                message: category == null
                    ? 'This category will appear in the reservation form.'
                    : 'Category name will be updated.',
                confirmLabel: 'Yes, save',
                cancelLabel: 'Cancel',
                icon: category == null
                    ? Icons.add_circle_outline
                    : Icons.save_outlined,
              );
              if (!confirmed || !context.mounted) return;
              final repo = ref.read(categoriesRepositoryProvider);
              if (category == null) {
                await repo.createCategory(name);
              } else {
                await repo.updateCategory(category.id, name);
              }
              if (context.mounted) Navigator.pop(context);
              ref.invalidate(categoriesListProvider);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteCategory(Category category) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'Delete this category?',
      message:
          '${category.name} will be removed. Reservations using it may show no category.',
      confirmLabel: 'Yes, delete',
      cancelLabel: 'Cancel',
      isDanger: true,
      icon: Icons.delete_forever_rounded,
    );
    if (!ok || !mounted) return;
    final repo = ref.read(categoriesRepositoryProvider);
    await repo.deleteCategory(category.id);
    ref.invalidate(categoriesListProvider);
  }
}
