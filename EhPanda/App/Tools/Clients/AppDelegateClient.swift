//
//  AppDelegateClient.swift
//  EhPanda
//

import SwiftUI
import ComposableArchitecture

struct AppDelegateClient {
    let setOrientation: @MainActor (UIInterfaceOrientationMask) -> Void
    /// nil = 清除覆蓋、跟隨即時寬度預設
    let setOrientationMask: (UIInterfaceOrientationMask?) -> Void
}

extension AppDelegateClient {
    static let live: Self = .init(
        setOrientation: { mask in
            DeviceUtil.keyWindow?.windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
        },
        setOrientationMask: { mask in
            AppDelegate.orientationMaskOverride = mask
        }
    )

    @MainActor
    func setPortraitOrientation() {
        // 寬視窗（摺疊內屏、iPad）不強制轉直向，避免產生黑邊
        guard !DeviceUtil.isWideWidth else { return }
        setOrientation(.portrait)
    }
    func setAllOrientationMask() {
        setOrientationMask([.all])
    }
    func setPortraitOrientationMask() {
        // 寬視窗改用即時預設（允許全方向）；窄視窗維持鎖直向
        if DeviceUtil.isWideWidth {
            setOrientationMask(nil)
        } else {
            setOrientationMask([.portrait, .portraitUpsideDown])
        }
    }
}

// MARK: API
enum AppDelegateClientKey: DependencyKey {
    static let liveValue = AppDelegateClient.live
    static let previewValue = AppDelegateClient.noop
    static let testValue = AppDelegateClient.unimplemented
}

extension DependencyValues {
    var appDelegateClient: AppDelegateClient {
        get { self[AppDelegateClientKey.self] }
        set { self[AppDelegateClientKey.self] = newValue }
    }
}

// MARK: Test
extension AppDelegateClient {
    static let noop: Self = .init(
        setOrientation: { _ in },
        setOrientationMask: { _ in }
    )

    static func placeholder<Result>() -> Result { fatalError() }

    static let unimplemented: Self = .init(
        setOrientation: IssueReporting.unimplemented(placeholder: placeholder()),
        setOrientationMask: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
