import Foundation
import FirebaseMessaging
import FirebaseFirestore
import UserNotifications
import UIKit

enum NotificationService {

    // MARK: - Permission + Registration

    static func requestPermissionAndRegister() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            print("[FCM] Permission error: \(error.localizedDescription)")
        }
    }

    // MARK: - Save token to Firestore

    static func saveToken(for userId: String) async {
        guard let token = Messaging.messaging().fcmToken else { return }
        do {
            try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .collection("profile")
                .document("fcm")
                .setData(["token": token, "updatedAt": Timestamp()])
        } catch {
            print("[FCM] Save token error: \(error.localizedDescription)")
        }
    }

    static func deleteToken(for userId: String) async {
        do {
            try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .collection("profile")
                .document("fcm")
                .delete()
        } catch {}
    }
}
