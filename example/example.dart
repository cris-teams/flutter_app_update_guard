import 'package:flutter_app_update_guard/flutter_app_update_guard.dart';

void main() async {
  print('=== flutter_app_update_guard example ===');

  // 1. Set up CLI configuration (using defaults)
  final config = GuardConfig.defaultConfig();

  // 2. Instantiate cached Pub API client
  final pubClient = CachedPubClient(PubApiClient());

  // 3. Instantiate check command executor
  final executor = CheckCommandExecutor(pubClient: pubClient);

  try {
    // 4. Run safety analysis on the current directory
    print('Evaluating dependency safety in current directory...');
    final report = await executor.execute(
      workingDir: '.',
      config: config,
    );

    // 5. Render report as plain text (console style)
    final textReport = const ConsoleReporter(useColor: false).render(report);
    print('\n=== Dependency Update Safety Report ===');
    print(textReport);

    // 6. Check for policy violations
    if (report.hasPolicyViolations) {
      print('[!] Alert: Update policy violations detected!');
      for (final violation in report.policyViolations) {
        print('  - $violation');
      }
    } else {
      print('[✓] Success: No policy violations found.');
    }
  } catch (e) {
    print('Error running safety analysis: $e');
  }
}
