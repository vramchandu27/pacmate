import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../shared/models/user_model.dart';
import 'firebase_service.dart';

// ─── AUTH SERVICE ─────────────────────────────────────────────────────────────
// Handles email/password, Google sign-in, sign-out, and Firestore profile.
// ─────────────────────────────────────────────────────────────────────────────

class AuthService {
  AuthService(this._firebase);

  final FirebaseService _firebase;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  FirebaseAuth get _auth => _firebase.auth;

  // ── Current user stream ────────────────────────────────────────────────────

  Stream<User?> get authStateChanges => _firebase.authStateChanges;

  User? get currentUser => _auth.currentUser;

  String? get currentUserId => _auth.currentUser?.uid;

  bool get isLoggedIn => _auth.currentUser != null;

  // ── Sign Up ────────────────────────────────────────────────────────────────

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // Parallelize display name update + email verification
    await Future.wait([
      credential.user?.updateDisplayName(fullName.trim()) ?? Future.value(),
      credential.user?.sendEmailVerification() ?? Future.value(),
    ]);

    await _createUserProfile(
      uid: credential.user!.uid,
      email: email.trim(),
      fullName: fullName.trim(),
      photoUrl: credential.user?.photoURL,
    );

    // Analytics — fire and forget
    _firebase.logSignUp('email').ignore();
    return credential;
  }

  // ── Sign In ────────────────────────────────────────────────────────────────

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // Block unverified email accounts — sign them out and surface a clear error.
    if (credential.user != null && !credential.user!.emailVerified) {
      await _auth.signOut();
      throw FirebaseAuthException(code: 'email-not-verified');
    }

    // Presence update is best-effort — don't let a missing Firestore doc
    // block a successful login.
    try {
      await _updatePresence(credential.user!.uid, isOnline: true);
    } catch (_) {}
    try {
      await _firebase.logLogin('email');
    } catch (_) {}

    return credential;
  }

  // ── Google Sign-In ─────────────────────────────────────────────────────────

  Future<UserCredential?> signInWithGoogle() async {
    // Clear any stale local session before starting.
    // A deleted account's cached session causes signInWithCredential to fail.
    try {
      await _googleSignIn.signOut();
      if (_auth.currentUser != null) await _auth.signOut();
    } catch (_) {}

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // user cancelled

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user!;

    // Check Firestore doc directly — isNewUser can be unreliable when an
    // account was deleted from Firebase Console and re-created with the same
    // Google account (Firebase Auth says "returning user" but the doc is gone).
    final docSnap = await _firebase.usersRef.doc(user.uid).get();
    final hasProfile = docSnap.exists;

    if (!hasProfile) {
      await _createUserProfile(
        uid: user.uid,
        email: user.email ?? '',
        fullName: user.displayName ?? 'Traveler',
        photoUrl: user.photoURL,
      );
      await _firebase.logSignUp('google');
    } else {
      await _updatePresence(user.uid, isOnline: true);
      await _firebase.logLogin('google');
    }

    return userCredential;
  }

  // ── Forgot Password ────────────────────────────────────────────────────────

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ── Resend Verification Email ──────────────────────────────────────────────

  /// Signs in temporarily to resend the verification email, then signs out.
  /// Returns null if credentials are wrong or any error occurs.
  Future<bool> resendVerificationEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user?.emailVerified == false) {
        await credential.user?.sendEmailVerification();
      }
      await _auth.signOut();
      return true;
    } catch (_) {
      try { await _auth.signOut(); } catch (_) {}
      return false;
    }
  }

  // ── Sign Out ───────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    final uid = currentUserId;
    if (uid != null) {
      await _updatePresence(uid, isOnline: false);
    }
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── Delete Account ─────────────────────────────────────────────────────────

  Future<void> deleteAccount() async {
    final uid = currentUserId;
    if (uid == null) return;

    // Cloud Functions onUserDeleted will clean up Firestore data
    await _auth.currentUser?.delete();
  }

  // ── Profile Completeness ───────────────────────────────────────────────────

  Future<bool> isProfileComplete() async {
    final uid = currentUserId;
    if (uid == null) return false;
    final doc = await _firebase.usersRef.doc(uid).get();
    if (!doc.exists) return false;
    return doc.data()?['profileComplete'] as bool? ?? false;
  }

  // ── Get Current User Model ─────────────────────────────────────────────────

  Future<UserModel?> getCurrentUserModel() async {
    final uid = currentUserId;
    if (uid == null) return null;
    final doc = await _firebase.usersRef.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Stream<UserModel?> watchCurrentUser() {
    final uid = currentUserId;
    if (uid == null) return const Stream.empty();
    return _firebase.usersRef.doc(uid).snapshots().map(
          (snap) => snap.exists ? UserModel.fromFirestore(snap) : null,
        );
  }

  // ── Update Profile ─────────────────────────────────────────────────────────

  // Whitelist prevents callers from overwriting privileged fields (isPro,
  // plan, totalTrips, profileComplete, etc.) via this public method.
  static const _allowedProfileFields = {
    'fullName', 'photoUrl', 'nationality', 'homeCity', 'homeCountry',
    'bio', 'travelStyle', 'travelType', 'languages', 'isOnline', 'lastSeen',
    'notificationsEnabled', 'emergencyContact', 'bloodGroup',
    'medicalNotes', 'currency', 'timezone',
    'phone', 'avatar', 'seniorMode',
  };

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    final uid = currentUserId;
    if (uid == null) return;
    final safe = Map.fromEntries(
      updates.entries.where((e) => _allowedProfileFields.contains(e.key)),
    );
    if (safe.isEmpty) return;
    await _firebase.usersRef.doc(uid).update({
      ...safe,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markProfileComplete() async {
    final uid = currentUserId;
    if (uid == null) return;
    await _firebase.usersRef.doc(uid).update({'profileComplete': true});
  }

  // ── Profile Photo Upload ───────────────────────────────────────────────────

  Future<String> uploadProfilePhoto(File photo) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not logged in');

    final ref = _firebase.profilePhotosRef(uid).child('avatar.jpg');
    await ref
        .putFile(photo, SettableMetadata(contentType: 'image/jpeg'))
        .timeout(const Duration(seconds: 30));
    final url = await ref.getDownloadURL().timeout(const Duration(seconds: 10));

    // Firestore update is critical; Auth update is best-effort
    await updateProfile({'photoUrl': url});
    _auth.currentUser?.updatePhotoURL(url).ignore();

    return url;
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  Future<void> _createUserProfile({
    required String uid,
    required String email,
    required String fullName,
    String? photoUrl,
  }) async {
    final now = DateTime.now();
    final user = UserModel(
      uid: uid,
      email: email,
      fullName: fullName,
      photoUrl: photoUrl,
      createdAt: now,
      lastSeen: now,
    );

    await _firebase.usersRef.doc(uid).set(user.toFirestore());

    // FCM token — best-effort, don't block profile creation
    _firebase.saveFcmToken().ignore();
  }

  Future<void> _updatePresence(String uid, {required bool isOnline}) async {
    await _firebase.usersRef.doc(uid).set(
      {
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}

// ─── PROVIDERS ────────────────────────────────────────────────────────────────

final firebaseServiceProvider = Provider<FirebaseService>(
  (ref) => FirebaseService.instance,
);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.read(firebaseServiceProvider)),
);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.read(authServiceProvider).authStateChanges;
});

final currentUserModelProvider = StreamProvider<UserModel?>((ref) {
  return ref.read(authServiceProvider).watchCurrentUser();
});
