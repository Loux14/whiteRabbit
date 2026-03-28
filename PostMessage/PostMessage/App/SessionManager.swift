import CryptoKit
import Foundation

struct Session {
    let masterSecret: SymmetricKey
    var sendCounter: Int = 0
    var recvCounter: Int = 0
    var isNew: Bool = true
    var ephemeralPubB64: String?
    var kemCiphertextB64: String?
    var usedOPKPubB64: String?
}

// Codable representation for persistence
private struct SessionStore: Codable {
    let masterSecretB64: String
    var sendCounter: Int
    var recvCounter: Int
    var isNew: Bool
    var ephemeralPubB64: String?
    var kemCiphertextB64: String?
    var usedOPKPubB64: String?

    init(_ s: Session) {
        masterSecretB64  = s.masterSecret.withUnsafeBytes { Data($0).base64EncodedString() }
        sendCounter      = s.sendCounter
        recvCounter      = s.recvCounter
        isNew            = s.isNew
        ephemeralPubB64  = s.ephemeralPubB64
        kemCiphertextB64 = s.kemCiphertextB64
        usedOPKPubB64    = s.usedOPKPubB64
    }

    var session: Session? {
        guard let raw = Data(base64Encoded: masterSecretB64) else { return nil }
        return Session(masterSecret: SymmetricKey(data: raw),
                       sendCounter: sendCounter, recvCounter: recvCounter,
                       isNew: isNew,
                       ephemeralPubB64: ephemeralPubB64,
                       kemCiphertextB64: kemCiphertextB64,
                       usedOPKPubB64: usedOPKPubB64)
    }
}

