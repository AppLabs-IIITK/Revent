import * as functions from 'firebase-functions/v1';

import { createLogEntry } from './utils';

// Log all writes to clubs collection
export const logClubChanges = functions
  .region('asia-south1')
  .firestore
  .document('clubs/{clubId}')
  .onWrite(async (change: functions.Change<functions.firestore.DocumentSnapshot>, context: functions.EventContext) => {
    const clubId = context.params.clubId;
    const beforeData = change.before.exists ? change.before.data() : null;
    const afterData = change.after.exists ? change.after.data() : null;

    // Determine operation type
    let operation = 'unknown';
    if (!beforeData && afterData) operation = 'create_club';
    else if (beforeData && afterData) {
      // Check if admin emails were updated
      if (JSON.stringify(beforeData.adminEmails) !== JSON.stringify(afterData.adminEmails)) {
        operation = 'update_club_admins';
      }
      // Check if logo was updated
      else if (beforeData.logoUrl !== afterData.logoUrl) {
        operation = 'update_club_logo';
      }
      // Check if background was updated
      else if (beforeData.backgroundImageUrl !== afterData.backgroundImageUrl) {
        operation = 'update_club_background';
      }
      // General update
      else {
        operation = 'update_club';
      }
    }
    else if (beforeData && !afterData) operation = 'delete_club';

    // Create log entry
    return createLogEntry({
      collection: 'clubs',
      documentId: clubId,
      operation,
      beforeData,
      afterData,
      context
    });
  });

