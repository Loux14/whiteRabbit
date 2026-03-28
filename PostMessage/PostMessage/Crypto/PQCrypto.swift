import SwiftKyber
import SwiftDilithium
import Foundation

enum PQCrypto {

    // MARK: - ML-KEM (key encapsulation)

    static func generateKEMKeyPair() -> (encapKey: Data, decapKey: Data) {
        let (ek, dk) = Kyber.GenerateKeyPair(kind: .K768)
        return (Data(ek.keyBytes), Data(dk.keyBytes))
    }

    // Returns (ciphertext, sharedSecret)
    static func encapsulate(publicKey: Data) throws -> (ciphertext: Data, sharedSecret: Data) {
        let ek = try EncapsulationKey(keyBytes: [UInt8](publicKey))
        let (ss, ct) = ek.Encapsulate()
        return (Data(ct), Data(ss))
    }

    static func decapsulate(ciphertext: Data, privateKey: Data) throws -> Data {
        let dk = try DecapsulationKey(keyBytes: [UInt8](privateKey))
        let ss = try dk.Decapsulate(ct: [UInt8](ciphertext))
        return Data(ss)
    }

    // MARK: - ML-DSA-65 (digital signatures)

    // Returns (verifyKey, signKey)
    static func generateDSAKeyPair() -> (verifyKey: Data, signKey: Data) {
        let (sk, vk) = Dilithium.GenerateKeyPair(kind: .ML_DSA_65)
        return (Data(vk.keyBytes), Data(sk.keyBytes))
    }

    static func signDSA(_ data: Data, privateKey: Data) throws -> Data {
        let sk = try SecretKey(keyBytes: [UInt8](privateKey))
        return Data(sk.Sign(message: [UInt8](data)))
    }

    static func verifyDSA(_ signature: Data, for data: Data, publicKey: Data) -> Bool {
        guard let vk = try? PublicKey(keyBytes: [UInt8](publicKey)) else { return false }
        return vk.Verify(message: [UInt8](data), signature: [UInt8](signature))
    }
}
