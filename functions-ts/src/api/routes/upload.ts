import express from 'express';
import * as admin from 'firebase-admin';
import { v4 as uuidv4 } from 'uuid';
import { verifyFirebaseToken, AuthenticatedRequest } from '../middleware/auth';

const router = express.Router();

interface SignedUrlRequest {
  filePath: string;
  contentType: string;
}

interface SignedUrlResponse {
  signedUrl: string;
  publicUrl: string;
  token: string;
}

// Fixed expiration time: 5 minutes
const SIGNED_URL_EXPIRATION_SECONDS = 300;

async function generateSignedUploadUrl(
  filePath: string,
  contentType: string
): Promise<SignedUrlResponse> {
  const token = uuidv4();
  console.log('Generated token for upload:', token);

  const bucket = admin.storage().bucket();
  const file = bucket.file(filePath);

  const [signedUrl] = await file.getSignedUrl({
    version: 'v4',
    action: 'write',
    expires: Date.now() + SIGNED_URL_EXPIRATION_SECONDS * 1000,
    contentType,
    extensionHeaders: {
      'x-goog-meta-firebaseStorageDownloadTokens': token,
    },
  });

  const encodedPath = encodeURIComponent(filePath);
  const publicUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodedPath}?alt=media&token=${token}`;

  return {
    signedUrl,
    publicUrl,
    token,
  };
}

router.post('/signed-url', verifyFirebaseToken, async (req: AuthenticatedRequest, res) => {
  try {
    const { filePath, contentType }: SignedUrlRequest = req.body;

    // Log authenticated user
    console.log('Authenticated user:', req.user?.uid, req.user?.email);

    // Validation
    if (!filePath || !contentType) {
      res.status(400).json({
        error: 'Missing required fields',
        message: 'filePath and contentType are required',
      });
      return;
    }

    // Generate signed URL
    const result = await generateSignedUploadUrl(filePath, contentType);

    res.status(200).json(result);
  } catch (error: any) {
    console.error('Error generating signed upload URL:', error);
    res.status(500).json({
      error: 'Failed to generate signed upload URL',
      message: error.message,
    });
  }
});

export { router as uploadRouter };
