import Foundation
import CryptoKit

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(
        Data("usage: generate-update-key.swift <private-key-output-path>\n".utf8)
    )
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let fileManager = FileManager.default
guard !fileManager.fileExists(atPath: outputURL.path) else {
    FileHandle.standardError.write(
        Data("refusing to overwrite existing key: \(outputURL.path)\n".utf8)
    )
    exit(1)
}

let key = Curve25519.Signing.PrivateKey()
let privateBase64 = key.rawRepresentation.base64EncodedString()
let publicBase64 = key.publicKey.rawRepresentation.base64EncodedString()

try fileManager.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try Data((privateBase64 + "\n").utf8).write(to: outputURL, options: .atomic)
try fileManager.setAttributes(
    [.posixPermissions: 0o600],
    ofItemAtPath: outputURL.path
)

print("PUBLIC_KEY=\(publicBase64)")
print("PRIVATE_KEY_FILE=\(outputURL.path)")
