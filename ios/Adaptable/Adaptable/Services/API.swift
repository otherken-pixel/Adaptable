import Foundation
import Supabase

/// Every network call the app makes, live or Demo Mode. Mirrors
/// `src/lib/api.ts` function-for-function so behavior stays identical to
/// the web app. Live calls hit the exact same Supabase project — same
/// recipes, same community, same edge functions.
enum API {
    private static let recipeSelect = "*, author:profiles!recipes_author_id_fkey(id, username, avatar_url)"
    private static let commentSelect = "*, author:profiles!comments_user_id_fkey(id, username, avatar_url)"

    private static var db: SupabaseClient { SupabaseManager.client }

    // MARK: - Feed / recipes

    static func fetchFeed(sort: FeedSort) async throws -> [Recipe] {
        if SupabaseManager.isDemo {
            let list = await DemoStore.shared.listRecipes()
            switch sort {
            case .top: return list.sorted { ($0.net_upvotes ?? 0) > ($1.net_upvotes ?? 0) }
            case .new: return list.sorted { ($0.created_at ?? "") > ($1.created_at ?? "") }
            case .hot: return Trending.sorted(list)
            }
        }
        do {
            var query = db.from("recipes").select(recipeSelect).limit(50)
            query = sort == .top
                ? query.order("net_upvotes", ascending: false).order("created_at", ascending: false)
                : query.order("created_at", ascending: false)
            let rows: [Recipe] = try await query.execute().value
            return sort == .hot ? Trending.sorted(rows) : rows
        } catch {
            throw AppError(.requestFailed, message: error.localizedDescription)
        }
    }

    static func fetchRecipe(id: String) async throws -> Recipe? {
        if SupabaseManager.isDemo { return await DemoStore.shared.getRecipe(id) }
        do {
            let rows: [Recipe] = try await db.from("recipes").select(recipeSelect).eq("id", value: id).limit(1).execute().value
            return rows.first
        } catch {
            throw AppError(.requestFailed, message: error.localizedDescription)
        }
    }

    /// Recipes authored by a specific user (Profile "Your creations").
    static func fetchRecipesByAuthor(userId: String, limit: Int = 100) async throws -> [Recipe] {
        if SupabaseManager.isDemo {
            let list = await DemoStore.shared.listRecipes()
            return list.filter { $0.author_id == userId }
        }
        do {
            return try await db.from("recipes")
                .select(recipeSelect)
                .eq("author_id", value: userId)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
        } catch {
            throw AppError(.requestFailed, message: error.localizedDescription)
        }
    }

    // MARK: - Votes

    static func fetchMyVotes(userId: String) async throws -> [String: VoteValue] {
        if SupabaseManager.isDemo { return await DemoStore.shared.getVotes() }
        do {
            struct Row: Decodable { let recipe_id: String; let value: Int }
            let rows: [Row] = try await db.from("user_votes").select("recipe_id, value").eq("user_id", value: userId).execute().value
            return Dictionary(uniqueKeysWithValues: rows.map { ($0.recipe_id, $0.value) })
        } catch {
            throw AppError(.requestFailed, message: error.localizedDescription)
        }
    }

    static func setVote(userId: String, recipeId: String, value: VoteValue?) async throws {
        if SupabaseManager.isDemo { return await DemoStore.shared.setVote(recipeId, value: value) }
        do {
            if let value {
                struct Payload: Encodable { let user_id: String; let recipe_id: String; let value: Int }
                try await db.from("user_votes").upsert(Payload(user_id: userId, recipe_id: recipeId, value: value)).execute()
            } else {
                try await db.from("user_votes").delete().eq("user_id", value: userId).eq("recipe_id", value: recipeId).execute()
            }
        } catch {
            throw AppError(.requestFailed, message: error.localizedDescription)
        }
    }

    // MARK: - Saves

    static func fetchMySaveIds(userId: String) async throws -> [String] {
        if SupabaseManager.isDemo { return await DemoStore.shared.getSaves() }
        do {
            struct Row: Decodable { let recipe_id: String }
            let rows: [Row] = try await db.from("saves").select("recipe_id").eq("user_id", value: userId).order("created_at", ascending: false).execute().value
            return rows.map(\.recipe_id)
        } catch {
            throw AppError(.requestFailed, message: error.localizedDescription)
        }
    }

