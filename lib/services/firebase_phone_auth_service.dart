import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';

/// Service for handling Firebase Phone Authentication
/// Provides SMS OTP functionality with Firebase's built-in phone auth
class FirebasePhoneAuthService {
  final firebase_auth.FirebaseAuth _auth;

  FirebasePhoneAuthService({firebase_auth.FirebaseAuth? auth})
      : _auth = auth ?? firebase_auth.FirebaseAuth.instance;

  /// Sends an OTP to the provided phone number
  /// Returns a verificationId that can be used to verify the OTP
  Future<String> sendOtp({
    required String phoneNumber,
    Duration timeout = const Duration(seconds: 60),
    void Function(firebase_auth.PhoneAuthCredential)? onVerificationCompleted,
    void Function(firebase_auth.FirebaseAuthException)? onVerificationFailed,
    void Function(String, int?)? onCodeSent,
    void Function(String)? onCodeAutoRetrievalTimeout,
  }) async {
    final completer = Completer<String>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: timeout,
      verificationCompleted: (credential) {
        debugPrint('[Firebase Phone Auth] Auto-verification completed');
        onVerificationCompleted?.call(credential);
        if (!completer.isCompleted) {
          // For auto-verification, we return a special marker
          completer.complete('AUTO_VERIFIED');
        }
      },
      verificationFailed: (exception) {
        debugPrint('[Firebase Phone Auth] Verification failed: ${exception.message}');
        onVerificationFailed?.call(exception);
        if (!completer.isCompleted) {
          completer.completeError(exception);
        }
      },
      codeSent: (verificationId, resendToken) {
        debugPrint('[Firebase Phone Auth] OTP sent successfully');
        onCodeSent?.call(verificationId, resendToken);
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        debugPrint('[Firebase Phone Auth] Auto-retrieval timeout');
        onCodeAutoRetrievalTimeout?.call(verificationId);
      },
    );

    return completer.future;
  }

  /// Verifies the OTP code and signs in the user
  /// Returns the UserCredential on success
  Future<firebase_auth.UserCredential> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = firebase_auth.PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    return await _auth.signInWithCredential(credential);
  }

  /// Signs out the current Firebase user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Gets the current Firebase user
  firebase_auth.User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<firebase_auth.User?> get authStateChanges => _auth.authStateChanges();

  /// Links phone credential to existing user (for email users adding phone)
  Future<firebase_auth.UserCredential> linkPhoneToCurrentUser({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = firebase_auth.PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    return await user.linkWithCredential(credential);
  }

  /// Updates the phone number for the current user
  Future<void> updatePhoneNumber({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = firebase_auth.PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    await user.updatePhoneNumber(credential);
  }
}
