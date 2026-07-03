import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

bool _firebaseAvailable() {
  try {
    Firebase.app();
    return true;
  } catch (_) {
    return false;
  }
}

class AuthService {
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // clientId: '200266998037-j4a7ep3mvv6mtd88lh80usl2gu2fk735.apps.googleusercontent.com',
  );
  AppUser? _currentUser;
  bool _demoMode = false;

  AppUser? get currentUser => _currentUser;
  bool get isDemoMode => _demoMode;

  AuthService() {
    if (_firebaseAvailable()) {
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
    } else {
      _demoMode = true;
    }
  }

  Stream<User?> get authStateChanges {
    if (_auth != null) return _auth!.authStateChanges();
    return const Stream.empty();
  }

  Future<AppUser?> signInWithEmail(String email, String password) async {
    if (_demoMode) {
      _currentUser = AppUser(
        uid: 'demo_user',
        email: email,
        displayName: email.split('@').first,
      );
      return _currentUser;
    }
    final result = await _auth!.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _loadUser(result.user!.uid);
    return _currentUser;
  }

  Future<AppUser?> registerWithEmail(
    String email,
    String password,
    String name, {
    double? targetWeightKg,
    double? dailyCalorieTarget,
    String? workoutGoal,
    DateTime? workoutEndDate,
    int? age,
    double? weight,
    double? height,
    String? activityLevel,
    String? gender,
  }) async {
    if (_demoMode) {
      _currentUser = AppUser(
        uid: 'demo_user',
        email: email,
        displayName: name,
        age: age ?? 25,
        weight: weight ?? 65,
        height: height ?? 170,
        gender: gender ?? 'male',
        activityLevel: activityLevel ?? 'moderate',
        targetWeightKg: targetWeightKg,
        dailyCalorieTarget: dailyCalorieTarget,
        workoutGoal: workoutGoal,
        workoutEndDate: workoutEndDate,
      );
      return _currentUser;
    }
    final result = await _auth!.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await result.user!.updateDisplayName(name);
    final user = AppUser(
      uid: result.user!.uid,
      email: email,
      displayName: name,
      age: age ?? 25,
      weight: weight ?? 65,
      height: height ?? 170,
      gender: gender ?? 'male',
      activityLevel: activityLevel ?? 'moderate',
      targetWeightKg: targetWeightKg,
      dailyCalorieTarget: dailyCalorieTarget,
      workoutGoal: workoutGoal,
      workoutEndDate: workoutEndDate,
    );
    await _firestore!
        .collection('users')
        .doc(result.user!.uid)
        .set(user.toMap());
    _currentUser = user;
    return _currentUser;
  }

  Future<AppUser?> signInWithGoogle() async {
    if (_demoMode) {
      _currentUser = AppUser(
        uid: 'demo_user',
        email: 'demo@fitsync.app',
        displayName: 'Demo User',
      );
      return _currentUser;
    }
    final account = await _googleSignIn.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
    final result = await _auth!.signInWithCredential(credential);
    await _loadUser(result.user!.uid);
    return _currentUser;
  }

  Future<void> _loadUser(String uid) async {
    if (_firestore == null) return;
    final doc = await _firestore!.collection('users').doc(uid).get();
    if (doc.exists) {
      final map = doc.data();
      _currentUser = AppUser.fromMap(map is Map<String, dynamic> ? map : {});
    } else {
      final firebaseUser = _auth!.currentUser!;
      _currentUser = AppUser(
        uid: uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName ?? '',
      );
      await _firestore!.collection('users').doc(uid).set(_currentUser!.toMap());
    }
  }

  Future<void> loadUserFromFirestore(String uid) async {
    await _loadUser(uid);
  }

  Future<void> updateUserProfile(AppUser user) async {
    if (_firestore != null) {
      await _firestore!.collection('users').doc(user.uid).update(user.toMap());
    }
    _currentUser = user;
  }

  Future<String?> sendPhoneOtp(String phoneNumber) async {
    if (_demoMode) {
      return 'demo-verification-id';
    }
    if (_auth == null) return null;

    Completer<String?> completer = Completer();

    await _auth!.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
        final result = await _auth!.signInWithCredential(credential);
        await _loadUser(result.user!.uid);
      },
      verificationFailed: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      codeSent: (verificationId, forceResendingToken) {
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
    );

    return completer.future;
  }

  Future<AppUser?> verifyPhoneOtp(String verificationId, String smsCode) async {
    if (_demoMode) {
      _currentUser = AppUser(
        uid: 'demo_user',
        email: 'demo@fitsync.app',
        displayName: 'Demo User',
      );
      return _currentUser;
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final result = await _auth!.signInWithCredential(credential);
    await _loadUser(result.user!.uid);
    return _currentUser;
  }

  Future<bool> resetPassword(String email, String name, String newPassword) async {
    if (_demoMode) return true;
    if (_auth == null) return false;
    try {
      await _auth!.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('No account found with this email');
      }
      throw Exception('Failed to send reset email. Please try again.');
    } catch (e) {
      throw Exception('Failed to send reset email. Please try again.');
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    if (_auth != null) {
      await _auth!.signOut();
    }
    _currentUser = null;
  }
}
