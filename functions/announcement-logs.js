const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { createLogEntry, sendEmail } = require('./utils');

// Helper function for sending emails with retry logic
async function sendWithRetry(email, subject, html, retryCount = 0, maxRetries = 3) {
  try {
    console.log(`Attempt ${retryCount + 1}/${maxRetries + 1} to send email to: ${email}`);
    const result = await sendEmail(email, subject, html);
    console.log(`Email sent successfully to ${email} on attempt ${retryCount + 1}`);
    return result;
  } catch (error) {
    // Log detailed error information
    console.error(`Attempt ${retryCount + 1}/${maxRetries + 1} failed for ${email}:`, {
      message: error.message,
      code: error.code,
      response: error.response,
      stack: error.stack ? error.stack.split('\n').slice(0, 3).join('\n') : null
    });

    // Check if we've exceeded the maximum number of retries
    if (retryCount >= maxRetries) {
      console.error(`Exceeded maximum retries (${maxRetries}) for ${email}`);
      // We've exceeded max retries, so rethrow the error
      throw error;
    }

    // Exponential backoff
    const delay = 1000 * Math.pow(2, retryCount);
    console.log(`Waiting ${delay}ms before retry ${retryCount + 2} for ${email}`);
    await new Promise(resolve => setTimeout(resolve, delay));
    return sendWithRetry(email, subject, html, retryCount + 1, maxRetries);
  }
}

// Log all writes to announcements collection
exports.logAnnouncementChanges = functions
  .region('asia-south1')
  .firestore
  .document('announcements/{clubId}')
  .onWrite(async (change, context) => {
    const clubId = context.params.clubId;
    const beforeData = change.before.exists ? change.before.data() : null;
    const afterData = change.after.exists ? change.after.data() : null;

    // Determine operation type
    let operation = 'unknown';
    if (!beforeData && afterData) {
      operation = 'create_club_announcements';
    } else if (beforeData && afterData) {
      const beforeList = beforeData && beforeData.announcementsList ? beforeData.announcementsList : [];
      const afterList = afterData && afterData.announcementsList ? afterData.announcementsList : [];

      if (afterList.length > beforeList.length) {
        operation = 'add_announcement';

        // Get the new announcement (it's at the start of the list)
        const newAnnouncement = afterList[0];

        try {
          // Get club name
          const clubDoc = await admin.firestore().collection('clubs').doc(clubId).get();
          const clubName = clubDoc.exists ? clubDoc.data().name : 'Unknown Club';

          // Get all users with active sessions
          const listUsersResult = await admin.auth().listUsers();
          const activeUsers = listUsersResult.users.filter(user =>
            user.emailVerified && !user.disabled
          );
          const userEmails = activeUsers
            .map(user => user.email)
            .filter(email => email); // Filter out any undefined/null emails

          console.log(`Sending emails to ${userEmails.length} users`);

          // Prepare email content
          const subject = `New Announcement from ${clubName}`;
          const html = `
            <div style="font-family: Arial, sans-serif; max-width: 600px;">
              <p style="font-size: 16px; margin-bottom: 8px;">Hey there! 👋</p>
              <p style="font-size: 16px; margin-bottom: 8px;">${clubName} just posted a new announcement:</p>
              <p style="font-size: 16px; margin-bottom: 16px;">${newAnnouncement.title}</p>
              <p style="margin-bottom: 24px;">
                <a href="https://event-manager-dfd26.web.app/app"
                   style="background-color: #4285f4; color: white; padding: 10px 20px;
                          text-decoration: none; border-radius: 4px; display: inline-block;">
                  Check it out
                </a>
              </p>
              <p style="color: #666; font-size: 12px; margin-top: 24px;">Sent by Revent</p>
            </div>
          `;

          // Send emails in batches of 20 to avoid rate limits
          const batchSize = 20;
          const failedEmails = [];
          const maxRetries = 10;

          for (let i = 0; i < userEmails.length; i += batchSize) {
            const end = Math.min(i + batchSize, userEmails.length);
            const batch = userEmails.slice(i, end);
            const results = await Promise.allSettled(
              batch.map(email => sendWithRetry(email, subject, html, 0, maxRetries))
            );

            // Track any failed sends
            results.forEach((result, index) => {
              if (result.status === 'rejected') {
                failedEmails.push({
                  email: batch[index],
                  error: result.reason,
                  retryCount: maxRetries
                });
              }
            });

            // Add a longer delay between batches to prevent rate limiting
            if (i + batchSize < userEmails.length) {
              await new Promise(resolve => setTimeout(resolve, 10000)); // 10 second delay between batches
            }
          }

          // Log any failures
          if (failedEmails.length > 0) {
            console.error('Failed to send some announcement emails:', {
              totalFailed: failedEmails.length,
              failures: failedEmails
            });
          }
        } catch (error) {
          console.error('Error sending announcement emails:', error);
        }
      } else if (afterList.length < beforeList.length) {
        operation = 'delete_announcement';
      } else {
        operation = 'update_announcement';
      }
    } else if (beforeData && !afterData) {
      operation = 'delete_club_announcements';
    }
    // Create log entry
    return createLogEntry({
      collection: 'announcements',
      documentId: clubId,
      operation,
      beforeData,
      afterData,
      context
    });
  });