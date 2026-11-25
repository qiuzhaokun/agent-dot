import Foundation
import CryptoKit

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(
        Data("usage: AGENTDOT_UPDATE_PRIVATE_KEY=<base64> sign-update.swift <zip>\n".utf8)
    )
    exit(2)
}

let zipURL = URL(fileURLWithPath: CommandLine.arguments[1])
guard let rawKey = ProcessInfo.processInfo.environment["AGENTDOT_UPDATE_PRIVATE_KEY"],
      !rawKey.isEmpty else {
    FileHandle.standardError.write(
        Data("AGENTDOT_UPDATE_PRIVATE_KEY is required\n".utf8)
    )
    exit(1)
}

do {
    let trimmed = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let keyData = Data(base64Encoded: trimmed),
          let key = try? Curve25519.Signing.PrivateKey(
              rawRepresentation: keyData
          ) else {
        FileHandle.standardError.write(Data("invalid private key\n".utf8))
        exit(1)
    }
    let data = try Data(contentsOf: zipURL)
    let signature = try key.signature(for: data)
    print(signature.base64EncodedString())
} catch {
    FileHandle.standardError.write(
        Data("sign-update failed: \(error)\n".utf8)
    )
    exit(1)
}
