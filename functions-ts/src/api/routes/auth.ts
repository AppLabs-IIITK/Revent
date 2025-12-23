import express from 'express';
import * as admin from 'firebase-admin';
import { OAuth2Client } from 'google-auth-library';

const router = express.Router();

// Google Client ID for verification
const GOOGLE_CLIENT_ID = '271665798346-bqalgst3gesb4979nacjplai064dpusf.apps.googleusercontent.com';

// Initialize Google Auth Client
const googleClient = new OAuth2Client(GOOGLE_CLIENT_ID);

interface GoogleAuthRequest {
  idToken: string;
}

interface UserData {
  uid: string;
  email: string;
  name: string | null;
  photoURL: string | null;
  rollNumber: string | null;
  createdAt: admin.firestore.FieldValue | admin.firestore.Timestamp;
  lastLogin: admin.firestore.FieldValue;
}

interface AuthResponse {
  customToken: string;
  user: {
    uid: string;
    email: string;
    name?: string;
    photoURL?: string;
    rollNumber?: string;
    isNewUser: boolean;
  };
}

/**
 * Extract roll number from IIIT Kottayam email
 * Format: 25bcs001@iiitkottayam.ac.in -> 2025BCS0001
 */
function extractRollNumber(email: string): string | null {
  if (!email.endsWith('iiitkottayam.ac.in')) {
    return null;
  }

  const emailParts = email.split('@')[0];
  const regExp = /(\d+)([a-zA-Z]+)(\d+)/;
  const match = regExp.exec(emailParts);

  if (match) {
    const year = match[1];
    const branch = match[2].toUpperCase();
    const number = match[3].padStart(4, '0');
    return `20${year}${branch}${number}`;
  }

  return null;
}

/**
 * Verify Google ID token and extract user information
 */
async function verifyGoogleIdToken(idToken: string) {
  const ticket = await googleClient.verifyIdToken({
    idToken,
    audience: GOOGLE_CLIENT_ID,
  });

  const payload = ticket.getPayload();
  if (!payload) {
    throw new Error('Invalid token payload');
  }

  return {
    email: payload.email!,
    emailVerified: payload.email_verified || false,
    name: payload.name,
    picture: payload.picture,
  };
}

/**
 * POST /auth/google
 *
 * Accepts a Google ID token, verifies it, creates/updates user in Firestore,
 * and returns a custom Firebase token.
 */
router.post('/google', async (req, res) => {
  try {
    const { idToken }: GoogleAuthRequest = req.body;

    // Validate request
    if (!idToken) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'idToken is required',
      });
      return;
    }

    // Verify the Google ID token
    let googleData;
    try {
      googleData = await verifyGoogleIdToken(idToken);
    } catch (error) {
      console.error('Failed to verify Google ID token:', error);
      res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid Google ID token',
      });
      return;
    }

    // Validate email is verified
    if (!googleData.emailVerified) {
      res.status(401).json({
        error: 'Unauthorized',
        message: 'Email not verified',
      });
      return;
    }

    // Validate email domain (IIIT Kottayam or whitelisted)
    const email = googleData.email;
    const isIIITKEmail = email.endsWith('iiitkottayam.ac.in');
    const isWhitelisted = email === 'kssakhilraj@gmail.com';

    if (!isIIITKEmail && !isWhitelisted) {
      res.status(403).json({
        error: 'Forbidden',
        message: 'Only IIIT Kottayam email addresses are allowed',
        email,
      });
      return;
    }

    // Extract roll number for IIIT Kottayam emails
    const rollNumber = extractRollNumber(email);

    // Run Firebase Auth and Firestore operations in parallel for speed
    const [firebaseUser, firestoreResult] = await Promise.all([
      // Get or create Firebase Auth user
      (async () => {
        try {
          return await admin.auth().getUserByEmail(email);
        } catch (error: any) {
          if (error.code === 'auth/user-not-found') {
            return await admin.auth().createUser({
              email,
              emailVerified: true,
              displayName: googleData.name,
              photoURL: googleData.picture,
            });
          }
          throw error;
        }
      })(),

      // Create or update Firestore user document
      (async () => {
        const userDoc = admin.firestore().collection('users').doc(email.split('@')[0]);
        const docSnapshot = await userDoc.get();

        const isNewUser = !docSnapshot.exists;

        if (isNewUser) {
          // Create new user document
          const userData: UserData = {
            uid: '', // Will be updated after we get the Firebase user
            email,
            name: googleData.name || null,
            photoURL: googleData.picture || null,
            rollNumber,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            lastLogin: admin.firestore.FieldValue.serverTimestamp(),
          };
          await userDoc.set(userData);
        } else {
          // Update lastLogin for existing user
          await userDoc.update({
            lastLogin: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        return { isNewUser, docRef: userDoc };
      })(),
    ]);

    // Update the Firestore document with the correct UID if it's a new user
    if (firestoreResult.isNewUser) {
      await firestoreResult.docRef.update({ uid: firebaseUser.uid });
    }

    // Generate custom Firebase token
    const customToken = await admin.auth().createCustomToken(firebaseUser.uid);

    // Return the custom token and user info
    const response: AuthResponse = {
      customToken,
      user: {
        uid: firebaseUser.uid,
        email,
        name: googleData.name,
        photoURL: googleData.picture,
        rollNumber: rollNumber || undefined,
        isNewUser: firestoreResult.isNewUser,
      },
    };

    console.log(`User authenticated: ${email} (${firebaseUser.uid}) - ${firestoreResult.isNewUser ? 'NEW' : 'EXISTING'}`);
    res.status(200).json(response);
  } catch (error: any) {
    console.error('Error in Google auth:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: error.message || 'Failed to authenticate',
    });
  }
});

export { router as authRouter };
