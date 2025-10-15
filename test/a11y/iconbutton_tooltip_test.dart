/// IconButton Tooltip Coverage Test
///
/// PURPOSE:
/// Ensure all IconButtons have tooltips for accessibility.
///
/// ACCEPTANCE CRITERIA:
/// - All IconButtons must have a tooltip parameter
/// - Tooltips should be descriptive and actionable
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('IconButton Tooltip Coverage', () {
    test('All IconButtons should have tooltips', () async {
      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => !file.path.contains('generated'))
          .where((file) => !file.path.contains('.g.dart'));

      final violations = <String>[];

      for (final file in dartFiles) {
        final content = await file.readAsString();
        final lines = content.split('\n');

        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];

          // Check for IconButton declarations
          if (line.contains('IconButton(')) {
            // Look ahead up to 10 lines for tooltip parameter
            var hasTooltip = false;
            var bracketCount = 0;
            var foundOpeningBracket = false;

            for (var j = i; j < i + 15 && j < lines.length; j++) {
              final checkLine = lines[j];

              // Count brackets to know when IconButton ends
              bracketCount += '('.allMatches(checkLine).length;
              bracketCount -= ')'.allMatches(checkLine).length;

              if (checkLine.contains('IconButton(')) {
                foundOpeningBracket = true;
              }

              if (checkLine.contains('tooltip:')) {
                hasTooltip = true;
                break;
              }

              // If we've closed all brackets, IconButton is complete
              if (foundOpeningBracket && bracketCount == 0) {
                break;
              }
            }

            if (!hasTooltip) {
              violations.add('${file.path}:${i + 1}');
            }
          }
        }
      }

      if (violations.isNotEmpty) {
        print('\nIconButtons without tooltips found:');
        for (final violation in violations) {
          print('  - $violation');
        }
        print('\nTotal violations: ${violations.length}');
      }

      expect(
        violations,
        isEmpty,
        reason:
            'All IconButtons must have tooltips for accessibility. Found ${violations.length} violations.',
      );
    });
  });
}
