import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'error_view.dart';
import 'loading_view.dart';

/// Renders AsyncValue with consistent loading, error, and empty states.
/// Keeps UI separate from state; use for list/data screens per ui_prompts.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.error,
    this.empty,
    this.isEmpty,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget Function()? loading;
  final Widget Function(Object err, StackTrace? st)? error;
  final Widget Function()? empty;
  final bool Function(T data)? isEmpty;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (d) {
        if (isEmpty != null && isEmpty!(d)) {
          return empty != null ? empty!() : const SizedBox.shrink();
        }
        return data(d);
      },
      loading: () => loading?.call() ?? const LoadingView(),
      error: (e, st) =>
          error?.call(e, st) ?? ErrorView(message: e.toString()),
    );
  }
}
