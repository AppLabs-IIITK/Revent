import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final GoogleSignIn googleSignIn = GoogleSignIn(
    clientId:
        '271665798346-bqalgst3gesb4979nacjplai064dpusf.apps.googleusercontent.com',
  );
  Future<GoogleSignInAccount?> signInWithGoogle() async {
    // Sign in and force the user to select an account
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

    if (googleUser == null) {
      // User canceled the sign-in, return null
      return null;
    }
    if (!googleUser.email.endsWith("iiitkottayam.ac.in") &&
        !googleUser.email.endsWith("kssakhilraj@gmail.com")) {
      // User is not from the IIIT Kottayam domain, return null
      await googleSignIn.signOut();
      return googleUser;
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Sign in to Firebase with the Google credentials
    final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

    // Extract roll number from email if it's an IIIT Kottayam email
    String? rollNumber;
    if (googleUser.email.endsWith('iiitkottayam.ac.in')) {
      final emailParts = googleUser.email.split('@')[0];
      final regExp = RegExp(r'(\d+)([a-zA-Z]+)(\d+)');
      final match = regExp.firstMatch(emailParts);
      if (match != null) {
        final year = match.group(1)!;
        final branch = match.group(2)!.toUpperCase();
        final number = match.group(3)!.padLeft(4, '0');
        rollNumber = '20$year$branch$number';
      }
    }
    await createOrUpdateUser(userCredential, googleUser, rollNumber);
    // Return the signed-in user
    return googleUser;
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await googleSignIn.signOut();
  }

  Future<void> createOrUpdateUser(UserCredential userCredential, GoogleSignInAccount googleUser, String? rollNumber) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid);

    // Check if document exists
    final docSnapshot = await userDoc.get();
    if (!docSnapshot.exists) {
      // Create new document if it doesn't exist
      await userDoc.set({
        'uid': userCredential.user!.uid,
        'name': googleUser.displayName,
        'email': googleUser.email,
        'photoURL': googleUser.photoUrl,
        'rollNumber': rollNumber,
        'createdAt': DateTime.now(),
        'lastLogin': DateTime.now(),
      });
    } else {
      // Update lastLogin for existing user
      await userDoc.update({
        'lastLogin': DateTime.now(),
      });
    }
  }
}
