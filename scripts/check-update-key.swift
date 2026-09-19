import CryptoKit
import Foundation

let environment = ProcessInfo.processInfo.environment
guard let encoded = environment["SPARKLE_PRIVATE_KEY"], let secret = Data(base64Encoded: encoded.trimmingCharacters(in: .whitespacesAndNewlines)),
      [32, 64].contains(secret.count), let expected = environment["SPARKLE_PUBLIC_KEY"],
      let publicKey = Data(base64Encoded: expected), publicKey.count == 32 else {
    FileHandle.standardError.write(Data("Update signing keys are missing or malformed.\n".utf8))
    exit(1)
}
let key = try Curve25519.Signing.PrivateKey(rawRepresentation: secret.prefix(32))
guard key.publicKey.rawRepresentation == publicKey else {
    FileHandle.standardError.write(Data("Update signing keys do not match.\n".utf8))
    exit(1)
}
print("Update signing keys match.")
