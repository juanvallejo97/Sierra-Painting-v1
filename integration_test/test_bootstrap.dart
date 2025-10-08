// Shared bootstrap for all integration tests.
import 'package:integration_test/integration_test.dart';

void bootstrapIntegration() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Reduce flakiness from first frame vs. test start.
  binding.deferFirstFrame();
  binding.allowFirstFrame();
}
