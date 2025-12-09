import * as functions from 'firebase-functions/v1';

import { createLogEntry } from './utils';

// Remove sensitive data from user objects before logging
function sanitizeUserData(userData: any): any {
  // Create a copy to avoid modifying the original
  const sanitized = {...userData};

  // Remove any sensitive fields you don't want to log
  delete sanitized.authProviders;
  delete sanitized.phoneNumber;

  return sanitized;
}

// Log all writes to users collection
export const logUserChanges = functions
  .region('asia-south1')
  .firestore
  .document('users/{userId}')
  .onWrite(async (change: functions.Change<functions.firestore.DocumentSnapshot>, context: functions.EventContext) => {
    const userId = context.params.userId;
    const beforeData = change.before.exists ? change.before.data() : null;
    const afterData = change.after.exists ? change.after.data() : null;

    // Determine operation type
    let operation = 'unknown';
    if (!beforeData && afterData) operation = 'create_user';
    else if (beforeData && afterData) {
      // Check if profile photo was updated
      if (beforeData.photoURL !== afterData.photoURL) {
        operation = 'update_user_photo';
      }
      // Check if background was updated
      else if (beforeData.backgroundImageUrl !== afterData.backgroundImageUrl) {
        operation = 'update_user_background';
      }
      // General update
      else {
        operation = 'update_user';
      }
    }
    else if (beforeData && !afterData) operation = 'delete_user';

    // Create log entry with sensitive data removed
    const sanitizedBeforeData = beforeData ? sanitizeUserData(beforeData) : null;
    const sanitizedAfterData = afterData ? sanitizeUserData(afterData) : null;

    return createLogEntry({
      collection: 'users',
      documentId: userId,
      operation,
      beforeData: sanitizedBeforeData,
      afterData: sanitizedAfterData,
      context
    });
  });
