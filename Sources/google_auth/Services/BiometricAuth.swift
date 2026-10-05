import Foundation
import LocalAuthentication

@MainActor
public final class BiometricAuth: ObservableObject {
    public static let shared = BiometricAuth()

    @Published public var isUnlocked: Bool = true
    @Published public var canUseBiometrics: Bool = false

    private init() {
        checkBiometricAvailability()
    }

    public func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        canUseBiometrics = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    public func authenticate(reason: String = "请验证身份以解锁 Google Authenticator", completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        let context = LAContext()
        context.localizedCancelTitle = "取消"

        var error: NSError?
        let policy: LAPolicy = .deviceOwnerAuthentication

        if context.canEvaluatePolicy(policy, error: &error) {
            context.evaluatePolicy(policy, localizedReason: reason) { success, _ in
                Task { @MainActor in
                    self.isUnlocked = success
                    completion(success)
                }
            }
        } else {
            // Biometrics / passcode not available, allow pass
            self.isUnlocked = true
            completion(true)
        }
    }

    public func lock() {
        isUnlocked = false
    }
}
