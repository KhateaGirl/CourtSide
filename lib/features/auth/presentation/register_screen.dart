import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_design_system.dart';
import '../domain/auth_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: AppSpacing.paddingMd,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null)
                  Text(
                    _error!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextField(
                  controller: _contactCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Contact number'),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: _passwordCtrl,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                AppSpacing.gapMdV,
                ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('Register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = ref.read(authRepositoryProvider);
    try {
      await repo.signUp(
        _emailCtrl.text.trim(),
        _passwordCtrl.text.trim(),
        _nameCtrl.text.trim(),
        _contactCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully. You can now sign in.'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/home');
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('already') ||
          msg.contains('duplicate') ||
          msg.contains('registered') ||
          msg.contains('unique')) {
        setState(() => _error = 'This email is already registered. Use another or sign in.');
      } else {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

