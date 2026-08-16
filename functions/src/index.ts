import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";

admin.initializeApp();

const db = admin.firestore();

/**
 * Triggered when a new friend request is created.
 * Sends a push notification to the target user.
 */
export const onFriendRequestCreated = onDocumentCreated(
  "users/{userId}/friend_requests/{requestId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const requestData = snapshot.data();
    const targetUserId = event.params.userId;
    // The client writes "fromDisplayName"; keep "fromUserName" as a legacy fallback
    const senderName =
      requestData.fromDisplayName || requestData.fromUserName || "Quelqu'un";

    // Get target user's FCM token
    const targetUserDoc = await db.collection("users").doc(targetUserId).get();
    if (!targetUserDoc.exists) return;

    const fcmToken = targetUserDoc.data()?.fcmToken;
    if (!fcmToken) {
      console.log(`No FCM token for user ${targetUserId}`);
      return;
    }

    // Send push notification
    try {
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: "Nouvelle demande d'ami",
          body: `${senderName} souhaite vous ajouter comme ami`,
        },
        data: {
          type: "friend_request",
          route: "/notifications",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "leguejuste_default",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: {
          payload: {
            aps: {
              badge: 1,
              sound: "default",
            },
          },
        },
      });
      console.log(`Push sent to ${targetUserId} for friend request from ${senderName}`);
    } catch (error) {
      console.error("Error sending push notification:", error);
      // If token is invalid, clean it up
      if ((error as any)?.code === "messaging/registration-token-not-registered") {
        await db.collection("users").doc(targetUserId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
      }
    }
  }
);

/**
 * Triggered when a friend request is accepted (notification created).
 * Sends a push notification to the original requester.
 */
export const onFriendAcceptedNotification = onDocumentCreated(
  "users/{userId}/notifications/{notificationId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const notifData = snapshot.data();

    // Only handle friend_request_accepted type
    if (notifData.type !== "friend_request_accepted") return;

    const targetUserId = event.params.userId;
    // The client writes "fromDisplayName"; keep "fromUserName" as a legacy fallback
    const accepterName =
      notifData.fromDisplayName || notifData.fromUserName || "Quelqu'un";

    // Get target user's FCM token
    const targetUserDoc = await db.collection("users").doc(targetUserId).get();
    if (!targetUserDoc.exists) return;

    const fcmToken = targetUserDoc.data()?.fcmToken;
    if (!fcmToken) {
      console.log(`No FCM token for user ${targetUserId}`);
      return;
    }

    try {
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: "Demande acceptée !",
          body: `${accepterName} a accepté votre demande d'ami`,
        },
        data: {
          type: "friend_request_accepted",
          route: "/friends",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "leguejuste_default",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: {
          payload: {
            aps: {
              badge: 1,
              sound: "default",
            },
          },
        },
      });
      console.log(`Push sent to ${targetUserId}: friend request accepted by ${accepterName}`);
    } catch (error) {
      console.error("Error sending push notification:", error);
      if ((error as any)?.code === "messaging/registration-token-not-registered") {
        await db.collection("users").doc(targetUserId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
      }
    }
  }
);
