import Foundation
import CryptoKit

public enum UpdateSignature {
    public static func verify(
        fileData: Data,
        signatureBase64: String,
        publicKeyBase64: String
    ) -> Bool {
        guard let signatureData = Data(base64Encoded: signatureBase64),
              let keyData = Data(base64Encoded: publicKeyBase64),
              let publicKey = try? Curve25519.Signing.PublicKey(
                  rawRepresentation: keyData
              ) else {
            return false
        }
        return publicKey.isValidSignature(signatureData, for: fileData)
    }
}
