//
//  AuthorizationClient.swift
//  EhPanda
//

import Combine
import LocalAuthentication
import ComposableArchitecture

struct AuthorizationClient {
    let passcodeNotSet: () -> Bool
    let localAuthroize: (String) async -> Bool
}

extension AuthorizationClient {
    static let live: Self = .init(
        passcodeNotSet: {
            var error: NSError?
            return !LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        },
        localAuthroize: { reason in
            await withCheckedContinuation { continuation in
                let context = LAContext()
                var error: NSError?

                // 生物識別優先：Face ID／Touch ID（依裝置註冊的為準），
                // 不過不放行、不讓裝置密碼頂替。
                if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                    context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { isSuccess, _ in
                        continuation.resume(returning: isSuccess)
                    }
                } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                    // 防呆：裝置完全沒註冊生物識別時退回系統層（裝置密碼），
                    // 否則使用者会被永久鎖在門外。
                    context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { isSuccess, _ in
                        continuation.resume(returning: isSuccess)
                    }
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
    )
}

// MARK: API
enum AuthorizationClientKey: DependencyKey {
    static let liveValue = AuthorizationClient.live
    static let previewValue = AuthorizationClient.noop
    static let testValue = AuthorizationClient.unimplemented
}

extension DependencyValues {
    var authorizationClient: AuthorizationClient {
        get { self[AuthorizationClientKey.self] }
        set { self[AuthorizationClientKey.self] = newValue }
    }
}

// MARK: Test
extension AuthorizationClient {
    static let noop: Self = .init(
        passcodeNotSet: { false },
        localAuthroize: { _ in false }
    )

    static func placeholder<Result>() -> Result { fatalError() }

    static let unimplemented: Self = .init(
        passcodeNotSet: IssueReporting.unimplemented(placeholder: placeholder()),
        localAuthroize: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
