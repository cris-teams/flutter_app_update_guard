import 'dart:io';
import 'package:flutter_app_update_guard/src/cli/app_runner.dart';

Future<void> main(List<String> arguments) async {
  final runner = AppRunner(arguments);
  final exitCode = await runner.run();
  exit(exitCode);
}
