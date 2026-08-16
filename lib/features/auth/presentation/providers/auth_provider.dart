import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_entity.dart';
import '../../data/models/user_model.dart';
import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/services/deep_link_service.dart';
import '../../../../core/services/push_notification_service.dart';

// Firebase Storage instance
final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

// Firebase instances
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// Auth state stream
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

// Current user profile
final currentUserProvider = FutureProvider<UserEntity?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.valueOrNull;

  if (user == null) return null;

  final doc = await ref
      .watch(firestoreProvider)
      .collection(FirebaseConstants.usersCollection)
      .doc(user.uid)
      .get();

  if (!doc.exists) return null;

  return UserModel.fromFirestore(doc).toEntity();
});

// Auth notifier for managing auth state
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
    ref.watch(firebaseStorageProvider),
    ref,
  );
});

class AuthState {
  final bool isLoading;
  final String? errorMessage;

  /// FirebaseAuthException code associated with [errorMessage], when known.
  /// Lets the UI react to specific failures (e.g. `session-expired` unlocks
  /// the resend button) without matching on localized message text.
  final String? errorCode;
  final String? verificationId;
  final String? phoneNumber;
  final bool codeSent;
  final bool needsProfileSetup;

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.errorCode,
    this.verificationId,
    this.phoneNumber,
    this.codeSent = false,
    this.needsProfileSetup = false,
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? errorCode,
    String? verificationId,
    String? phoneNumber,
    bool? codeSent,
    bool? needsProfileSetup,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      errorCode: errorCode,
      verificationId: verificationId ?? this.verificationId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      codeSent: codeSent ?? this.codeSent,
      needsProfileSetup: needsProfileSetup ?? this.needsProfileSetup,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final Ref _ref;

  int? _resendToken;

  /// Guards against `verifyPhoneNumber` never calling back — mainly the iOS
  /// reCAPTCHA fallback, which can hang and leave the UI spinning forever.
  Timer? _sendOtpWatchdog;
  bool _sendOtpSettled = true;

  AuthNotifier(this._auth, this._firestore, this._storage, this._ref) : super(const AuthState());

  /// Marks the current sendOtp attempt as resolved and cancels the watchdog.
  void _settleSendOtp() {
    _sendOtpSettled = true;
    _sendOtpWatchdog?.cancel();
    _sendOtpWatchdog = null;
  }