    static func fetchSavedRecipes(userId: String) async throws -> [Recipe] {
        if SupabaseManager.isDemo {
            let ids = await DemoStore.shared.getSaves()
            var out: [Recipe] = []
            for id in ids { if let r = await DemoStore.shared.getRecipe(id) { out.append(r) } }
            return out
        }
        do {
            struct Row: Decodable { let recipe: Recipe? }
            let rows: [Row] = try await db.from("saves").select("recipe:recipes(\(recipeSelect))").eq("user_id", value: userId).order("created_at", ascending: false).execute().value
            return rows.compactMap(\.recipe)
        } catch {
            throw AppError(.requestFailed, message: error.localizedDescription)
        }
    }

    @discardableResult
    static func toggleSave(userId: String, recipeId: String, currentlySaved: Bool) async throws -> Bool {
        if SupabaseManager.isDemo { return await DemoStore.shared.toggleSave(recipeId) }
        do {
            if currentlySaved {
                try await db.from("saves").delete().eq("user_id", value: userId).eq("recipe_id", value: recipeId).execute()
                return false
            }
            struct Payload: Encodable { let user_id: String; let recipe_id: String }
            try await db.from("saves").upsert(Payload(user_id: userId, recipe_id: recipeId)).execute()
            return true
        } catch {
            throw AppError(.requestFailed, message: error.localizedDescription)
        }
    }

    // MARK: - Comments

    static func fetchComments(recipeId: String) async throws -> [Comment] {
        if SupabaseManager.isDemo { return await DemoStore.shared.listComments(recipeId) }
        do {
            return try await db.from("comments").select(commentSelect).eq("recipe_id", value: recipeId)
                .order("created_at", ascending: false).limit(100).execute().value
        } catch {
            throw AppError(.requestFailed, message: error.localizedDescription)
        }
    }

    static func addComment(userId: String, recipeId: String, body: String) async throws -> Comment {
        if SupabaseManager.isDemo { return await DemoStore.shared.addComment(recipeId, body: body) }
        do {
            struct Payload: Encodable { let user_id: String; let recipe_id: String; let body: String }
            return try await db.from("comments")
                .insert(Payload(user_id: userId, recipe_id: recipeId, body: body))
                .select(commentSelect).single().execute().value
        } catch {
            throw AppError(.requestFailed, message: error.localizedDescription)
        }
    }

    static func deleteComment(userId: String, commentId: String) async throws {
        if SupabaseManager.isDemo { return await DemoStore.shared.deleteComment(commentId) }
        do {
            try await db.from("comments").delete().eq("user_id", value: userId).eq("id", value: commentId).execute()
        } catch {
            throw AppError(.requestFailed, message: error.localizedDescription)
        }
    }

    // MARK: - Cooks

    static func recordCook(userId: String, recipeId: String) async throws {
        if SupabaseManager.isDemo { return await DemoStore.shared.recordCook(recipeId) }
        do {
            struct Payload: Encodable { let user_id: String; let recipe_id: String }
            try await db.from("cooks").insert(Payload(user_id: userId, recipe_id: recipeId)).execute()
        } catch {
            throw AppError(.requestFailed, message: error.localizedDescription)
        }
    }

    // MARK: - Notifications

    static func fetchNotifications(userId: String) async throws -> [AppNotification] {
        if SupabaseManager.isDemo { return await DemoStore.shared.listNotifications() }
        let select = "*, actor:profiles!notifications_actor_id_fkey(id, username, avatar_url), recipe:recipes(id, title, emoji)"
        return try await db.from("notifications").select(select).eq("user_id", value: userId)
            .order("created_at", ascending: false).limit(50).execute().value
    }

    static func markNotificationsRead(userId: String) async throws {
        if SupabaseManager.isDemo { return await DemoStore.shared.markNotificationsRead() }
        struct Payload: Encodable { let read: Bool }
        try await db.from("notifications").update(Payload(read: true)).eq("user_id", value: userId).eq("read", value: false).execute()
    }

    // MARK: - Device tokens (push)

    static func registerDeviceToken(userId: String, token: String, platform: String) async throws {
        if SupabaseManager.isDemo { return }
        struct Payload: Encodable { let token: String; let user_id: String; let platform: String }
        try await db.from("device_tokens").upsert(Payload(token: token, user_id: userId, platform: platform)).execute()
    }

    static func unregisterDeviceToken(userId: String, token: String) async throws {
        if SupabaseManager.isDemo { return }
        try await db.from("device_tokens")
            .delete()
            .eq("user_id", value: userId)
            .eq("token", value: token)
            .execute()
    }

    // MARK: - Shopping list

