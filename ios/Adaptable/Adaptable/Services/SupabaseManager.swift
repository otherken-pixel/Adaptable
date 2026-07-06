import Foundation
import Supabase

/// Wires the native app to the exact same Supabase project as the web app
/// (`ypziulvtfsyrwpotlevp`), so recipes, votes, comments and the community
/// feed are shared across every platform. Configuration lives in
/// `Support/Config.xcconfig` → `Info.plist` (see that file for details).
///
/// When the URL/key are missing the app boots in Demo Mode, mirroring
/// `src/lib/supabase.ts`: a fully interactive local experience backed by
/// seeded data, explorable with zero setup.
enum SupabaseManager {
    static let supabaseURLString: String = {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
    }()

    static let supabaseAnonKey: String = {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""
    }()

    /// True when no valid Supabase config is present.
    static let isDemo: Bool = {
        guard !supabaseURLString.isEmpty,
              !supabaseAnonKey.isEmpty,
              !supabaseURLString.hasPrefix("$("),
              let url = URL(string: supabaseURLString),
              let host = url.host, !host.isEmpty,
              url.scheme?.hasPrefix("http") == true
        else { return true }
        return false
    }()

    /// The shared client. Only touch this when `isDemo == false`.
    static let client: SupabaseClient = {
        // Demo mode never calls the client; use a valid placeholder so a
        // misconfigured xcconfig can't fatal-error at launch.
        let urlString = isDemo ? "https://placeholder.supabase.co" : supabaseURLString
        let key = isDemo ? "placeholder" : supabaseAnonKey
        return SupabaseClient(
            supabaseURL: URL(string: urlString)!,
            supabaseKey: key
        )
    }()

    /// Custom URL scheme used for OAuth + password-reset redirects.
    static let redirectURL = URL(string: "com.adaptable.app://login-callback")!
    static let resetPasswordRedirectURL = URL(string: "com.adaptable.app://reset-password")!
}
