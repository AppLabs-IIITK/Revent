import * as functions from 'firebase-functions/v1';
// import * as admin from 'firebase-admin'; // Admin not used directly here

import { createLogEntry, scheduleEventNotifications } from './utils';

// Log all writes to events collection
export const logEventChanges = functions
  .region('asia-south1')
  .firestore
  .document('events/{eventId}')
  .onWrite(async (change: functions.Change<functions.firestore.DocumentSnapshot>, context: functions.EventContext) => {
    const eventId = context.params.eventId;
    const beforeData = change.before.exists ? change.before.data() : null;
    const afterData = change.after.exists ? change.after.data() : null;

    // Determine operation type
    let operation = 'unknown';
    if (!beforeData && afterData) operation = 'create_event';
    else if (beforeData && afterData) operation = 'update_event';
    else if (beforeData && !afterData) operation = 'delete_event';

    // Schedule notifications if event is created or startTime changed
    if (afterData && (!beforeData || beforeData.startTime !== afterData.startTime)) {
      // Run asynchronously to not block log creation
      setImmediate(async () => {
        try {
          await scheduleEventNotifications(eventId, afterData);
        } catch (error) {
          console.error('Error scheduling event notifications:', error);
        }
      });
    }

    // Create log entry
    return createLogEntry({
      collection: 'events',
      documentId: eventId,
      operation,
      beforeData,
      afterData,
      context
    });
  });

