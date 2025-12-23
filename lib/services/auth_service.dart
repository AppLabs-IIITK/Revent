import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class AuthService {
  final GoogleSignIn googleSignIn = GoogleSignIn(
    clientId:
        '271665798346-bqalgst3gesb4979nacjplai064dpusf.apps.googleusercontent.com',
  );

  // API endpoint for auth
  static const String _authEndpoint =
      'https://asia-south1-event-manager-dfd26.cloudfunctions.net/api/auth/google';

  /// Sign in with Google
  /// Returns the GoogleSignInAccount if successful, null if cancelled
  /// Returns the account but throws if domain is not allowed
  Future<GoogleSignInAccount?> signInWithGoogle() async {
    // Sign in with Google (user interaction)
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

    if (googleUser == null) {
      // User canceled the sign-in
      return null;
    }

    // Get the Google ID token
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    // Call server to verify token, create/update user, and get custom Firebase token
    final response = await http.post(
      Uri.parse(_authEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': googleAuth.idToken}),
    );

    if (response.statusCode == 403) {
      // User is not from the IIIT Kottayam domain
      await googleSignIn.signOut();
      return googleUser; // Return user so UI can show domain error
    }

    if (response.statusCode != 200) {
      await googleSignIn.signOut();
      throw Exception('Authentication failed: ${response.body}');
    }

    final responseData = jsonDecode(response.body);
    final customToken = responseData['customToken'] as String;

    // Sign in to Firebase with the custom token
    await FirebaseAuth.instance.signInWithCustomToken(customToken);

    return googleUser;
  }

  /// Sign out from both Firebase and Google
  Future<void> signOut() async {
    await Future.wait([
      FirebaseAuth.instance.signOut(),
      googleSignIn.signOut(),
    ]);
  }
}
