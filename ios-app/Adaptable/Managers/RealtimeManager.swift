import Foundation
import Supabase
import SwiftUI
import Combine

/// Manages the lifecycle of Supabase Realtime connections,
/// ensuring sockets are closed in the background and re-opened in the foreground.
@Observable
final class RealtimeManager {
    static let shared = RealtimeManager()
    
    // Assuming you have a global Supabase client configured
    // let client = SupabaseClient(supabaseURL: URL(string: "...")!, supabaseKey: "...")
    
    private var isConnected = false
    private var channel: RealtimeChannel?
    
    private init() {}
    
    /// Connect to the realtime channels. Call this when the app becomes active.
    func connect(client: SupabaseClient) async {
        guard !isConnected else { return }
        
        // Before connecting, it is highly recommended to perform a standard REST API fetch
        // to catch up on any missed events or data while the socket was disconnected.
        await catchUpMissedEvents(client: client)
        
        channel = client.channel("public:notifications")
        
        let _ = channel?.on("postgres_changes", filter: .init(event: "INSERT", schema: "public", table: "notifications")) { message in
            print("Received new notification: \(message.payload)")
            // Dispatch update to UI
        }
        
        do {
            try await channel?.subscribe()
            isConnected = true
            print("Successfully subscribed to Supabase Realtime")
        } catch {
            print("Failed to subscribe to Realtime: \(error)")
        }
    }
    
    /// Disconnect from the realtime channels. Call this when the app enters the background.
    func disconnect(client: SupabaseClient) async {
        guard isConnected else { return }
        
        if let channel = channel {
            do {
                try await client.removeChannel(channel)
            } catch {
                print("Error removing channel: \(error)")
            }
        }
        
        client.realtime.disconnect()
        isConnected = false
        print("Disconnected from Supabase Realtime")
    }
    
    /// Fallback fetch for missed events while the socket was closed.
    private func catchUpMissedEvents(client: SupabaseClient) async {
        // Fetch any notifications created since the last known timestamp.
        // Example:
        // do {
        //     let lastSync = UserDefaults.standard.string(forKey: "lastSyncDate") ?? Date().ISO8601Format()
        //     let missed = try await client.database
        //         .from("notifications")
        //         .select()
        //         .gt("created_at", value: lastSync)
        //         .execute()
        //     print("Caught up on missed notifications: \(missed.data)")
        // } catch { ... }
    }
}
