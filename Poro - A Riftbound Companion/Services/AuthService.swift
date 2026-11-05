import Foundation
import Observation
import FirebaseAuth

@Observable
final class AuthService {
    private(set) var currentUser: FirebaseAuth.User?
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    var isLoggedIn: Bool { currentUser != nil }

    var displayName: String? { currentUser?.displayName }
    var email: String? { currentUser?.email }

    init() {
        currentUser = Auth.auth().currentUser
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.currentUser = user
            }
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func signUp(email: String, password: String, displayName: String? = nil) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        currentUser = result.user
        let name = displayName?.isEmpty == false ? displayName! : String(email.split(separator: "@").first ?? "utilizador")
        try? await FirestoreService.saveUserProfile(uid: result.user.uid, displayName: name, email: email.lowercased())
    }

    func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        currentUser = result.user
    }

    func signOut() throws {
        try Auth.auth().signOut()
        currentUser = nil
    }

    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
}
