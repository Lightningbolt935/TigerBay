import 'package:flutter_test/flutter_test.dart';
import 'package:tigerbay_app/core/config/env_config.dart';

void main() {
  test('App smoke test - EnvConfig initialization', () async {
    await EnvConfig.initialize();
    expect(EnvConfig.supabaseUrl, isNotEmpty);
  });
}
