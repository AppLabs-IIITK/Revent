import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { createLogEntry } from './utils';

// Log all writes to announcements collection
export const logAnnouncementChanges = functions
  .region('asia-south1')
  .firestore
  .document('announcements/{clubId}')
  .onWrite(async (change: functions.Change<functions.firestore.DocumentSnapshot>, context: functions.EventContext) => {
    const clubId = context.params.clubId;
    const beforeData = change.before.exists ? change.before.data() : null;
    const afterData = change.after.exists ? change.after.data() : null;

    // Determine operation type and extract only affected announcement
    let operation = 'unknown';
    let optimizedBeforeData: any = null;
    let optimizedAfterData: any = null;

    if (!beforeData && afterData) {
      operation = 'create_club_announcements';
      // For initial creation, log summary only
      const announcementsList = afterData.announcementsList || [];
      optimizedAfterData = {
        clubId,
        totalCount: announcementsList.length,
        summary: 'Created announcements document',
        _metadata: afterData._metadata // Preserve metadata
      };
    } else if (beforeData && afterData) {
      const beforeList = beforeData.announcementsList || [];
      const afterList = afterData.announcementsList || [];

      if (afterList.length > beforeList.length) {
        operation = 'add_announcement';

        // Get the new announcement (it's at the start of the list)
        const newAnnouncement = afterList[0];

        // Log only the new announcement
        optimizedBeforeData = {
          clubId,
          totalCount: beforeList.length
        };
        optimizedAfterData = {
          clubId,
          totalCount: afterList.length,
          index: 0,
          announcement: newAnnouncement,
          _metadata: afterData._metadata // Preserve metadata for user tracking
        };

        // Send FCM notification asynchronously (non-blocking)
        setImmediate(async () => {
          try {
            // Get club name for notification
            const clubDoc = await admin.firestore().collection('clubs').doc(clubId).get();
            const clubName = clubDoc.exists ? clubDoc.data()?.name : 'Unknown Club';

            // Send to 'general' topic - all users subscribed
            await admin.messaging().send({
              topic: 'general',
              notification: {
                title: `New Announcement from ${clubName}`,
                body: newAnnouncement.title,
              },
              data: {
                type: 'announcement',
                clubId: clubId,
                announcementTitle: newAnnouncement.title,
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

            console.log(`Notification sent for announcement: ${newAnnouncement.title}`);
          } catch (error) {
            console.error('Error sending announcement notification:', error);
          }
        });
      } else if (afterList.length < beforeList.length) {
        operation = 'delete_announcement';

        // Find which announcement was deleted by comparing lists
        const deletedAnnouncement = beforeList.find(
          (before: any) => !afterList.some((after: any) =>
            JSON.stringify(before) === JSON.stringify(after)
          )
        );
        const deletedIndex = beforeList.findIndex(
          (before: any) => JSON.stringify(before) === JSON.stringify(deletedAnnouncement)
        );

        optimizedBeforeData = {
          clubId,
          totalCount: beforeList.length,
          index: deletedIndex,
          announcement: deletedAnnouncement,
          _deleteMetadata: beforeData._deleteMetadata // Preserve delete metadata
        };
        optimizedAfterData = {
          clubId,
          totalCount: afterList.length,
          _metadata: afterData._metadata // Preserve metadata
        };
      } else {
        operation = 'update_announcement';

        // Find which announcement was updated
        let updatedIndex = -1;
        let beforeAnnouncement = null;
        let afterAnnouncement = null;

        for (let i = 0; i < beforeList.length; i++) {
          if (JSON.stringify(beforeList[i]) !== JSON.stringify(afterList[i])) {
            updatedIndex = i;
            beforeAnnouncement = beforeList[i];
            afterAnnouncement = afterList[i];
            break;
          }
        }

        optimizedBeforeData = {
          clubId,
          totalCount: beforeList.length,
          index: updatedIndex,
          announcement: beforeAnnouncement
        };
        optimizedAfterData = {
          clubId,
          totalCount: afterList.length,
          index: updatedIndex,
          announcement: afterAnnouncement,
          _metadata: afterData._metadata // Preserve metadata
        };
      }
    } else if (beforeData && !afterData) {
      operation = 'delete_club_announcements';
      const beforeList = beforeData.announcementsList || [];
      optimizedBeforeData = {
        clubId,
        totalCount: beforeList.length,
        summary: 'Deleted entire announcements document',
        _deleteMetadata: beforeData._deleteMetadata // Preserve delete metadata
      };
    }

    // Create log entry with optimized data
    return createLogEntry({
      collection: 'announcements',
      documentId: clubId,
      operation,
      beforeData: optimizedBeforeData,
      afterData: optimizedAfterData,
      context
    });
  });
