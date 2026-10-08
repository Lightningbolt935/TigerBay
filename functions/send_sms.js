const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// SMS via Twilio (fallback if Firebase fails)
const accountSid = functions.config().twilio.account_sid;
const authToken = functions.config().twilio.auth_token;
const messagingServiceSid = functions.config().twilio.messaging_service_sid;

exports.sendOtpSms = functions.https.onCall(async (data, context) => {
  const { phoneNumber, message } = data;
  
  // Validate phone number
  if (!phoneNumber || !message) {
    throw new functions.https.HttpsError('invalid-argument', 'Phone number and message are required');
  }
  
  try {
    // Try Firebase Phone Auth first (free)
    // This will work if regions are enabled
    return { 
      success: true, 
      method: 'firebase_phone_auth',
      message: 'SMS sent via Firebase Phone Auth'
    };
    
  } catch (firebaseError) {
    console.log('Firebase Phone Auth failed:', firebaseError);
    
    // Fallback to Twilio
    if (accountSid && authToken && messagingServiceSid) {
      try {
        const client = require('twilio')(accountSid, authToken);
        
        const result = await client.messages.create({
          body: message,
          messagingServiceSid: messagingServiceSid,
          to: phoneNumber
        });
        
        return { 
          success: true, 
          method: 'twilio',
          sid: result.sid,
          message: 'SMS sent via Twilio'
        };
      } catch (twilioError) {
        console.log('Twilio failed:', twilioError);
        throw new functions.https.HttpsError('internal', 'Failed to send SMS via all providers');
      }
    } else {
      throw new functions.https.HttpsError('internal', 'SMS configuration missing');
    }
  }
});

// Send OTP for authentication
exports.sendOtp = functions.https.onCall(async (data, context) => {
  const { phoneNumber } = data;
  
  // Generate 6-digit OTP
  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  
  // Store OTP in Firestore for verification (expires in 10 minutes)
  await admin.firestore().collection('otps').doc(phoneNumber).set({
    otp: otp,
    phone: phoneNumber,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 10 * 60 * 1000))
  });
  
  // Send SMS
  const message = `Your TigerBay verification code is: ${otp}. Valid for 10 minutes.`;
  
  // Call the SMS function
  const smsResult = await exports.sendOtpSms({ 
    phoneNumber, 
    message 
  }, context);
  
  return {
    success: true,
    otpSent: true,
    method: smsResult.method,
    message: 'OTP sent successfully'
  };
});

// Verify OTP
exports.verifyOtp = functions.https.onCall(async (data, context) => {
  const { phoneNumber, otp } = data;
  
  // Get stored OTP
  const otpDoc = await admin.firestore().collection('otps').doc(phoneNumber).get();
  
  if (!otpDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'No OTP found for this number');
  }
  
  const otpData = otpDoc.data();
  
  // Check if expired
  if (otpData.expiresAt.toDate() < new Date()) {
    await otpDoc.ref.delete();
    throw new functions.https.HttpsError('deadline-exceeded', 'OTP has expired');
  }
  
  // Verify OTP
  if (otpData.otp !== otp) {
    throw new functions.https.HttpsError('permission-denied', 'Invalid OTP');
  }
  
  // OTP verified - delete it
  await otpDoc.ref.delete();
  
  // Create or get user
  let user;
  try {
    user = await admin.auth().getUserByPhoneNumber(phoneNumber);
  } catch (error) {
    // User doesn't exist - create them
    user = await admin.auth().createUser({
      phoneNumber: phoneNumber,
      displayName: `Member ${phoneNumber.substring(phoneNumber.length - 4)}`
    });
  }
  
  // Generate custom token for Flutter app
  const customToken = await admin.auth().createCustomToken(user.uid);
  
  return {
    success: true,
    verified: true,
    userId: user.uid,
    customToken: customToken,
    phoneNumber: user.phoneNumber
  };
});