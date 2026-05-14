import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:esl_learning_flutter/backend/auth/session_prefs.dart';
import 'package:esl_learning_flutter/backend/database/sqlite_helper.dart';
import 'package:esl_learning_flutter/backend/repositories/user_repository.dart';

enum AuthSessionStatus { authenticated, unauthenticated }

class AuthSessionState {
  const AuthSessionState({
    this.status = AuthSessionStatus.unauthenticated,
    this.userId,
    this.email,
    this.fullName,
    this.languagePreference,
  });

  final AuthSessionStatus status;
  final int? userId;
  final String? email;
  final String? fullName;
  final String? languagePreference;

  bool get isAuthenticated =>
      status == AuthSessionStatus.authenticated && userId != null;

  AuthSessionState copyWith({
    AuthSessionStatus? status,
    int? userId,
    String? email,
    String? fullName,
    String? languagePreference,
    bool clearUser = false,
  }) {
    if (clearUser) {
      return const AuthSessionState(status: AuthSessionStatus.unauthenticated);
    }
    return AuthSessionState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      languagePreference: languagePreference ?? this.languagePreference,
    );
  }

  static AuthSessionState fromUserRow(Map<String, Object?> row) {
    return AuthSessionState(
      status: AuthSessionStatus.authenticated,
      userId: row['id'] as int,
      email: row['email'] as String,
      fullName: row['full_name'] as String,
      languagePreference: row['language_preference'] as String? ?? 'en',
    );
  }
}

class AuthSessionNotifier extends StateNotifier<AuthSessionState> {
  AuthSessionNotifier(this._users, this._helper)
    : super(const AuthSessionState());

  final UserRepository _users;
  final SQLiteHelper _helper;

  static const duplicateEmailMessage = 'Email already registered.';
  static const invalidCredentialsMessage = 'Invalid email or password.';

  Future<void> bootstrap() async {
    await _helper.database;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(SessionPrefs.tokenKey);
    final userId = prefs.getInt(SessionPrefs.userIdKey);
    if (token == null || token.isEmpty || userId == null) {
      await _clearSessionPrefs(prefs);
      state = const AuthSessionState();
      return;
    }
    final user = await _users.getUserById(userId);
    if (user == null) {
      await _clearSessionPrefs(prefs);
      state = const AuthSessionState();
      return;
    }
    state = AuthSessionState.fromUserRow(user);
  }

  Future<String?> signIn(String email, String password) async {
    final user = await _users.getUserByEmail(email);
    if (user == null) return invalidCredentialsMessage;
    final hash = user['password_hash'] as String?;
    if (hash == null || hash.isEmpty) return invalidCredentialsMessage;
    if (!_users.verifyPassword(password, hash)) return invalidCredentialsMessage;
    final id = user['id'] as int;
    await _users.touchLogin(id);
    final prefs = await SharedPreferences.getInstance();
    await _persistSession(prefs, id);
    state = AuthSessionState.fromUserRow(user);
    return null;
  }

  Future<String?> signUp({
    required String fullName,
    required String email,
    required String password,
    String languagePreference = 'en',
  }) async {
    try {
      final id = await _users.insertUser(
        email: email,
        passwordPlain: password,
        fullName: fullName,
        languagePreference: languagePreference,
      );
      final prefs = await SharedPreferences.getInstance();
      await _persistSession(prefs, id);
      final row = await _users.getUserById(id);
      if (row == null) {
        await _clearSessionPrefs(prefs);
        state = const AuthSessionState();
        return 'Could not load new account.';
      }
      state = AuthSessionState.fromUserRow(row);
      return null;
    } on DatabaseException catch (e) {
      final msg = e.toString();
      if (msg.contains('UNIQUE') || msg.contains('unique')) {
        return duplicateEmailMessage;
      }
      return msg;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await _clearSessionPrefs(prefs);
    state = const AuthSessionState();
  }

  void applyLocalProfile({required String fullName, required String email}) {
    if (!state.isAuthenticated) return;
    state = state.copyWith(fullName: fullName, email: email);
  }

  void applyLanguagePreference(String languagePreference) {
    if (!state.isAuthenticated) return;
    state = state.copyWith(languagePreference: languagePreference);
  }

  Future<void> _persistSession(SharedPreferences prefs, int userId) async {
    final token = const Uuid().v4();
    await prefs.setString(SessionPrefs.tokenKey, token);
    await prefs.setInt(SessionPrefs.userIdKey, userId);
    await prefs.setBool('hasUser', true);
  }

  Future<void> _clearSessionPrefs(SharedPreferences prefs) async {
    await prefs.remove(SessionPrefs.tokenKey);
    await prefs.remove(SessionPrefs.userIdKey);
    await prefs.remove('hasUser');
  }
}
