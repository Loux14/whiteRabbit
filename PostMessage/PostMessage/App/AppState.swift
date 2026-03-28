import Combine
import CryptoKit
import Foundation
import UserNotifications

@MainActor
class AppState: ObservableObject {

    static let shared = AppState()

    // MARK: - Multi-user

    @Published var profiles: [UserProfile] = []
    @Published var activeProfileId: String = ""
    @Published var profileUnreadCounts: [String: Int] = [:]

    var activeProfile: UserProfile? {
        profiles.first { $0.id == activeProfileId }
    }

    // MARK: - Account (derived from active profile)

    @Published var pseudo: String = ""
    @Published var authToken: String = ""
    @Published var isRegistered: Bool = false

    // MARK: - Conversations

    private var suppressConversationSave = false

    @Published var conversations: [String: [ChatMessage]] = [:] {
        didSet {
            guard !suppressConversationSave else { return }
            saveConversations()
        }
    }
    @Published var unreadCounts: [String: Int] = [:]
    var activeConversation: String? = nil

    func markRead(_ contact: String) {
        unreadCounts[contact] = nil
        updateBadge()
    }

    private func updateBadge() {
        let activeUnread = unreadCounts.values.reduce(0, +)
        let otherUnread  = profileUnreadCounts.values.reduce(0, +)
        let total = activeUnread + otherUnread
        UNUserNotificationCenter.current().setBadgeCount(total) { _ in }
        if total == 0 {
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        }
    }

    // MARK: - Internals

    private var isFetching = false
    private var processedIds = Set<Int>()
    private var pollTask: Task<Void, Never>?
    private var pendingMessages: [String: [String]] = [:]

    // MARK: - Init

    init() {
        loadProfiles()
        let savedId = UserDefaults.standard.string(forKey: "activeProfileId") ?? ""
        let profile = profiles.first { $0.id == savedId } ?? profiles.first
        if let profile {
            applyProfile(profile)
            if isRegistered {
                Task { await SessionManager.shared.clearAndLoad(for: profile.id) }
                startPolling()
            }
        }
    }

    // MARK: - Profile management

    private func applyProfile(_ profile: UserProfile) {
        activeProfileId = profile.id
        pseudo = profile.pseudo
        authToken = profile.authToken
        KeyManager.userPrefix = profile.id
        isRegistered = !pseudo.isEmpty && !authToken.isEmpty && KeyManager.hasKeys

        suppressConversationSave = true
        conversations = [:]
        unreadCounts = [:]
        processedIds = []
        pendingMessages = [:]
        suppressConversationSave = false

        loadConversations()
        UserDefaults.standard.set(profile.id, forKey: "activeProfileId")
    }

    func updateAvatar(for profileId: String, avatarIndex: Int) {
        guard let i = profiles.firstIndex(where: { $0.id == profileId }) else { return }
        profiles[i].avatarIndex = avatarIndex
        saveProfiles()
    }

    func deleteProfile(_ profile: UserProfile) async {
        // If deleting active profile, stop polling first
        if profile.id == activeProfileId {
            pollTask?.cancel()
            pollTask = nil
        }
        // Wipe per-user data
        UserDefaults.standard.removeObject(forKey: "conversations.\(profile.id)")
        KeychainManager.delete(key: "sessions.\(profile.id)")
        profileUnreadCounts[profile.id] = nil
        profiles.removeAll { $0.id == profile.id }
        saveProfiles()

        // Switch to another profile or log out
        if profile.id == activeProfileId {
            if let next = profiles.first {
                applyProfile(next)
                await SessionManager.shared.clearAndLoad(for: next.id)
                if isRegistered { startPolling() }
            } else {
                activeProfileId = ""
                pseudo = ""
                authToken = ""
                isRegistered = false
                suppressConversationSave = true
                conversations = [:]
                suppressConversationSave = false
                unreadCounts = [:]
                processedIds = []
            }
        }
    }

    func switchTo(_ profile: UserProfile) async {
        pollTask?.cancel()
        pollTask = nil
        profileUnreadCounts[profile.id] = nil
        updateBadge()
        applyProfile(profile)
        await SessionManager.shared.clearAndLoad(for: profile.id)
        if isRegistered { startPolling() }
    }

    // MARK: - Device token

    func uploadDeviceToken(_ token: String) async {
        guard !authToken.isEmpty else { return }
        try? await APIClient.shared.uploadDeviceToken(token, authToken: authToken)
    }

    // MARK: - Register