  Future<void> sendOtp(String phoneNumber) async {
    debugPrint('sendOtp called');

    // A resend token is only valid for the number it was issued for: reusing
    // it after the user changed numbers makes the SMS send fail.
    if (state.phoneNumber != null && state.phoneNumber != phoneNumber) {
      _resendToken = null;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    _sendOtpWatchdog?.cancel();
    _sendOtpSettled = false;
    // Slightly longer than verifyPhoneNumber's own 60s timeout so Firebase gets
    // a chance to report the failure itself before we give up on it.
    _sendOtpWatchdog = Timer(const Duration(seconds: 75), () {
      if (_sendOtpSettled) return;
      _settleSendOtp();
      debugPrint('sendOtp watchdog fired: no callback received after 75s');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'L\'envoi du SMS n\'a pas abouti. Vérifiez votre connexion et réessayez.',
      );
    });

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (Android)
          _settleSendOtp();
          try {
            await _signInWithCredential(credential);
          } on FirebaseAuthException catch (e) {
            debugPrint('verificationCompleted FirebaseAuthException: code="${e.code}"');
            state = state.copyWith(
              isLoading: false,
              errorMessage: _mapAuthError(e),
              errorCode: e.code,
            );
          } catch (e) {
            debugPrint('verificationCompleted error: $e');
            state = state.copyWith(
              isLoading: false,
              errorMessage: 'La vérification automatique a échoué. Veuillez entrer le code manuellement.',
            );
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          // Only the code: the message and stack can echo the phone number.
          debugPrint('verificationFailed: code="${e.code}"');
          _settleSendOtp();
          state = state.copyWith(
            isLoading: false,
            errorMessage: _mapAuthError(e),
            errorCode: e.code,
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          _settleSendOtp();
          _resendToken = resendToken;
          state = state.copyWith(
            isLoading: false,
            verificationId: verificationId,
            phoneNumber: phoneNumber,
            codeSent: true,
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          state = state.copyWith(verificationId: verificationId);
        },
      );
    } catch (e) {
      debugPrint('sendOtp error: $e');
      _settleSendOtp();
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible d\'envoyer le SMS. Vérifiez votre connexion internet.',
      );
    }
  }

  @override
  void dispose() {
    _sendOtpWatchdog?.cancel();
    super.dispose();
  }

  Future<void> verifyOtp(String smsCode) async {
    // In-flight guard: the OTP screen auto-submits when 6 digits are entered
    // and the button can race it — never run two signInWithCredential calls.
    if (state.isLoading) return;

    if (state.verificationId == null) {
      state = state.copyWith(
        errorMessage: 'Session expirée. Veuillez redemander un code.',
        errorCode: 'session-expired',
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: state.verificationId!,
        smsCode: smsCode,
      );
      await _signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapAuthError(e),
        errorCode: e.code,
      );
    } catch (e) {
      debugPrint('verifyOtp error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Code de vérification invalide.',
      );
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;

    if (user != null) {
      // Check if user profile exists
      final doc = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(user.uid)
          .get();

      state = state.copyWith(
        isLoading: false,
        needsProfileSetup: !doc.exists,
      );
    }
  }

  Future<void> createProfile(String displayName, {String? avatarEmoji}) async {
    final user = _auth.currentUser;
    if (user == null) {
      state = state.copyWith(errorMessage: 'Utilisateur non trouvé. Veuillez vous reconnecter.');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final now = DateTime.now();
      final docRef = _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(user.uid);

      final data = <String, dynamic>{
        FirebaseConstants.displayName: displayName,
        FirebaseConstants.updatedAt: Timestamp.fromDate(now),
      };

      if (avatarEmoji != null) {
        data[FirebaseConstants.avatarUrl] = 'emoji:$avatarEmoji';
      }

      // If a profile document already exists (e.g. an existing user wrongly
      // routed here after a transient fetch error), NEVER regenerate the QR
      // code or reset createdAt: friends and shared invites reference them.
      final existingDoc = await docRef.get();
      if (existingDoc.exists) {
        await docRef.set(data, SetOptions(merge: true));
      } else {
        data[FirebaseConstants.phoneNumber] = user.phoneNumber;
        data[FirebaseConstants.qrCode] = _generateQrCode(user.uid);
        data[FirebaseConstants.createdAt] = Timestamp.fromDate(now);
        await docRef.set(data);
      }

      // Invalidate cached user so router redirect sees the new profile
      _ref.invalidate(currentUserProvider);

      state = state.copyWith(
        isLoading: false,
        needsProfileSetup: false,
      );
    } catch (e, stackTrace) {
      debugPrint('createProfile error: $e');
      debugPrint('createProfile stackTrace: $stackTrace');
      final detail = kDebugMode ? '\n($e)' : '';
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de créer le profil. Veuillez réessayer.$detail',
      );
    }
  }

  String _generateQrCode(String userId) {
    final shortId = userId.substring(0, 8).toUpperCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    return 'LGJ-$shortId-$timestamp';
  }

  Future<void> updateProfile({String? displayName, String? avatarUrl}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final updates = <String, dynamic>{
        FirebaseConstants.updatedAt: Timestamp.now(),
      };

      if (displayName != null) {
        updates[FirebaseConstants.displayName] = displayName;
      }

      if (avatarUrl != null) {
        updates['avatarUrl'] = avatarUrl;
      }

      await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(user.uid)
          .update(updates);

      state = state.copyWith(isLoading: false);

      // Refresh the currentUserProvider to reload user data
      _ref.invalidate(currentUserProvider);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de mettre à jour le profil.',
      );
    }
  }

  /// Upload an avatar image to Firebase Storage and return the download URL
  Future<String?> uploadAvatar(File imageFile) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Create a reference to the avatar location
      final ref = _storage.ref().child('avatars').child('${user.uid}.jpg');

      // Upload the file
      await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Get the download URL
      final downloadUrl = await ref.getDownloadURL();

      // Update the user profile with the new avatar URL
      await updateProfile(avatarUrl: downloadUrl);

      state = state.copyWith(isLoading: false);
      return downloadUrl;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de télécharger l\'avatar.',
      );
      return null;
    }
  }

  Future<void> signOut() async {
    // Delete FCM token before signing out
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': FieldValue.delete()});
      }
    } catch (e) {
      debugPrint('Failed to delete FCM token on signout: $e');
    }

    await _auth.signOut();
    _resendToken = null;

    // Pending deep links / notification routes belong to the account that was
    // signed in — never apply them to the next account on this device.
    _ref.read(pendingDeepLinkQrCodeProvider.notifier).state = null;
    _ref.read(pendingNotificationRouteProvider.notifier).state = null;

    state = const AuthState();
  }

  void resetState() {
    _resendToken = null;
    state = const AuthState();
  }

  /// Message shown when Firebase refuses to send an SMS to the number's country.
  /// Kept in sync with the SMS region allowlist configured on the Firebase project.
  static const String _regionBlockedMessage =
      'Les SMS ne sont pas disponibles pour ce pays. Utilisez un numéro d\'un pays pris en charge.';

  String _mapAuthError(FirebaseAuthException e) {
    // Region blocking surfaces under several codes depending on the platform SDK,
    // and sometimes only in the message, so match on both.
    final rawMessage = (e.message ?? '').toUpperCase();
    if (rawMessage.contains('SMS_REGION') ||
        rawMessage.contains('UNSUPPORTED_REGION') ||
        rawMessage.contains('REGION_NOT_ALLOWED')) {
      return _regionBlockedMessage;
    }

    switch (e.code) {
      case 'invalid-phone-number':
        return 'Numéro de téléphone invalide.';
      case 'unsupported-first-factor':
      case 'admin-restricted-operation':
      case 'sms-region-not-allowed':
      case 'unsupported-region':
        return _regionBlockedMessage;
      case 'operation-not-allowed':
        return 'La connexion par SMS est désactivée sur ce projet. Contactez le support.';
      case 'billing-not-enabled':
        return 'Le service SMS est temporairement indisponible. Contactez le support.';
      case 'invalid-app-credential':
        return 'La vérification de l\'application a échoué. Réinstallez l\'application ou réessayez.';
      case 'too-many-requests':
        return 'Trop de tentatives. Veuillez réessayer dans quelques minutes.';
      case 'invalid-verification-code':
        return 'Code de vérification invalide.';
      case 'session-expired':
        return 'Session expirée. Veuillez redemander un code.';
      case 'network-request-failed':
        return 'Erreur réseau. Vérifiez votre connexion internet.';
      case 'quota-exceeded':
        return 'Quota SMS dépassé. Veuillez réessayer plus tard.';
      case 'user-disabled':
        return 'Ce compte a été désactivé.';
      case 'credential-already-in-use':
        return 'Ce numéro est déjà associé à un autre compte.';
      case 'app-not-authorized':
        return 'L\'application n\'est pas autorisée. Contactez le support.';
      case 'missing-client-identifier':
        return 'Configuration manquante. Veuillez mettre à jour l\'application.';
      case 'internal-error':
      case 'unknown':
        if (kDebugMode) {
          return 'Erreur [${e.code}]: ${e.message ?? "no message"}';
        }
        return 'Une erreur est survenue. Veuillez réessayer.';
      case 'web-context-cancelled':
        return 'Vérification annulée. Veuillez réessayer.';
      case 'captcha-check-failed':
        return 'Vérification reCAPTCHA échouée. Veuillez réessayer.';
      case 'missing-phone-number':
        return 'Numéro de téléphone manquant.';
      default:
        debugPrint('Unhandled FirebaseAuthException code: "${e.code}", message: "${e.message}"');
        if (kDebugMode) {
          return 'Erreur auth [${e.code}]: ${e.message}';
        }
        return 'Une erreur est survenue. Veuillez réessayer.';
    }
  }
}
