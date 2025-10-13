// lib/core/debug/provider_logger.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final class ProviderLogger extends ProviderObserver {
  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    debugPrint(
      '🟢 add ${context.provider.name ?? context.provider.runtimeType}',
    );
  }

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    debugPrint(
      '🔁 update ${context.provider.name ?? context.provider.runtimeType} -> ${newValue.runtimeType}',
    );
  }

  @override
  void didDisposeProvider(ProviderObserverContext context) {
    debugPrint(
      '⚫ dispose ${context.provider.name ?? context.provider.runtimeType}',
    );
  }
}