actor SessionManager {

    static let shared = SessionManager()

    private var sendSessions: [String: Session] = [:]
    private var recvSessions: [String: Session] = [:]
    private var sessionKey = "sessions"

    // MARK: - Persistence

    func clearAndLoad(for userId: String) {
        sessionKey = "sessions.\(userId)"
        sendSessions = [:]
        recvSessions = [:]
        loadSessions()
    }

    func loadSessions() {
        guard let data = try? KeychainManager.load(key: sessionKey),
              let stored = try? JSONDecoder().decode([String: [String: SessionStore]].self, from: data)
        else { return }
        sendSessions = stored["send"]?.compactMapValues { $0.session } ?? [:]
        recvSessions = stored["recv"]?.compactMapValues { $0.session } ?? [:]
    }

    private func save() {
        let payload: [String: [String: SessionStore]] = [
            "send": sendSessions.mapValues { SessionStore($0) },
            "recv": recvSessions.mapValues { SessionStore($0) }
        ]
        if let data = try? JSONEncoder().encode(payload) {
            try? KeychainManager.save(data, key: sessionKey)
        }
    }

    // MARK: - Outgoing

    func getOrCreateSendSession(with contact: String, token: String) async throws -> Session {
        if let existing = sendSessions[contact] { return existing }

        let bundle = try await APIClient.shared.fetchKeys(for: contact)

        guard let ikData    = Data(base64Encoded: bundle.identityKey),
              let pqikData  = Data(base64Encoded: bundle.pqIdentityKey),
              let spkData   = Data(base64Encoded: bundle.signedPrekey.key),
              let sigData   = Data(base64Encoded: bundle.signedPrekey.signature),
              let pqSigData = Data(base64Encoded: bundle.signedPrekey.pqSignature) else {
            throw SessionError.invalidPayload
        }
        let ikPub  = try Curve25519.Signing.PublicKey(rawRepresentation: ikData)
        let spkPub = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: spkData)
        guard ClassicCrypto.verify(sigData, for: spkData, publicKey: ikPub),
              PQCrypto.verifyDSA(pqSigData, for: spkData, publicKey: pqikData) else {
            throw SessionError.invalidSignature
        }

        guard let pqData       = Data(base64Encoded: bundle.pqSignedPrekey.key),
              let pqSpkSigData = Data(base64Encoded: bundle.pqSignedPrekey.signature),
              let pqSpkPQSig   = Data(base64Encoded: bundle.pqSignedPrekey.pqSignature) else {
            throw SessionError.invalidPayload
        }
        guard ClassicCrypto.verify(pqSpkSigData, for: pqData, publicKey: ikPub),
              PQCrypto.verifyDSA(pqSpkPQSig, for: pqData, publicKey: pqikData) else {
            throw SessionError.invalidSignature
        }

        var opkPub: Curve25519.KeyAgreement.PublicKey? = nil
        if let opkB64 = bundle.onetimePrekey, let opkData = Data(base64Encoded: opkB64) {
            opkPub = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: opkData)
        }

        let eph = ClassicCrypto.generateAgreementKey()
        let (master, kemCT) = try HybridCrypto.establishSession(
            ephemeralPriv:  eph,
            recipientSPK:   spkPub,
            recipientOPK:   opkPub,
            recipientPQKey: pqData
        )

        let session = Session(
            masterSecret:     master,
            isNew:            true,
            ephemeralPubB64:  eph.publicKey.rawRepresentation.base64EncodedString(),
            kemCiphertextB64: kemCT.base64EncodedString(),
            usedOPKPubB64:    bundle.onetimePrekey
        )
        sendSessions[contact] = session
        save()
        return session
    }

    func markSent(to contact: String) {
        sendSessions[contact]?.sendCounter += 1
        sendSessions[contact]?.isNew = false
        save()
    }

    // MARK: - Incoming

    func decrypt(_ msg: IncomingMessage) async throws -> String {
        let masterSecret: SymmetricKey
        let counter: Int
        let isHandshake: Bool

        if let ephB64  = msg.ephemeralKey,
           let ephData = Data(base64Encoded: ephB64),
           let kemB64  = msg.kemCiphertext,
           let kemData = Data(base64Encoded: kemB64) {

            let spkPriv   = try KeyManager.loadSPKPrivate()
            let pqspkPriv = try KeyManager.loadPQSPKPrivate()
            let ephPub    = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: ephData)

            var opkPriv: Curve25519.KeyAgreement.PrivateKey? = nil
            if let opkPubB64 = msg.usedOnetimeKeyId,
               let opkPubData = Data(base64Encoded: opkPubB64) {
                opkPriv = KeyManager.findAndPopOPKPrivate(matchingPublicKey: opkPubData)
            }

            masterSecret = try HybridCrypto.recoverSession(
                recipientSPKPriv:   spkPriv,
                recipientOPKPriv:   opkPriv,
                recipientPQKeyPriv: pqspkPriv,
                senderEphemeralPub: ephPub,
                kemCiphertext:      kemData
            )
            counter     = 0
            isHandshake = true
        } else {
            guard let session = recvSessions[msg.sender] else {
                throw SessionError.missingHandshakeData
            }
            masterSecret = session.masterSecret
            counter      = session.recvCounter
            isHandshake  = false
        }

        guard let ctData    = Data(base64Encoded: msg.ciphertext),
              let nonceData = Data(base64Encoded: msg.nonce) else {
            throw SessionError.invalidPayload
        }

        let msgKey = HybridCrypto.messageKey(from: masterSecret, counter: counter)
        let text = try MessageCrypto.decrypt(
            MessageCrypto.EncryptedPayload(ciphertext: ctData, nonce: nonceData),
            key: msgKey
        )

        if isHandshake {
            recvSessions[msg.sender] = Session(masterSecret: masterSecret,
                                               recvCounter: 1, isNew: false)
        } else {
            recvSessions[msg.sender]?.recvCounter += 1
        }
        save()
        return text
    }
}

enum SessionError: Error, LocalizedError {
    case invalidSignature
    case missingHandshakeData
    case invalidPayload
    case userNotFound

    var errorDescription: String? {
        switch self {
        case .invalidSignature:     return "Invalid signature — contact may be compromised"
        case .missingHandshakeData: return "Missing session handshake data"
        case .invalidPayload:       return "Invalid payload"
        case .userNotFound:         return "User not found"
        }
    }
}
