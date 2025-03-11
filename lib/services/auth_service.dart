import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Helper method to handle auth errors with user-friendly messages
  String _handleAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect username or password';
        case 'email-already-in-use':
          return 'An account already exists with this email';
        case 'weak-password':
          return 'Password is too weak';
        case 'requires-recent-login':
          return 'Please sign out and sign in again before this operation';
        default:
          return 'Authentication failed. Please try again.';
      }
    }
    return 'An error occurred. Please try again.';
  }

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Error signing in: $e');
      throw _handleAuthError(e);
    }
  }

  // Create user with email and password
  Future<UserCredential> createUserWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Create initial user document in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });
      
      return userCredential;
    } catch (e) {
      print('Error creating user: $e');
      throw _handleAuthError(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      throw 'Failed to sign out. Please try again.';
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Error sending password reset email: $e');
      if (e is FirebaseAuthException && e.code == 'user-not-found') {
        throw 'If an account exists with this email, a password reset link will be sent.';
      }
      throw 'Failed to send password reset email. Please try again.';
    }
  }

  // Delete account and all associated data
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'No user signed in';

      // Delete user data from Firestore first
      await _deleteUserData(user.uid);

      // Then delete the user account
      await user.delete();
    } catch (e) {
      print('Error deleting account: $e');
      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        throw 'Please sign out and sign in again before deleting your account';
      }
      throw 'Failed to delete account. Please try again.';
    }
  }

  // Helper method to delete user data
  Future<void> _deleteUserData(String userId) async {
    try {
      // Delete all bookmarks
      final bookmarksSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('bookmarks')
          .get();
      
      final batch = _firestore.batch();
      
      // Delete all bookmark documents
      for (var doc in bookmarksSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete the user document itself
      batch.delete(_firestore.collection('users').doc(userId));
      
      // Commit the batch
      await batch.commit();
    } catch (e) {
      print('Error deleting user data: $e');
      throw 'Failed to delete user data. Please try again.';
    }
  }

  // Reauthenticate user (needed for sensitive operations like deletion)
  Future<void> reauthenticateUser(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'No user signed in';

      // Create credentials
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      // Reauthenticate
      await user.reauthenticateWithCredential(credential);
    } catch (e) {
      print('Error reauthenticating: $e');
      throw 'Authentication failed. Please check your password and try again.';
    }
  }
} 