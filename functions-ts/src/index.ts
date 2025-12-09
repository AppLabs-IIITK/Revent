
import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions/v2/https';
import { app } from './api/index.js';

// Initialize Firebase Admin SDK
admin.initializeApp();

// V1 Functions - Firestore triggers
export * from './event-logs';
export * from './club-logs';
export * from './user-logs';
export * from './map-marker-logs';
export * from './announcement-logs';

// V2 Functions - HTTP endpoints
export const api = functions.onRequest(
  {
    region: 'asia-south1',
    cors: true,
  },
  app
);

// Event notification endpoint (called by Cloud Tasks)
export * from './send-event-notification';
