const functions = require("firebase-functions");

const admin = require("firebase-admin");

const nodemailer = require("nodemailer");

const cors = require("cors")({ origin: true });



admin.initializeApp();



exports.resetStudentPassword = functions.https.onRequest(async (req, res) => {

  cors(req, res, async () => {

    try {

      // Method check

      if (req.method !== "POST") {

        return res.status(405).send({ error: "Only POST requests are allowed." });

      }



      const idToken = req.headers.authorization?.split("Bearer ")[1];

      if (!idToken) {

        return res.status(401).send({ error: "User must be signed in." });

      }



      // Verify token

      const decodedToken = await admin.auth().verifyIdToken(idToken);

      const callerUid = decodedToken.uid;



      const { studentUid } = req.body;

      if (!studentUid || typeof studentUid !== "string") {

        return res.status(400).send({ error: "Invalid studentUid." });

      }



      // Check if caller is authorized

      const callerDoc = await admin.firestore().collection("Heads").doc(callerUid).get();

      if (!callerDoc.exists) {

        return res.status(403).send({ error: "Permission denied." });

      }



      // Reset password

      const newPassword = "mc@12345";

      await admin.auth().updateUser(studentUid, { password: newPassword });



      console.log(`Password reset for ${studentUid} by ${callerUid}`);

      return res.status(200).send({ success: true, message: "Student password reset successfully." });



    } catch (err) {

      console.error("Error resetting password:", err);

      return res.status(500).send({ error: "Internal server error." });

    }

  });

});



// ==========================



// ✅ 1. FCM Notification Function (Existing)



// ==========================



exports.sendLeaveNotification = functions.https.onRequest(async (req, res) => {



  try {



    const { fcmToken, title, body } = req.body;







    if (!fcmToken || !title || !body) {



      return res.status(400).send("Missing fields");



    }







    const message = {



      notification: { title, body },



      token: fcmToken,



    };







    const response = await admin.messaging().send(message);



    console.log("✅ Notification sent:", response);



    res.status(200).send("Notification sent");



  } catch (error) {



    console.error("❌ Error sending notification:", error);



    res.status(500).send("Internal Error");



  }



});





//Notification2



exports.sendBroadcastNotification = onRequest(async (req, res) => {

  try {

    const { title, body } = req.body;

    if (!title || !body) {

      console.warn("Missing fields:", { title, body });

      return res.status(400).send("Missing fields: title or body");

    }



    const topic = "all_users";



    const message = {

      notification: {

        title: title,

        body: body,

      },

      topic: topic,

    };



    const response = await admin.messaging().send(message);

    console.log("✅ Broadcast notification sent:", response);

    res.status(200).send("Broadcast sent successfully");



  } catch (error) {

    console.error("❌ Error sending broadcast notification:", error);

    res.status(500).send("Internal Server Error: " + error.message);

  }

});





// ==========================



// ✅ 2. Email OTP Verification Function (Existing)



// ==========================



const GMAIL_USER = "madarsaconnect.org@gmail.com";



const GMAIL_PASS = "xpjzydcxpfnebuuw";







const transporter = nodemailer.createTransport({



  service: 'gmail',



  auth: {



    user: GMAIL_USER,



    pass: GMAIL_PASS



  }



});







exports.sendOtpEmail = functions.https.onCall(async (data, context) => {



  const email = data.data.email;



  const otp = data.data.otp;



  const name = data.data.name || "user";







  console.log('📩 Sending OTP to:', email, 'OTP:', otp);







  if (!email) {



    console.error("❌ No email provided!");



    return { success: false, error: "No email provided" };



  }







  const mailOptions = {



    from: `Madarsa Connect <${GMAIL_USER}>`,



    to: email,



    subject: '🔐 Verify your email - Madarsa Connect',



    text: `Dear ${name},\n\nYour OTP is: ${otp}\n\nThis OTP is valid for 5 minutes.\nIf you did not request this, please ignore this email.`,



    html: `



      <div style="max-width: 600px; margin: auto; font-family: 'Segoe UI', sans-serif; background-color: #f9f9f9; border-radius: 10px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">



        <div style="background-color: #2E6C80; padding: 20px;">



          <h2 style="color: white; margin: 0;">Madarsa Connect</h2>



          <p style="color: #cce7f3; margin: 5px 0 0;">Email Verification OTP</p>



        </div>







        <div style="padding: 30px;">



          <p style="font-size: 16px; color: #333;">Dear user,</p>



          <p style="font-size: 15px; color: #555;">



            We received a request to verify your email address. Please use the following OTP to complete your verification:



          </p>







          <div style="text-align: center; margin: 30px 0;">



            <span style="font-size: 36px; color: #d32f2f; font-weight: bold; letter-spacing: 2px;">${otp}</span>



          </div>







          <p style="font-size: 14px; color: #555;">



            This OTP is valid for <strong>5 minutes</strong>. Please do not share this code with anyone.



          </p>







          <p style="font-size: 14px; color: #888;">



            If you did not initiate this request, you can safely ignore this email.



          </p>



        </div>







        <div style="background-color: #f0f0f0; padding: 15px; text-align: center;">



          <p style="font-size: 12px; color: #777;">&copy; ${new Date().getFullYear()} Madarsa Connect. All rights reserved.</p>



        </div>



      </div>



    `,



  };







  try {



    await transporter.sendMail(mailOptions);



    console.log('✅ Email sent to', email);



    return { success: true };



  } catch (error) {



    console.error('❌ Error sending email:', error);



    return { success: false, error: error.toString() };



  }



});





