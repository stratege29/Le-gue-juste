import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_entity.dart';
import '../../data/models/user_model.dart';
import '../../../../core/constants/firebase_constants.dart';

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
  final String? verificationId;
  final String? phoneNumber;
  final bool codeSent;
  final bool needsProfileSetup;

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.verificationId,
    this.phoneNumber,
    this.codeSent = false,
    this.needsProfileSetup = false,
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? verificationId,
    String? phoneNumber,
    bool? codeSent,
    bool? needsProfileSetup,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
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

  AuthNotifier(this._auth, this._firestore, this._storage, this._ref) : super(const AuthState());

  Future<void> sendOtp(String phoneNumber) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (Android)
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: _mapAuthError(e),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
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
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'An error occurred. Please try again.',
      );
    }
  }

  Future<void> verifyOtp(String smsCode) async {
    if (state.verificationId == null) {
      state = state.copyWith(errorMessage: 'Verification ID not found');
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
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Invalid verification code',
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

  Future<void> createProfile(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) {
      state = state.copyWith(errorMessage: 'User not found');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final now = DateTime.now();
      final qrCode = _generateQrCode(user.uid);

      await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(user.uid)
          .set({
        FirebaseConstants.phoneNumber: user.phoneNumber,
        FirebaseConstants.displayName: displayName,
        FirebaseConstants.qrCode: qrCode,
        FirebaseConstants.createdAt: Timestamp.fromDate(now),
        FirebaseConstants.updatedAt: Timestamp.fromDate(now),
      });

      state = state.copyWith(
        isLoading: false,
        needsProfileSetup: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to create profile',
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
        errorMessage: 'Failed to update profile',
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
        errorMessage: 'Failed to upload avatar',
      );
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    state = const AuthState();
  }

  void resetState() {
    state = const AuthState();
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Invalid phone number format';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'invalid-verification-code':
        return 'Invalid verification code';
      case 'session-expired':
        return 'Session expired. Please request a new code.';
      default:
        return e.message ?? 'An error occurred';
    }
  }
}
