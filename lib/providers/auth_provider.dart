import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  AppUser? _user;
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _error;
  StreamSubscription? _authSubscription;
  /// Wipes every per-user provider (steps, sleep, meals, workouts, ...).
  /// Invoked on sign-out *and* on each successful sign-in, so an account never
  /// starts out showing figures left behind by the previous session.
  VoidCallback? onLogout;

  /// Called before a new session's data is loaded. Kept separate from the
  /// sign-in result so a failed attempt does not wipe the current session.
  void _resetSessionData() => onLogout?.call();

  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  static const int _maxFailedAttempts = 3;
  static const Duration _lockoutDuration = Duration(minutes: 5);

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  int get failedAttempts => _failedAttempts;
  bool get isLockedOut =>
      _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);
  Duration? get lockoutRemaining {
    if (_lockoutUntil == null) return null;
    final remaining = _lockoutUntil!.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  AuthProvider() {
    if (!_authService.isDemoMode) {
      _authSubscription = _authService.authStateChanges.listen((firebaseUser) async {
        _isInitializing = false;
        if (firebaseUser != null) {
          try {
            await _authService.loadUserFromFirestore(firebaseUser.uid);
            _user = _authService.currentUser;
          } catch (_) {
            _user = AppUser(
              uid: firebaseUser.uid,
              email: firebaseUser.email ?? '',
              displayName: firebaseUser.displayName ?? '',
            );
          }
        } else {
          _user = null;
        }
        notifyListeners();
      });
    } else {
      _isInitializing = false;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<bool> login(String email, String password) async {
    if (isLockedOut) {
      _error = 'Too many failed attempts. Please try again later.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _authService.signInWithEmail(email, password);
      // Drop the previous session's steps/sleep/meals before this account's
      // own data is loaded, so nothing carries over between users.
      _resetSessionData();
      _isLoading = false;
      _failedAttempts = 0;
      _lockoutUntil = null;
      notifyListeners();
      return _user != null;
    } catch (e) {
      _failedAttempts++;
      if (_failedAttempts >= _maxFailedAttempts) {
        _lockoutUntil = DateTime.now().add(_lockoutDuration);
        _error = 'Too many failed attempts. Please try again later.';
      } else {
        _error = 'Invalid password. Please try again.';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(
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
    String? dietPreference,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _authService.registerWithEmail(
        email,
        password,
        name,
        targetWeightKg: targetWeightKg,
        dailyCalorieTarget: dailyCalorieTarget,
        workoutGoal: workoutGoal,
        workoutEndDate: workoutEndDate,
        age: age,
        weight: weight,
        height: height,
        activityLevel: activityLevel,
        gender: gender,
        dietPreference: dietPreference,
      );
      // A brand-new account must start at 0 steps and 0 hours of sleep, not
      // inherit whatever was in memory from a previous session.
      _resetSessionData();
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _authService.signInWithGoogle();
      _resetSessionData();
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Emails a reset link. Does not set the password itself — see
  /// [changePassword] for that.
  Future<bool> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _authService.sendPasswordResetEmail(email);
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Changes the signed-in user's password to exactly [newPassword], after
  /// verifying [currentPassword].
  Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.changePassword(currentPassword, newPassword);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateProfile(AppUser user) async {
    await _authService.updateUserProfile(user);
    _user = user;
    notifyListeners();
  }

  Future<void> updateSelectedPlan(String? planId) async {
    if (_user == null) return;
    final updated = _user!.copyWith(selectedPlanId: planId);
    await _authService.updateUserProfile(updated);
    _user = updated;
    notifyListeners();
  }

  Future<void> logout() async {
    await _authService.signOut();
    _user = null;
    onLogout?.call();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