    func register(pseudo: String, avatarIndex: Int = 0) async throws {
        let response = try await APIClient.shared.register(pseudo: pseudo)

        // Create profile first to get its ID for Keychain key prefix
        let profile = UserProfile(pseudo: response.pseudo, authToken: response.authToken,
                                  avatarIndex: avatarIndex)
        KeyManager.userPrefix = profile.id

        let bundle = try KeyManager.generateAndStore()
        try await APIClient.shared.uploadKeys(bundle, token: response.authToken)

        profiles.append(profile)
        saveProfiles()
        applyProfile(profile)
        await SessionManager.shared.clearAndLoad(for: profile.id)

        if let token = UserDefaults.standard.string(forKey: "apnsToken") {
            Task { await uploadDeviceToken(token) }
        }
        startPolling()
    }

    // MARK: - Send

    func send(_ text: String, to contact: String) async throws {
        do {
            try await transmit(text, to: contact)
        } catch APIError.httpError(404) {
            pendingMessages[contact, default: []].append(text)
        }
        let msg = ChatMessage(id: UUID().uuidString, sender: pseudo, text: text,
                              timestamp: Date(), isOutgoing: true)
        conversations[contact, default: []].append(msg)
    }

    private func transmit(_ text: String, to contact: String) async throws {
        let session = try await SessionManager.shared.getOrCreateSendSession(
            with: contact,
            token: authToken
        )
        let counter = session.sendCounter
        let msgKey  = HybridCrypto.messageKey(from: session.masterSecret, counter: counter)
        let payload = try MessageCrypto.encrypt(text, key: msgKey)

        let request = SendMessageRequest(
            to:               contact,
            ephemeralKey:     session.isNew ? session.ephemeralPubB64 : nil,
            kemCiphertext:    session.isNew ? session.kemCiphertextB64 : nil,
            usedOnetimeKeyId: session.isNew ? session.usedOPKPubB64 : nil,
            ciphertext:       payload.ciphertext.base64EncodedString(),
            nonce:            payload.nonce.base64EncodedString()
        )
        _ = try await APIClient.shared.sendMessage(request, token: authToken)
        await SessionManager.shared.markSent(to: contact)
    }

    // MARK: - Polling

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                await fetchMessages()
                await retryPending()
                await pollOtherProfiles()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private func pollOtherProfiles() async {
        for profile in profiles where profile.id != activeProfileId {
            let count = (try? await APIClient.shared.fetchMessages(token: profile.authToken))?.count ?? 0
            profileUnreadCounts[profile.id] = count > 0 ? count : nil
        }
        updateBadge()
    }

    private func retryPending() async {
        guard !pendingMessages.isEmpty else { return }
        var stillPending: [String: [String]] = [:]
        for (contact, messages) in pendingMessages {
            var remaining: [String] = []
            for text in messages {
                do {
                    try await transmit(text, to: contact)
                } catch {
                    remaining.append(text)
                }
            }
            if !remaining.isEmpty { stillPending[contact] = remaining }
        }
        pendingMessages = stillPending
    }

    func fetchMessages() async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }

        guard let incoming = try? await APIClient.shared.fetchMessages(token: authToken) else { return }

        for msg in incoming {
            guard !processedIds.contains(msg.id) else {
                try? await APIClient.shared.deleteMessage(id: msg.id, token: authToken)
                continue
            }
            guard let text = try? await SessionManager.shared.decrypt(msg) else {
                print("[AppState] Decrypt failed for msg \(msg.id) from \(msg.sender), keeping on server")
                continue
            }
            processedIds.insert(msg.id)
            let chat = ChatMessage(
                id:         String(msg.id),
                sender:     msg.sender,
                text:       text,
                timestamp:  ISO8601DateFormatter().date(from: msg.timestamp) ?? Date(),
                isOutgoing: false
            )
            conversations[msg.sender, default: []].append(chat)
            if activeConversation != msg.sender {
                unreadCounts[msg.sender, default: 0] += 1
            }
            try? await APIClient.shared.deleteMessage(id: msg.id, token: authToken)
        }
    }
}

// MARK: - Persistence

extension AppState {
    private func saveConversations() {
        guard !activeProfileId.isEmpty else { return }
        if let data = try? JSONEncoder().encode(conversations) {
            UserDefaults.standard.set(data, forKey: "conversations.\(activeProfileId)")
        }
    }

    private func loadConversations() {
        guard !activeProfileId.isEmpty else { return }
        if let data = UserDefaults.standard.data(forKey: "conversations.\(activeProfileId)"),
           let saved = try? JSONDecoder().decode([String: [ChatMessage]].self, from: data) {
            conversations = saved
        }
    }

    func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: "profiles")
        }
    }

    func loadProfiles() {
        if let data = UserDefaults.standard.data(forKey: "profiles"),
           let saved = try? JSONDecoder().decode([UserProfile].self, from: data) {
            profiles = saved
        }
    }
}

// MARK: - Local model

struct ChatMessage: Identifiable, Codable {
    let id: String
    let sender: String
    let text: String
    let timestamp: Date
    let isOutgoing: Bool
}
