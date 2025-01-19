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
        print('User ${user.uid} signed in successfully.');
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

  Future<void> registerWithUsername(String email, String password, String username) async {
    // Check if username exists
    final existingUser = await _db
        .collection('users')
        .where('username', isEqualTo: username)
        .get();

    if (existingUser.docs.isNotEmpty) {
      throw Exception('Username is already taken.');
    }

    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    String userId = userCredential.user!.uid;

    // Store user details in Firestore
    await _db.collection('users').doc(userId).set({
      'username': username,
      'email': email,
      'uid': userId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Ensure personal project exists for the new user
    await FirestoreService().ensurePersonalProjectExists(userId);
  }


}
