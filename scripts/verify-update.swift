import Foundation
import CryptoKit

guard CommandLine.arguments.count == 4 else {
    FileHandle.standardError.write(
        Data("usage: verify-update.swift <zip> <signature-base64> <public-key-base64>\n".utf8)
    )
    exit(2)
}

let zipURL = URL(fileURLWithPath: CommandLine.arguments[1])
guard let signature = Data(base64Encoded: CommandLine.arguments[2]),
      let publicKeyData = Data(base64Encoded: CommandLine.arguments[3]),
      let publicKey = try? Curve25519.Signing.PublicKey(
          rawRepresentation: publicKeyData
      ) else {
    FileHandle.standardError.write(Data("invalid signature or public key\n".utf8))
    exit(1)
}

do {
    let data = try Data(contentsOf: zipURL)
    if publicKey.isValidSignature(signature, for: data) {
        print("OK")
        exit(0)
    }
    FileHandle.standardError.write(Data("signature verification failed\n".utf8))
    exit(1)
} catch {
    FileHandle.standardError.write(
        Data("verify-update failed: \(error)\n".utf8)
    )
    exit(1)
}
