import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/main.dart';

void main() {
  testWidgets('App should build without errors', (WidgetTester tester) async {
    // Build our app
    await tester.pumpWidget(
      const ProviderScope(
        child: SierraPaintingApp(),
      ),
    );

    // Verify that the app title is present
    expect(find.text('Sierra Painting'), findsOneWidget);

    // Verify welcome text is present
    expect(find.text('Welcome to Sierra Painting'), findsOneWidget);
  });

  testWidgets('Home screen has proper accessibility', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SierraPaintingApp(),
      ),
    );

    // Verify semantic labels are present for accessibility
    expect(find.bySemanticsLabel('Painting app icon'), findsOneWidget);
  });
}
