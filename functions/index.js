const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
admin.initializeApp();

// Triggered when a new message is created in any conversation
exports.onNewMessage = onDocumentCreated(
  "conversations/{convId}/messages/{messageId}",
  async (event) => {
    const message = event.data.data();
    const convId = event.params.convId;

    // Get the conversation to find the recipient
    const convSnap = await admin.firestore()
      .collection("conversations")
      .doc(convId)
      .get();

    if (!convSnap.exists) return;
    const conv = convSnap.data();

    const senderId = message.senderId;
    const recipientId = conv.buyerId === senderId ? conv.sellerId : conv.buyerId;

    // Get recipient's FCM token
    const tokenSnap = await admin.firestore()
      .collection("users")
      .doc(recipientId)
      .collection("profile")
      .doc("fcm")
      .get();

    if (!tokenSnap.exists) return;
    const token = tokenSnap.data().token;
    if (!token) return;

    // Send notification
    await admin.messaging().send({
      token,
      notification: {
        title: message.senderName,
        body: message.text.length > 100
          ? message.text.substring(0, 100) + "…"
          : message.text,
      },
      data: {
        conversationId: convId,
        type: "message",
      },
      apns: {
        payload: {
          aps: { sound: "default" },
        },
      },
    });
  }
);
