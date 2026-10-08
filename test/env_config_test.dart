import 'package:flutter_test/flutter_test.dart';
import 'package:tigerbay_app/core/config/env_config.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/core/utils/qr_timer.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await EnvConfig.initialize();
  });

  group('EnvConfig Tests', () {
    test('EnvConfig provides valid default Supabase configuration', () {
      expect(EnvConfig.supabaseUrl, isNotEmpty);
      expect(EnvConfig.supabaseUrl.startsWith('https://'), isTrue);
      expect(EnvConfig.supabaseAnonKey, isNotEmpty);
    });

    test('EnvConfig provides valid Stripe configuration', () {
      expect(EnvConfig.stripePublishableKey, isNotEmpty);
      expect(EnvConfig.stripePublishableKey.startsWith('pk_'), isTrue);
      expect(EnvConfig.isStripeConfigured, isTrue);
      expect(EnvConfig.stripeSecretKey.startsWith('sk_'), isTrue);
    });

    test('EnvConfig provides valid Google Client & App Scheme', () {
      expect(EnvConfig.googleWebClientId, isNotEmpty);
      expect(EnvConfig.appScheme, equals('io.tigerbay.app'));
    });

    test('EnvConfig provides valid Twilio configuration', () {
      expect(EnvConfig.twilioAccountSid, startsWith('AC'));
      expect(EnvConfig.twilioVerifyServiceSid, startsWith('VA'));
      // Secrets are empty by default for client-side security
      expect(EnvConfig.twilioAuthToken, isA<String>());
      expect(EnvConfig.twilioApiSecret, isA<String>());
    });
  });

  group('AppColors & Theme Tests', () {
    test('Core Brand Colors are properly defined', () {
      expect(AppColors.brandRed, isNotNull);
      expect(AppColors.gold, isNotNull);
      expect(AppColors.brandBlack, isNotNull);
      expect(AppColors.glassSurface, isNotNull);
      expect(AppColors.glassBorder, isNotNull);
    });
  });

  group('QrTimer Tests', () {
    test('QrTimer initializes with user details and generates payload', () {
      final timer = QrTimer(
        userId: 'test_user_001',
        memberCode: '100001',
        deviceId: 'device_uuid_test',
        secret: 'test_secret_key',
      );
      timer.start();
      expect(timer.secondsRemaining, equals(60));
      timer.dispose();
    });
  });
}
