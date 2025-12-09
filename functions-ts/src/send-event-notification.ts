import * as functions from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';

/**
 * HTTP endpoint for sending event notifications
 * Called by Cloud Tasks at scheduled times
 *
 * Request body:
 * {
 *   eventId: string,
 *   type: 'BEFORE' | 'START'
 * }
 */
export const sendEventNotification = functions.onRequest(
  { region: 'asia-south1' },
  async (req, res) => {
    try {
      const { eventId, type } = req.body;

      if (!eventId || !type) {
        res.status(400).send('Missing eventId or type');
        return;
      }

      // Get event data
      const eventSnap = await admin.firestore().doc(`events/${eventId}`).get();

      if (!eventSnap.exists) {
        res.status(404).send('Event not found');
        return;
      }

      const event = eventSnap.data();
      if (!event) {
        res.status(404).send('Event data is null');
        return;
      }

      // Prepare notification message
      const title = event.title || 'Event Reminder';
      const body = type === 'BEFORE'
        ? `${event.title} starts in 30 minutes at ${event.venue || 'the venue'}`
        : `${event.title} is starting now at ${event.venue || 'the venue'}!`;

      // Send to 'general' topic
      await admin.messaging().send({
        topic: 'general',
        notification: {
          title,
          body,
        },
        data: {
          type: 'event',
          eventId,
          notificationType: type,
          clubId: event.clubId || '',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'general_channel',
            priority: 'high',
          },
        },
        apns: {
          payload: {
            aps: {
              contentAvailable: true,
            },
          },
        },
      });

      console.log(`Event notification sent: ${type} for ${eventId}`);
      res.status(200).send('Notification sent');
    } catch (error) {
      console.error('Error sending event notification:', error);
      res.status(500).send('Internal server error');
    }
  }
);