    static func fetchShoppingItems(userId: String) async throws -> [ShoppingItem] {
        if SupabaseManager.isDemo { return await ShoppingLocal.shared.list() }
        return try await db.from("shopping_items")
            .select("id, recipe_id, recipe_title, item, quantity, checked, created_at")
            .eq("user_id", value: userId).order("created_at", ascending: false).execute().value
    }

    static func addShoppingItems(userId: String, rows: [(recipeId: String?, recipeTitle: String, item: String, quantity: String)]) async throws -> [ShoppingItem] {
        if SupabaseManager.isDemo { return await ShoppingLocal.shared.add(rows) }
        struct Payload: Encodable {
            let user_id: String
            let recipe_id: String?
            let recipe_title: String
            let item: String
            let quantity: String
        }
        let payloads = rows.map { Payload(user_id: userId, recipe_id: $0.recipeId, recipe_title: $0.recipeTitle, item: $0.item, quantity: $0.quantity) }
        return try await db.from("shopping_items").insert(payloads)
            .select("id, recipe_id, recipe_title, item, quantity, checked, created_at").execute().value
    }

    static func setShoppingItemChecked(userId: String, id: String, checked: Bool) async throws {
        if SupabaseManager.isDemo { return await ShoppingLocal.shared.setChecked(id, checked: checked) }
        struct Payload: Encodable { let checked: Bool }
        try await db.from("shopping_items").update(Payload(checked: checked)).eq("user_id", value: userId).eq("id", value: id).execute()
    }

    static func removeShoppingItem(userId: String, id: String) async throws {
        if SupabaseManager.isDemo { return await ShoppingLocal.shared.remove(id) }
        try await db.from("shopping_items").delete().eq("user_id", value: userId).eq("id", value: id).execute()
    }

    static func clearCheckedShoppingItems(userId: String) async throws {
        if SupabaseManager.isDemo { return await ShoppingLocal.shared.clearChecked() }
        try await db.from("shopping_items").delete().eq("user_id", value: userId).eq("checked", value: true).execute()
    }

    // MARK: - Meal planner

    static func fetchMealPlans(userId: String) async throws -> [MealPlanEntry] {
        if SupabaseManager.isDemo { return await DemoStore.shared.listPlans() }
        return try await db.from("meal_plans").select("*, recipe:recipes(\(recipeSelect))")
            .eq("user_id", value: userId).order("plan_date", ascending: true).execute().value
    }

    static func addMealPlan(userId: String, recipeId: String, planDate: String, servings: Int) async throws {
        if SupabaseManager.isDemo { _ = await DemoStore.shared.addPlan(recipeId, planDate: planDate, servings: servings); return }
        struct Payload: Encodable { let user_id: String; let recipe_id: String; let plan_date: String; let servings: Int }
        try await db.from("meal_plans").insert(Payload(user_id: userId, recipe_id: recipeId, plan_date: planDate, servings: servings)).execute()
    }

    static func updateMealPlanServings(userId: String, id: String, servings: Int) async throws {
        if SupabaseManager.isDemo { return await DemoStore.shared.updatePlanServings(id, servings: servings) }
        struct Payload: Encodable { let servings: Int }
        try await db.from("meal_plans").update(Payload(servings: servings)).eq("user_id", value: userId).eq("id", value: id).execute()
    }

    static func removeMealPlan(userId: String, id: String) async throws {
        if SupabaseManager.isDemo { return await DemoStore.shared.removePlan(id) }
        try await db.from("meal_plans").delete().eq("user_id", value: userId).eq("id", value: id).execute()
    }

    // MARK: - Follows

    static func fetchFollowees(userId: String) async throws -> [String] {
        if SupabaseManager.isDemo { return await DemoStore.shared.getFollows() }
        struct Row: Decodable { let followee_id: String }
        let rows: [Row] = try await db.from("follows").select("followee_id").eq("follower_id", value: userId).execute().value
        return rows.map(\.followee_id)
    }

    static func setFollow(userId: String, chefId: String, follow: Bool) async throws {
        if SupabaseManager.isDemo { _ = await DemoStore.shared.toggleFollow(chefId); return }
        if follow {
            struct Payload: Encodable { let follower_id: String; let followee_id: String }
            try await db.from("follows").upsert(Payload(follower_id: userId, followee_id: chefId)).execute()
        } else {
            try await db.from("follows").delete().eq("follower_id", value: userId).eq("followee_id", value: chefId).execute()
        }
    }

    // MARK: - Cooked-it photos + avatars (live mode only; storage-backed)

