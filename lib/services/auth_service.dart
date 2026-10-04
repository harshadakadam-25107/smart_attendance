import 'package:firebase_auth/firebase_auth.dart';
import '../services/biometric_service.dart';

class AuthService {

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ GET CURRENT USER
  User? get currentUser => _auth.currentUser;

  // ─────────────────────────────────────────────
  // ✅ REGISTER
  // ─────────────────────────────────────────────
  Future<String> register(String email, String password) async {
    try {

      // 🔹 Validation
      if (email.isEmpty || password.isEmpty) {
        return "Please fill all fields";
      }

      if (password.length < 6) {
        return "Password must be at least 6 characters";
      }

      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      return "success";

    } on FirebaseAuthException catch (e) {

      if (e.code == 'email-already-in-use') {
        return "Email already in use";
      } else if (e.code == 'invalid-email') {
        return "Invalid email";
      } else if (e.code == 'weak-password') {
        return "Weak password";
      }

      return "Registration failed";

    } catch (e) {
      return "Something went wrong";
    }
  }

  // ─────────────────────────────────────────────
  // ✅ LOGIN (WITH FINGERPRINT)
  // ─────────────────────────────────────────────
  Future<String> login(String email, String password) async {
    try {

      // 🔹 Validation
      if (email.isEmpty || password.isEmpty) {
        return "Please enter email and password";
      }

      // 🔹 Firebase Login
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // 🔐 Fingerprint Authentication
      bool auth = await BiometricService().authenticate();

      if (!auth) {
        await _auth.signOut();
        return "Fingerprint authentication failed";
      }

      return "success";

    } on FirebaseAuthException catch (e) {

      if (e.code == 'user-not-found') {
        return "User not found";
      } else if (e.code == 'wrong-password') {
        return "Wrong password";
      } else if (e.code == 'invalid-email') {
        return "Invalid email";
      }

      return "Login failed";

    } catch (e) {
      return "Something went wrong";
    }
  }

  // ─────────────────────────────────────────────
  // ✅ LOGOUT
  // ─────────────────────────────────────────────
  Future<void> logout() async {
    await _auth.signOut();
  }
}