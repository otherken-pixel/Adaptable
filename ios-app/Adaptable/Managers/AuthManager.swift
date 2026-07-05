import Foundation
import Supabase
import AuthenticationServices
import SwiftUI

/// Manages Google OAuth via ASWebAuthenticationSession, holding strong references
/// and configuring ephemeral session behaviors properly.
@Observable
final class AuthManager: NSObject {
    static let shared = AuthManager()
    
    // Hold a strong reference to prevent immediate deallocation
    private var webAuthSession: ASWebAuthenticationSession?
    
    private override init() {
        super.init()
    }
    
    /// Start Google Sign In Flow
    func signInWithGoogle(client: SupabaseClient) async throws {
        // Supabase authorization URL
        guard let authURL = try? await client.auth.getOAuthSignInURL(
            provider: .google,
            redirectTo: URL(string: "com.adaptable.app://login-callback") // Ensure this matches Info.plist CFBundleURLTypes
        ) else {
            throw AuthError.invalidURL
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "com.adaptable.app") { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: AuthError.missingCallbackURL)
                    return
                }
                
                Task {
                    do {
                        // Hand the callback URL back to Supabase to exchange for a session
                        try await client.auth.session(from: callbackURL)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            // Set to false so the browser can reuse existing Google cookies (SSO)
            session.prefersEphemeralWebBrowserSession = false
            
            // Requires ASWebAuthenticationPresentationContextProviding
            session.presentationContextProvider = self
            
            self.webAuthSession = session
            session.start()
        }
    }
    
    enum AuthError: Error {
        case invalidURL
        case missingCallbackURL
    }
}

// Extension to provide a presentation window for the ASWebAuthenticationSession
extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return the key window of the application
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: \.isKeyWindow) else {
            return ASPresentationAnchor()
        }
        return window
    }
}