exports.getGuestAuthToken = onCall(async (request) => {

  const data = request.data;

  console.log("INFO: Data received from client:", data);



  const deviceId = data?.deviceId;



  if (!deviceId) {

    console.error("ERROR: Device ID not found in payload. Payload received:", data);

    throw new HttpsError(

      "invalid-argument",

      "Device ID is required but was not received by the function."

    );

  }



  console.log(`INFO: Device ID extracted successfully: ${deviceId}`);



  const firestore = getFirestore();

  const guestRef = firestore.collection("guests").doc(deviceId);

  let firebaseUid;



  try {

    const guestDoc = await guestRef.get();



    if (guestDoc.exists) {

      firebaseUid = guestDoc.data().firebaseUid;

      console.log(`INFO: Returning existing UID: ${firebaseUid} for device: ${deviceId}`);

    } else {

      const newUser = await getAuth().createUser({});

      firebaseUid = newUser.uid;

      console.log(`INFO: Created new UID: ${firebaseUid} for device: ${deviceId}`);



      await guestRef.set({

        firebaseUid: firebaseUid,

        createdAt: FieldValue.serverTimestamp(),

      });

    }



    const customToken = await getAuth().createCustomToken(firebaseUid);

    return { token: customToken };

  } catch (error) {

    console.error("CRITICAL ERROR in getGuestAuthToken:", error);

    throw new HttpsError(

      "internal",

      "An unexpected error occurred on the server.",

      error.message

    );

  }

});



const { onCall, HttpsError } = require("firebase-functions/v2/https");

const { initializeApp, cert } = require("firebase-admin/app");

const { getAuth } = require("firebase-admin/auth");

const { getFirestore, FieldValue } = require("firebase-admin/firestore");



// Explicit service account credential

initializeApp({

  credential: cert(require("./service-account.json"))

});



exports.getGuestAuthToken = onCall(async (request) => {

  const data = request.data;

  console.log("INFO: Data received from client:", data);



  const deviceId = data?.deviceId;

  if (!deviceId) {

    console.error("ERROR: Device ID missing in payload:", data);

    throw new HttpsError(

      "invalid-argument",

      "Device ID is required but not provided."

    );

  }



  const firestore = getFirestore();

  const guestRef = firestore.collection("guests").doc(deviceId);

  let firebaseUid;



  try {

    const guestDoc = await guestRef.get();



    if (guestDoc.exists) {

      firebaseUid = guestDoc.data().firebaseUid;

      console.log(`Returning existing UID: ${firebaseUid} for device: ${deviceId}`);

    } else {

      const newUser = await getAuth().createUser({});

      firebaseUid = newUser.uid;

      console.log(`Created new UID: ${firebaseUid} for device: ${deviceId}`);



      await guestRef.set({

        firebaseUid: firebaseUid,

        createdAt: FieldValue.serverTimestamp(),

      });

    }



    const customToken = await getAuth().createCustomToken(firebaseUid);

    return { token: customToken };

  } catch (error) {

    console.error("CRITICAL ERROR in getGuestAuthToken:", error);

    throw new HttpsError(

      "internal",

      "An unexpected error occurred on the server.",

      error.message

    );

  }

});

//Notification2

exports.sendBroadcastNotification = functions.https.onRequest(async (req, res) => {
  try {
    // Request ki body se title aur body extract karein
    const { title, body } = req.body;

    // Check karein ki title aur body maujood hain ya nahi
    if (!title || !body) {
      return res.status(400).send("Missing fields: title or body");
    }

    // Jis topic par notification bhejna hai
    const topic = "all_users";

    // Notification ka payload (message object) taiyyar karein
    const message = {
      notification: {
        title: title,
        body: body,
      },
      // Android specific configuration
      android: {
        notification: {
          // Yeh channel ID Flutter app mein define kiye gaye channel se match honi chahiye
          channelId: "high_importance_channel" 
        }
      },
      // Apple Push Notification Service (APNS) specific configuration for iOS
      apns: {
        payload: {
          aps: {
            // iOS devices par default notification sound play karega
            sound: "default" 
          }
        }
      },
      // Target topic
      topic: topic,
    };

    // Firebase Cloud Messaging (FCM) service ka use karke message bhejein
    const response = await admin.messaging().send(message);
    
    // Success hone par console mein log karein
    console.log("Broadcast notification sent:", response);
    
    // Client ko success response bhejein
    res.status(200).send("Broadcast sent successfully");

  } catch (error) {
    // Error hone par console mein log karein
    console.error("Error sending broadcast notification:", error);
    
    // Client ko internal server error response bhejein
    res.status(500).send("Internal Error");
  }
});