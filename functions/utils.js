const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
const functions = require('firebase-functions');

// Initialize nodemailer with SMTP config
const transporter = nodemailer.createTransport({
  service: 'gmail',  // Using built-in Gmail config
  auth: {
    user: functions.config().smtp.user,
    pass: functions.config().smtp.pass,
  },
  tls: {
    minVersion: 'TLSv1.2',
    rejectUnauthorized: true
  }
});

// Helper function to send email
exports.sendEmail = async function(to, subject, html) {
  console.log('Attempting to send email to:', to);
  console.log('SMTP Config:', {
    host: functions.config().smtp.host,
    port: functions.config().smtp.port,
    user: functions.config().smtp.user,
    // Don't log the actual password
    hasPass: !!functions.config().smtp.pass
  });

  const mailOptions = {
    from: `Revent <${functions.config().smtp.user}>`,
    to,
    subject,
    html
  };

  try {
    console.log('Mail options:', { ...mailOptions, html: 'HTML content hidden for brevity' });
    const result = await transporter.sendMail(mailOptions);
    console.log('Email sent successfully:', result);
    return result; // Return the full result object for more detailed logging
  } catch (error) {
    console.error('Detailed email error:', {
      code: error.code,
      message: error.message,
      response: error.response,
      stack: error.stack
    });
    // Throw the error instead of returning false so that retry logic works
    throw error;
  }
};

// Helper function to create a log entry
exports.createLogEntry = async function({
  collection,
  documentId,
  operation,
  beforeData,
  afterData,
  context
}) {
  try {
    // Get user info from auth context or metadata
    let userId = 'system';
    let userEmail = 'system';

    // Try to get user from auth context
    if (context.auth) {
      userId = context.auth.uid;
      userEmail = context.auth.token.email;
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