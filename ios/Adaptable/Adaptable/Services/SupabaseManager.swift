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
        supabaseURLString.isEmpty
            || supabaseAnonKey.isEmpty
            || supabaseURLString.hasPrefix("$(")
            || URL(string: supabaseURLString) == nil
    }()

    /// The shared client. Only touch this when `isDemo == false`.
    static let client: SupabaseClient = {
        SupabaseClient(
            supabaseURL: URL(string: supabaseURLString) ?? URL(string: "https://invalid.supabase.co")!,
            supabaseKey: supabaseAnonKey
        )
    }()

    /// Custom URL scheme used for OAuth + password-reset redirects.
    static let redirectURL = URL(string: "com.adaptable.app://login-callback")!
    static let resetPasswordRedirectURL = URL(string: "com.adaptable.app://reset-password")!
}
