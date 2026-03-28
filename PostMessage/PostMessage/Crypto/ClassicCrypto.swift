import CryptoKit
import Foundation

enum ClassicCrypto {

    // MARK: - Key generation

    static func generateIdentityKey() -> Curve25519.Signing.PrivateKey {
        Curve25519.Signing.PrivateKey()
    }

    static func generateAgreementKey() -> Curve25519.KeyAgreement.PrivateKey {
        Curve25519.KeyAgreement.PrivateKey()
    }

    // MARK: - DH exchange

    static func dh(
        _ privateKey: Curve25519.KeyAgreement.PrivateKey,
        _ publicKey: Curve25519.KeyAgreement.PublicKey
    ) throws -> Data {
        let secret = try privateKey.sharedSecretFromKeyAgreement(with: publicKey)
        return secret.withUnsafeBytes { Data($0) }
    }

    // MARK: - Signatures

    static func sign(_ data: Data, with key: Curve25519.Signing.PrivateKey) throws -> Data {
        try key.signature(for: data)
    }

    static func verify(_ signature: Data, for data: Data, publicKey: Curve25519.Signing.PublicKey) -> Bool {
        publicKey.isValidSignature(signature, for: data)
    }
}
