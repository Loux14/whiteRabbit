import CryptoKit
import Foundation

enum MessageCrypto {

    struct EncryptedPayload {
        let ciphertext: Data  // ciphertext + GCM tag (16 bytes)
        let nonce: Data       // 12 bytes
    }

    // MARK: - Encrypt

    static func encrypt(_ plaintext: String, key: SymmetricKey) throws -> EncryptedPayload {
        guard let data = plaintext.data(using: .utf8) else {
            throw CryptoError.encodingFailed
        }
        let sealed = try AES.GCM.seal(data, using: key)
        let ciphertext = sealed.ciphertext + sealed.tag
        let nonce = Data(sealed.nonce)
        return EncryptedPayload(ciphertext: ciphertext, nonce: nonce)
    }

    // MARK: - Decrypt

    static func decrypt(_ payload: EncryptedPayload, key: SymmetricKey) throws -> String {
        guard payload.ciphertext.count > 16 else { throw CryptoError.invalidCiphertext }

        let tag = payload.ciphertext.suffix(16)
        let ct = payload.ciphertext.dropLast(16)
        let nonce = try AES.GCM.Nonce(data: payload.nonce)

        let sealed = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ct, tag: tag)
        let plainData = try AES.GCM.open(sealed, using: key)

        guard let text = String(data: plainData, encoding: .utf8) else {
            throw CryptoError.decodingFailed
        }
        return text
    }
}

enum CryptoError: Error {
    case encodingFailed
    case decodingFailed
    case invalidCiphertext
}
