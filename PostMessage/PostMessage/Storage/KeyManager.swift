import CryptoKit
import Foundation

// Keys stored in Keychain — prefixed per user
private enum K {
    static var p: String { KeyManager.userPrefix.isEmpty ? "" : "\(KeyManager.userPrefix)." }
    static var identitySignPriv: String  { p + "ik.sign.priv" }
    static var identitySignPub: String   { p + "ik.sign.pub" }
    static var pqikPriv: String          { p + "pqik.dsa.priv" }
    static var pqikPub: String           { p + "pqik.dsa.pub" }
    static var spkPriv: String           { p + "spk.priv" }
    static var spkPub: String            { p + "spk.pub" }
    static var spkSignature: String      { p + "spk.sig" }
    static var spkPQSignature: String    { p + "spk.pqsig" }
    static var pqspkPriv: String         { p + "pqspk.priv" }
    static var pqspkPub: String          { p + "pqspk.pub" }
    static var pqspkSignature: String    { p + "pqspk.sig" }
    static var pqspkPQSignature: String  { p + "pqspk.pqsig" }
    static var opkPrivPrefix: String     { p + "opk.priv." }
    static var opkPubPrefix: String      { p + "opk.pub." }
    static var pqopkPrivPrefix: String   { p + "pqopk.priv." }
    static var pqopkPubPrefix: String    { p + "pqopk.pub." }
}

enum KeyManager {

    static var userPrefix: String = ""
    static let opkCount   = 5
    static let pqopkCount = 5

    // MARK: - Generate and persist all keys

    static func generateAndStore() throws -> KeyBundleUpload {
        // Identity key — Ed25519 (classic)
        let ik = ClassicCrypto.generateIdentityKey()
        try KeychainManager.save(ik.rawRepresentation, key: K.identitySignPriv)
        try KeychainManager.save(ik.publicKey.rawRepresentation, key: K.identitySignPub)

        // PQ Identity key — ML-DSA-65
        let (pqikPub, pqikPriv) = PQCrypto.generateDSAKeyPair()
        try KeychainManager.save(pqikPriv, key: K.pqikPriv)
        try KeychainManager.save(pqikPub, key: K.pqikPub)

        // Signed PreKey (X25519) — signed by both IKs
        let spk = ClassicCrypto.generateAgreementKey()
        let spkSig   = try ClassicCrypto.sign(spk.publicKey.rawRepresentation, with: ik)
        let spkPQSig = try PQCrypto.signDSA(spk.publicKey.rawRepresentation, privateKey: pqikPriv)
        try KeychainManager.save(spk.rawRepresentation, key: K.spkPriv)
        try KeychainManager.save(spk.publicKey.rawRepresentation, key: K.spkPub)
        try KeychainManager.save(spkSig, key: K.spkSignature)
        try KeychainManager.save(spkPQSig, key: K.spkPQSignature)

        // PQ Signed PreKey (ML-KEM-768) — signed by both IKs
        let (pqspkPub, pqspkPriv) = PQCrypto.generateKEMKeyPair()
        let pqspkSig   = try ClassicCrypto.sign(pqspkPub, with: ik)
        let pqspkPQSig = try PQCrypto.signDSA(pqspkPub, privateKey: pqikPriv)
        try KeychainManager.save(pqspkPriv, key: K.pqspkPriv)
        try KeychainManager.save(pqspkPub, key: K.pqspkPub)
        try KeychainManager.save(pqspkSig, key: K.pqspkSignature)
        try KeychainManager.save(pqspkPQSig, key: K.pqspkPQSignature)

        // One-time PreKeys (X25519)
        var opkPubs: [String] = []
        for i in 0..<opkCount {
            let opk = ClassicCrypto.generateAgreementKey()
            try KeychainManager.save(opk.rawRepresentation, key: K.opkPrivPrefix + "\(i)")
            try KeychainManager.save(opk.publicKey.rawRepresentation, key: K.opkPubPrefix + "\(i)")
            opkPubs.append(opk.publicKey.rawRepresentation.base64EncodedString())
        }

        // PQ One-time PreKeys (ML-KEM-768)
        var pqopkPubs: [String] = []
        for i in 0..<pqopkCount {
            let (pub, priv) = PQCrypto.generateKEMKeyPair()
            try KeychainManager.save(priv, key: K.pqopkPrivPrefix + "\(i)")
            try KeychainManager.save(pub, key: K.pqopkPubPrefix + "\(i)")
            pqopkPubs.append(pub.base64EncodedString())
        }

        return KeyBundleUpload(
            identityKey:      ik.publicKey.rawRepresentation.base64EncodedString(),
            pqIdentityKey:    pqikPub.base64EncodedString(),
            signedPrekey:     SignedKeyDTO(
                key:         spk.publicKey.rawRepresentation.base64EncodedString(),
                signature:   spkSig.base64EncodedString(),
                pqSignature: spkPQSig.base64EncodedString()
            ),
            onetimePrekeys:   opkPubs,
            pqSignedPrekey:   SignedKeyDTO(
                key:         pqspkPub.base64EncodedString(),
                signature:   pqspkSig.base64EncodedString(),
                pqSignature: pqspkPQSig.base64EncodedString()
            ),
            pqOnetimePrekeys: pqopkPubs
        )
    }

    // MARK: - Load identity key

    static func loadIdentityKey() throws -> Curve25519.Signing.PrivateKey {
        let data = try KeychainManager.load(key: K.identitySignPriv)
        return try Curve25519.Signing.PrivateKey(rawRepresentation: data)
    }

    static func loadIdentityPublicKey() throws -> Curve25519.Signing.PublicKey {
        let data = try KeychainManager.load(key: K.identitySignPub)
        return try Curve25519.Signing.PublicKey(rawRepresentation: data)
    }

    // MARK: - Load SPK

    static func loadSPKPrivate() throws -> Curve25519.KeyAgreement.PrivateKey {
        let data = try KeychainManager.load(key: K.spkPriv)
        return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
    }

    // MARK: - Load PQSPK

    static func loadPQSPKPrivate() throws -> Data {
        try KeychainManager.load(key: K.pqspkPriv)
    }

    // MARK: - Pop OPK (consumed on use)

    static func popOPKPrivate(id: String) throws -> Curve25519.KeyAgreement.PrivateKey? {
        guard let data = try? KeychainManager.load(key: K.opkPrivPrefix + id) else { return nil }
        KeychainManager.delete(key: K.opkPrivPrefix + id)
        KeychainManager.delete(key: K.opkPubPrefix + id)
        return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
    }

    static func findAndPopOPKPrivate(matchingPublicKey: Data) -> Curve25519.KeyAgreement.PrivateKey? {
        for i in 0..<opkCount {
            guard let pub = try? KeychainManager.load(key: K.opkPubPrefix + "\(i)") else { continue }
            if pub == matchingPublicKey {
                return try? popOPKPrivate(id: "\(i)")
            }
        }
        return nil
    }

    // MARK: - Pop PQOPK (consumed on use)

    static func popPQOPKPrivate(id: String) throws -> Data? {
        guard let data = try? KeychainManager.load(key: K.pqopkPrivPrefix + id) else { return nil }
        KeychainManager.delete(key: K.pqopkPrivPrefix + id)
        KeychainManager.delete(key: K.pqopkPubPrefix + id)
        return data
    }

    // MARK: - Check if keys exist

    static var hasKeys: Bool {
        (try? KeychainManager.load(key: K.identitySignPriv)) != nil
    }
}
