import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(FirebaseAuth.instance);
});

class AuthController {
  final FirebaseAuth _auth;
  AuthController(this._auth);

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) => _auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) => _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Stream<User?> authState() => _auth.authStateChanges();
}
