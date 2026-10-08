import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Headers;
import '../core/config/env_config.dart';
import '../core/utils/error_sanitizer.dart';

/// Service for managing SMS notifications, booking alerts, and OTP verification
/// using Twilio REST and Twilio Verify APIs.
class TwilioNotificationService {
  final SupabaseClient? _supabase;
  final Dio _dio;

  TwilioNotificationService({SupabaseClient? supabase, Dio? dio})
      : _supabase = supabase ?? (Supabase.instance.client),
        _dio = dio ?? Dio();

  /// Tests connectivity and status of the Twilio credentials.
  Future<Map<String, dynamic>> testConnection() async {
    final accountSid = EnvConfig.twilioAccountSid;
    final authToken = EnvConfig.twilioAuthToken;

    final basicAuth = base64Encode(utf8.encode('$accountSid:$authToken'));
    final url = 'https://api.twilio.com/2010-04-01/Accounts/$accountSid.json';

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        options: Options(
          headers: {'Authorization': 'Basic $basicAuth'},
        ),
      );

      final data = response.data ?? {};
      return {
        'success': true,
        'account_sid': data['sid'],
        'status': data['status'],
        'type': data['type'],
        'friendly_name': data['friendly_name'],
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      final errorMsg = data is Map ? data['message'] : e.message;
      return {
        'success': false,
        'error': errorMsg ?? 'Failed to connect to Twilio',
        'code': data is Map ? data['code'] : null,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Sends a booking confirmation SMS notification.
  Future<Map<String, dynamic>> sendBookingConfirmation({
    required String recipientPhone,
    required String venueName,
    required String bookingDate,
    required String timeSlot,
    int? partySize,
  }) async {
    final message =
        'TigerBay: Your reservation at $venueName is confirmed for $bookingDate at $timeSlot. We look forward to welcoming you!';

    return sendSms(to: recipientPhone, message: message);
  }

  /// Sends a generic SMS message via the edge function or Twilio REST API.
  Future<Map<String, dynamic>> sendSms({
    required String to,
    required String message,
  }) async {
    // 1. Try via Supabase Edge Function first if available
    final client = _supabase;
    if (client != null) {
      try {
        final res = await client.functions.invoke(
          'send-twilio-notification',
          body: {
            'action': 'send_sms',
            'to': to,
            'message': message,
          },
        );

        if (res.status == 200 && res.data is Map) {
          return Map<String, dynamic>.from(res.data as Map);
        }
      } catch (e) {
        debugPrint('[Twilio] Edge function invoke failed ($e), falling back to direct API.');
      }
    }

    // 2. Direct Twilio REST API fallback
    final accountSid = EnvConfig.twilioAccountSid;
    final authToken = EnvConfig.twilioAuthToken;
    final fromNumber = EnvConfig.twilioFromNumber;

    final basicAuth = base64Encode(utf8.encode('$accountSid:$authToken'));
    final url = 'https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json';

    final bodyData = <String, String>{
      'To': to,
      'Body': message,
    };
    if (fromNumber.isNotEmpty) {
      bodyData['From'] = fromNumber;
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        url,
        data: bodyData,
        options: Options(
          headers: {'Authorization': 'Basic $basicAuth'},
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      final data = response.data ?? {};
      return {
        'status': 'success',
        'sid': data['sid'],
        'to': data['to'],
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      final errorMsg = data is Map ? data['message'] : e.message;
      return {
        'status': 'error',
        'error': errorMsg ?? 'Failed to send SMS',
        'code': data is Map ? data['code'] : null,
      };
    } catch (e) {
      return {'status': 'error', 'error': e.toString()};
    }
  }

  /// Dispatches a verification OTP to [to] using Twilio Verify API.
  Future<Map<String, dynamic>> sendVerificationCode({
    required String to,
    String channel = 'sms',
  }) async {
    // 1. Try Supabase Edge Function first (send-twilio-notification)
    try {
      final res = await _supabase?.functions.invoke(
        'send-twilio-notification',
        body: {'to': to, 'action': 'send_otp', 'channel': channel},
      );
      if (res != null && res.data != null) {
        final data = res.data;
        if (data is Map && (data['status'] == 'pending' || data['sid'] != null)) {
          debugPrint('[Twilio] OTP sent via edge function: ${data['sid']}');
          return {
            'success': true,
            'status': 'pending',
            'sid': data['sid'],
            'to': to,
          };
        }
      }
    } catch (e) {
      debugPrint('[Twilio] Edge function invoke failed for send_otp ($e), falling back to direct API.');
    }

    // 2. Direct Twilio Verify API fallback
    final accountSid = EnvConfig.twilioAccountSid;
    final authToken = EnvConfig.twilioAuthToken;
    final serviceSid = EnvConfig.twilioVerifyServiceSid;

    final basicAuth = base64Encode(utf8.encode('$accountSid:$authToken'));
    final url = 'https://verify.twilio.com/v2/Services/$serviceSid/Verifications';

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        url,
        data: {
          'To': to,
          'Channel': channel,
        },
        options: Options(
          headers: {'Authorization': 'Basic $basicAuth'},
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      final data = response.data ?? {};
      return {
        'success': true,
        'status': 'pending',
        'sid': data['sid'],
        'to': data['to'],
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      final errorMsg = data is Map ? data['message'] : e.message;
      final errorCode = data is Map ? data['code'] : null;
      final errStr = errorMsg?.toString().toLowerCase() ?? '';
      final isTrial = errorCode == 21608 ||
          errStr.contains('unverified') ||
          errStr.contains('compliance') ||
          errStr.contains('trusthub') ||
          errStr.contains('caller id');
      return {
        'status': 'error',
        'error': ErrorSanitizer.format(errorMsg ?? 'Failed to send verification code'),
        'code': errorCode,
        'isTrialRestriction': isTrial,
      };
    } catch (e) {
      return {'status': 'error', 'error': ErrorSanitizer.format(e)};
    }
  }

  /// Verifies a 6-digit OTP code with Twilio Verify API.
  Future<bool> verifyCode({
    required String to,
    required String code,
  }) async {
    // 1. Try Supabase Edge Function first
    try {
      final res = await _supabase?.functions.invoke(
        'send-twilio-notification',
        body: {'to': to, 'code': code, 'action': 'verify_otp'},
      );
      if (res != null && res.data != null) {
        final data = res.data;
        if (data is Map && data['status'] == 'approved') {
          debugPrint('[Twilio] OTP verified via edge function: approved');
          return true;
        }
      }
    } catch (e) {
      debugPrint('[Twilio] Edge function invoke failed for verify_otp ($e), falling back to direct API.');
    }

    // 2. Direct Twilio Verify API fallback
    final accountSid = EnvConfig.twilioAccountSid;
    final authToken = EnvConfig.twilioAuthToken;
    final serviceSid = EnvConfig.twilioVerifyServiceSid;

    final basicAuth = base64Encode(utf8.encode('$accountSid:$authToken'));
    final url = 'https://verify.twilio.com/v2/Services/$serviceSid/VerificationCheck';

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        url,
        data: {
          'To': to,
          'Code': code,
        },
        options: Options(
          headers: {'Authorization': 'Basic $basicAuth'},
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      final data = response.data ?? {};
      return data['status'] == 'approved';
    } catch (e) {
      debugPrint('[Twilio] Verification check failed: $e');
      return false;
    }
  }
}
