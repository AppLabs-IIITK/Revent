import * as admin from 'firebase-admin';
import { EventContext } from 'firebase-functions/v1';
import { CloudTasksClient } from '@google-cloud/tasks';

// Initialize Cloud Tasks client
const tasksClient = new CloudTasksClient();
const project = process.env.GCLOUD_PROJECT || 'event-manager-dfd26';
const location = 'asia-south1';
const queue = 'event-notifications';


interface LogEntryParams {
  collection: string;
  documentId: string;
  operation: string;
  beforeData: any;
  afterData: any;
  context: EventContext;
}


// Helper function to create a log entry
export const createLogEntry = async ({
  collection,
  documentId,
  operation,
  beforeData,
  afterData,
  context
}: LogEntryParams) => {
  try {
    // Get user info from auth context or metadata
    let userId = 'system';
    let userEmail = 'system';

    // Try to get user from auth context
    if (context.auth) {
      userId = context.auth.uid;
      if (context.auth.token && context.auth.token.email) {
          userEmail = context.auth.token.email;
      }
    }
    // For delete operations, check for delete metadata in beforeData
    else if (operation.startsWith('delete_') && beforeData && beforeData._deleteMetadata) {
      const metadata = beforeData._deleteMetadata;
      if (metadata.userId) userId = metadata.userId;
      if (metadata.userEmail) userEmail = metadata.userEmail;

      // Remove delete metadata from the logged data to keep it clean
      delete beforeData._deleteMetadata;
    }
    // If not available, try to get from metadata in the document
    else if (afterData && afterData._metadata) {
      const metadata = afterData._metadata;
      if (metadata.userId) userId = metadata.userId;
      if (metadata.userEmail) userEmail = metadata.userEmail;

      // Remove metadata from the logged data to keep it clean
      delete afterData._metadata;
    }

    // Create log entry
    const logEntry = {
      collection,
      documentId,
      operation,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      userId,
      userEmail,
      beforeData,
      afterData
    };

    // Add to admin_logs collection
    return admin.firestore().collection('admin_logs').add(logEntry);
  } catch (error) {
    console.error('Error creating log entry:', error);
    // Don't throw - we don't want to interrupt the main operation
    return null;
  }
};

/**
 * Schedule event notifications using Cloud Tasks
 * Creates two tasks:
 * 1. 30 minutes before event start
 * 2. At event start time
 *
 * Uses deterministic task names to prevent duplicates when event is updated
 */
export const scheduleEventNotifications = async (eventId: string, eventData: any) => {
  try {
    const startTime = eventData.startTime;
    if (!startTime || !startTime.toDate) {
      console.log('Invalid startTime, skipping notification scheduling');
      return;
    }

    const startDate = startTime.toDate();
    const now = new Date();

    // Calculate notification times
    const beforeTime = new Date(startDate.getTime() - 30 * 60 * 1000); // 30 minutes before
    const startTimeExact = startDate;

    const parent = tasksClient.queuePath(project, location, queue);
    const url = `https://${location}-${project}.cloudfunctions.net/sendEventNotification`;

    // Schedule "30 minutes before" notification
    if (beforeTime > now) {
      // Use deterministic task name to prevent duplicates
      const taskName = `${parent}/tasks/${eventId}-before`;

      const beforeTask = {
        name: taskName,
        httpRequest: {
          httpMethod: 'POST' as const,
          url,
          headers: {
            'Content-Type': 'application/json',
          },
          body: Buffer.from(JSON.stringify({
            eventId,
            type: 'BEFORE',
          })).toString('base64'),
        },
        scheduleTime: {
          seconds: Math.floor(beforeTime.getTime() / 1000),
        },
      };

      try {
        await tasksClient.createTask({ parent, task: beforeTask });
        console.log(`Scheduled BEFORE notification for event ${eventId} at ${beforeTime}`);
      } catch (error: any) {
        // If task already exists, delete and recreate it
        if (error.code === 6) { // ALREADY_EXISTS
          try {
            await tasksClient.deleteTask({ name: taskName });
            await tasksClient.createTask({ parent, task: beforeTask });
            console.log(`Rescheduled BEFORE notification for event ${eventId} at ${beforeTime}`);
          } catch (retryError) {
            console.error('Error rescheduling BEFORE task:', retryError);
          }
        } else {
          throw error;
        }
      }
    }

    // Schedule "at start time" notification
    if (startTimeExact > now) {
      // Use deterministic task name to prevent duplicates
      const taskName = `${parent}/tasks/${eventId}-start`;

      const startTask = {
        name: taskName,
        httpRequest: {
          httpMethod: 'POST' as const,
          url,
          headers: {
            'Content-Type': 'application/json',
          },
          body: Buffer.from(JSON.stringify({
            eventId,
            type: 'START',
          })).toString('base64'),
        },
        scheduleTime: {
          seconds: Math.floor(startTimeExact.getTime() / 1000),
        },
      };

      try {
        await tasksClient.createTask({ parent, task: startTask });
        console.log(`Scheduled START notification for event ${eventId} at ${startTimeExact}`);
      } catch (error: any) {
        // If task already exists, delete and recreate it
        if (error.code === 6) { // ALREADY_EXISTS
          try {
            await tasksClient.deleteTask({ name: taskName });
            await tasksClient.createTask({ parent, task: startTask });
            console.log(`Rescheduled START notification for event ${eventId} at ${startTimeExact}`);
          } catch (retryError) {
            console.error('Error rescheduling START task:', retryError);
          }
        } else {
          throw error;
        }
      }
    }
  } catch (error) {
    console.error('Error scheduling event notifications:', error);
    // Don't throw - we don't want to interrupt the main operation
  }
};
