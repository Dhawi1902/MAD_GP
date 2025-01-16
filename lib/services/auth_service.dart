import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = userCredential.user;

      if (user != null) {
        // Save user details to Firestore
        await _db.collection('users').doc(user.uid).set({
          'email': email,
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('User ${user.uid} registered and saved to Firestore.');
      }

      return user;

      
    } catch (e) {
      print('Sign-in error: $e');
      throw e;
    }
  }

  Future<void> register(String email, String password) async {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    String userId = userCredential.user!.uid;

    // Ensure personal project exists for the new user
    await FirestoreService().ensurePersonalProjectExists(userId);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}
