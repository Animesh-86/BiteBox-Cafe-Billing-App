import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/logic/auth/trust_provider.dart';

/// A widget that only shows its child if the current device is trusted.
/// Otherwise, it shows [fallback] or nothing.
class TrustedDeviceGate extends ConsumerWidget {
  final Widget child;
  final Widget? fallback;
  final bool hideCompletely;

  const TrustedDeviceGate({
    super.key,
    required this.child,
    this.fallback,
    this.hideCompletely = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trustworthiness = ref.watch(isDeviceTrustedProvider);

    return trustworthiness.when(
      data: (isTrusted) {
        if (isTrusted) return child;
        if (fallback != null) return fallback!;
        return hideCompletely
            ? const SizedBox.shrink()
            : const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(), // Wait until trust is known
      error: (_, __) => hideCompletely
          ? const SizedBox.shrink()
          : const SizedBox.shrink(), // Fail safe
    );
  }
}
