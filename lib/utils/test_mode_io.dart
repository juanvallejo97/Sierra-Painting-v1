import 'dart:io';

bool runtimeTestEnv() => Platform.environment['FLUTTER_TEST'] == 'true';
