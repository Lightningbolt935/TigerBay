import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';

/// Result of [FirebasePhoneAuthService.deleteCurrentUser].
enum FirebaseDeleteResult {
  /// A Firebase user existed and was deleted.
  deleted,

  /// No Firebase user was signed in (e.g. Supabase-only / social login).
  /// Nothing was deleted on the Firebase side. This is NOT an error, but the
  /// caller must not assume a Firebase account was removed.
  noFirebaseUser,
}

/// Thrown when Firebase refuses a sensitive operation because the user's
/// sign-in is too old. The UI should re-authenticate (send an OTP to
/// [FirebasePhoneAuthService.currentPhoneNumber], then call
/// [FirebasePhoneAuthService.reauthenticateWithOtp]) and retry.
class FirebaseRequiresRecentLoginException implements Exception {
  final String message;
  const FirebaseRequiresRecentLoginException([
    this.message = 'Please verify your identity again to continue.',
  ]);

  @override
  String toString() => 'FirebaseRequiresRecentLoginException: $message';
}

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
        debugPrint(
            '[Firebase Phone Auth] Verification failed: ${exception.message}');
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

  // ═════════════════════════════════════════════════════════════════════════
  // Account deletion support
  // ═════════════════════════════════════════════════════════════════════════

  /// True when a Firebase user is currently signed in. Use this to know
  /// whether a Firebase deletion / re-authentication step is even applicable.
  bool get hasFirebaseUser => _auth.currentUser != null;

  /// The phone number of the current Firebase user (E.164), or null.
  /// Use it to send the re-authentication OTP.
  String? get currentPhoneNumber => _auth.currentUser?.phoneNumber;

  /// Whether the current Firebase user signed in recently enough for
  /// sensitive operations such as deletion. Returns true when there is no
  /// Firebase user (nothing to re-authenticate).
  bool hasRecentSignIn({Duration within = const Duration(minutes: 5)}) {
    final user = _auth.currentUser;
    if (user == null) return true;
    final lastSignIn = user.metadata.lastSignInTime;
    if (lastSignIn == null) return false;
    return DateTime.now().difference(lastSignIn) <= within;
  }

  /// Re-authenticates the current user with a fresh phone OTP.
  /// Call this after catching [FirebaseRequiresRecentLoginException],
  /// then retry [deleteCurrentUser].
  Future<void> reauthenticateWithOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    final credential = firebase_auth.PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    await user.reauthenticateWithCredential(credential);
  }

  /// Permanently deletes the current Firebase user.
  ///
  /// Returns:
  ///  • [FirebaseDeleteResult.deleted] – the Firebase user was deleted.
  ///  • [FirebaseDeleteResult.noFirebaseUser] – no Firebase user was signed in
  ///    (Supabase-only / social login). Nothing was deleted here.
  ///
  /// Throws:
  ///  • [FirebaseRequiresRecentLoginException] – sign-in is too old; the UI
  ///    must re-authenticate via [reauthenticateWithOtp] and retry.
  ///  • [firebase_auth.FirebaseAuthException] – any other Firebase failure.
  ///
  /// Recommended order in the caller:
  ///  1. Supabase: write the `account_deletions` audit row and delete app data
  ///     (the `delete_my_account` RPC does both) while the user is still
  ///     authenticated.
  ///  2. Call this method.
  ///  3. Clear local session / tokens and route to login.
  Future<FirebaseDeleteResult> deleteCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[Firebase Phone Auth] No Firebase user to delete');
      return FirebaseDeleteResult.noFirebaseUser;
    }

    try {
      await user.delete();
      return FirebaseDeleteResult.deleted;
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw FirebaseRequiresRecentLoginException(
          e.message ?? 'Please verify your identity again to continue.',
        );
      }
      rethrow;
    }
  }
}
