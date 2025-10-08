import 'package:flutter/material.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override Widget build(BuildContext context) =>
    const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
}

class EmptyView extends StatelessWidget {
  final String message;
  const EmptyView(this.message, {super.key});
  @override Widget build(BuildContext context) =>
    Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(message)));
}

class ErrorView extends StatelessWidget {
  final String message; final VoidCallback? onRetry;
  const ErrorView(this.message, {super.key, this.onRetry});
  @override Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        if (onRetry != null) ElevatedButton(onPressed: onRetry, child: const Text('Retry'))
      ]),
    ),
  );
}