    static func fetchRecipePhotos(recipeId: String) async throws -> [RecipePhoto] {
        if SupabaseManager.isDemo { return [] }
        var photos: [RecipePhoto] = try await db.from("recipe_photos").select("*")
            .eq("recipe_id", value: recipeId).order("created_at", ascending: false).limit(24).execute().value
        for i in photos.indices {
            photos[i].url = (try? SupabaseManager.client.storage.from("cook-photos").getPublicURL(path: photos[i].path))?.absoluteString
        }
        return photos
    }

    static func uploadCookPhoto(userId: String, recipeId: String, imageData: Data) async throws -> RecipePhoto {
        let path = "\(userId)/\(recipeId)-\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
        try await SupabaseManager.client.storage.from("cook-photos").upload(path, data: imageData, options: FileOptions(contentType: "image/jpeg"))
        struct Payload: Encodable { let user_id: String; let recipe_id: String; let path: String }
        var photo: RecipePhoto = try await db.from("recipe_photos")
            .insert(Payload(user_id: userId, recipe_id: recipeId, path: path))
            .select("*").single().execute().value
        photo.url = (try? SupabaseManager.client.storage.from("cook-photos").getPublicURL(path: path))?.absoluteString
        return photo
    }

    static func uploadAvatar(userId: String, imageData: Data) async throws -> String {
        let path = "\(userId)/avatar-\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
        try await SupabaseManager.client.storage.from("avatars").upload(
            path, data: imageData,
            options: FileOptions(contentType: "image/jpeg", upsert: true)
        )
        let url = try SupabaseManager.client.storage.from("avatars").getPublicURL(path: path)
        struct Payload: Encodable { let avatar_url: String }
        try await db.from("profiles").update(Payload(avatar_url: url.absoluteString)).eq("id", value: userId).execute()
        return url.absoluteString
    }

    // MARK: - Import + generation (edge functions)

    private struct RecipeEnvelope: Decodable { let recipe: Recipe }
    private struct EdgeErrorBody: Decodable { let error: String? }

    private static func invoke(_ name: String, body: some Encodable) async throws -> Recipe {
        do {
            let envelope: RecipeEnvelope = try await SupabaseManager.client.functions.invoke(
                name, options: FunctionInvokeOptions(body: body)
            )
            return envelope.recipe
        } catch let FunctionsError.httpError(code, data) {
            let message = (try? JSONDecoder().decode(EdgeErrorBody.self, from: data))?.error
            throw AppError(message ?? "Request failed (\(code)).")
        } catch {
            throw error
        }
    }

    static func importRecipe(_ source: ImportSource) async throws -> Recipe {
        if SupabaseManager.isDemo {
            return await DemoStore.shared.importRecipe(url: source.url, hasText: source.text != nil)
        }
        struct Body: Encodable {
            let url: String?
            let text: String?
            let image_base64: String?
            let mime_type: String?
        }
        let body = Body(url: source.url, text: source.text, image_base64: source.imageBase64, mime_type: source.mimeType)
        return try await invoke("import-recipe", body: body)
    }

    static func generateRecipe(prompt: String, servings: Int?) async throws -> Recipe {
        if SupabaseManager.isDemo { return await DemoStore.shared.generate(prompt: prompt, servings: servings) }
        struct Body: Encodable { let prompt: String; let servings: Int? }
        let body = Body(prompt: prompt, servings: servings)
        // One client-side retry for transient edge/Gemini failures.
        do {
            return try await invoke("generate-recipe", body: body)
        } catch {
            let message = (error as? AppError)?.message ?? error.localizedDescription
            let retryable = message.localizedCaseInsensitiveContains("temporarily unavailable")
                || message.localizedCaseInsensitiveContains("try again")
                || message.localizedCaseInsensitiveContains("Too many requests")
            guard retryable else { throw error }
            try await Task.sleep(nanoseconds: 800_000_000)
            return try await invoke("generate-recipe", body: body)
        }
    }

    // MARK: - Account deletion

    static func deleteAccount() async throws {
        if SupabaseManager.isDemo { return }
        struct EmptyResponse: Decodable {}
        do {
            let _: EmptyResponse = try await SupabaseManager.client.functions.invoke("delete-account")
        } catch let FunctionsError.httpError(code, data) {
            let message = (try? JSONDecoder().decode(EdgeErrorBody.self, from: data))?.error
            throw AppError(message ?? "Deletion failed (\(code)).")
        }
    }
}
