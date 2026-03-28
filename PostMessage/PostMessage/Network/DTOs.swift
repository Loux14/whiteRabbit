import Foundation

// MARK: - Register
struct RegisterRequest: Codable {
    let pseudo: String
}

struct RegisterResponse: Codable {
    let pseudo: String
    let authToken: String

    enum CodingKeys: String, CodingKey {
        case pseudo
        case authToken = "auth_token"
    }
}

// MARK: - Keys
struct SignedKeyDTO: Codable {
    let key: String
    let signature: String   // Ed25519
    let pqSignature: String // ML-DSA-65

    enum CodingKeys: String, CodingKey {
        case key
        case signature
        case pqSignature = "pq_signature"
    }
}

struct KeyBundleUpload: Codable {
    let identityKey: String
    let pqIdentityKey: String
    let signedPrekey: SignedKeyDTO
    let onetimePrekeys: [String]
    let pqSignedPrekey: SignedKeyDTO
    let pqOnetimePrekeys: [String]

    enum CodingKeys: String, CodingKey {
        case identityKey      = "identity_key"
        case pqIdentityKey    = "pq_identity_key"
        case signedPrekey     = "signed_prekey"
        case onetimePrekeys   = "onetime_prekeys"
        case pqSignedPrekey   = "pq_signed_prekey"
        case pqOnetimePrekeys = "pq_onetime_prekeys"
    }
}

struct KeyBundleResponse: Codable {
    let pseudo: String
    let identityKey: String
    let pqIdentityKey: String
    let signedPrekey: SignedKeyDTO
    let onetimePrekey: String?
    let pqSignedPrekey: SignedKeyDTO
    let pqOnetimePrekey: String?

    enum CodingKeys: String, CodingKey {
        case pseudo
        case identityKey     = "identity_key"
        case pqIdentityKey   = "pq_identity_key"
        case signedPrekey    = "signed_prekey"
        case onetimePrekey   = "onetime_prekey"
        case pqSignedPrekey  = "pq_signed_prekey"
        case pqOnetimePrekey = "pq_onetime_prekey"
    }
}

// MARK: - Messages
struct SendMessageRequest: Codable {
    let to: String
    let ephemeralKey: String?
    let kemCiphertext: String?
    let usedOnetimeKeyId: String?
    let ciphertext: String
    let nonce: String

    enum CodingKeys: String, CodingKey {
        case to
        case ephemeralKey      = "ephemeral_key"
        case kemCiphertext     = "kem_ciphertext"
        case usedOnetimeKeyId  = "used_onetime_key_id"
        case ciphertext
        case nonce
    }
}

struct SendMessageResponse: Codable {
    let messageId: Int
    let timestamp: String

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case timestamp
    }
}

struct IncomingMessage: Codable, Identifiable {
    let id: Int
    let sender: String
    let ephemeralKey: String?
    let kemCiphertext: String?
    let usedOnetimeKeyId: String?
    let ciphertext: String
    let nonce: String
    let timestamp: String

    enum CodingKeys: String, CodingKey {
        case id
        case sender
        case ephemeralKey     = "ephemeral_key"
        case kemCiphertext    = "kem_ciphertext"
        case usedOnetimeKeyId = "used_onetime_key_id"
        case ciphertext
        case nonce
        case timestamp
    }
}

struct MessagesResponse: Codable {
    let messages: [IncomingMessage]
}
