import * as functions from 'firebase-functions/v1';

import { createLogEntry } from './utils';

// Log all writes to mapMarkers collection
export const logMapMarkerChanges = functions
  .region('asia-south1')
  .firestore
  .document('mapMarkers/{markerId}')
  .onWrite(async (change: functions.Change<functions.firestore.DocumentSnapshot>, context: functions.EventContext) => {
    const markerId = context.params.markerId;
    const beforeData = change.before.exists ? change.before.data() : null;
    const afterData = change.after.exists ? change.after.data() : null;

    // Determine operation type
    let operation = 'unknown';
    if (!beforeData && afterData) operation = 'create_map_marker';
    else if (beforeData && afterData) operation = 'update_map_marker';
    else if (beforeData && !afterData) operation = 'delete_map_marker';

    // Create log entry
    return createLogEntry({
      collection: 'mapMarkers',
      documentId: markerId,
      operation,
      beforeData,
      afterData,
      context
    });
  });

