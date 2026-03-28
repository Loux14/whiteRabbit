import CryptoKit
import Foundation

enum HybridCrypto {

    // MARK: - Session establishment (sender side)
    //
    // Simplified PQXDH:
    //   dh  = DH(ephemeral_priv, recipient_spk_pub)
    //   ss  = ML-KEM.Encaps(recipient_pqspk_pub)
    //   master = HKDF(dh || ss)

    static func establishSession(
        ephemeralPriv: Curve25519.KeyAgreement.PrivateKey,
        recipientSPK: Curve25519.KeyAgreement.PublicKey,
        recipientOPK: Curve25519.KeyAgreement.PublicKey?,
        recipientPQKey: Data
    ) throws -> (masterSecret: SymmetricKey, kemCiphertext: Data) {
        var ikm = Data()
        ikm.append(try ClassicCrypto.dh(ephemeralPriv, recipientSPK))
        if let opk = recipientOPK {
            ikm.append(try ClassicCrypto.dh(ephemeralPriv, opk))
        }
        let (kemCT, ss) = try PQCrypto.encapsulate(publicKey: recipientPQKey)
        ikm.append(ss)
        return (deriveKey(from: ikm), kemCT)
    }

    // MARK: - Session recovery (receiver side)

    static func recoverSession(
        recipientSPKPriv: Curve25519.KeyAgreement.PrivateKey,
        recipientOPKPriv: Curve25519.KeyAgreement.PrivateKey?,
        recipientPQKeyPriv: Data,
        senderEphemeralPub: Curve25519.KeyAgreement.PublicKey,
        kemCiphertext: Data
    ) throws -> SymmetricKey {
        var ikm = Data()
        ikm.append(try ClassicCrypto.dh(recipientSPKPriv, senderEphemeralPub))
        if let opkPriv = recipientOPKPriv {
            ikm.append(try ClassicCrypto.dh(opkPriv, senderEphemeralPub))
        }
        ikm.append(try PQCrypto.decapsulate(ciphertext: kemCiphertext, privateKey: recipientPQKeyPriv))
        return deriveKey(from: ikm)
    }

    // MARK: - Per-message key derivation

    static func messageKey(from masterSecret: SymmetricKey, counter: Int) -> SymmetricKey {
        var info = Data("msg".utf8)
        withUnsafeBytes(of: UInt32(counter).bigEndian) { info.append(contentsOf: $0) }
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: masterSecret,
            info: info,
            outputByteCount: 32
        )
    }

    // MARK: - Private

    private static func deriveKey(from ikm: Data) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: ikm),
            info: Data("hybrid_session_v1".utf8),
            outputByteCount: 32
        )
    }
}
