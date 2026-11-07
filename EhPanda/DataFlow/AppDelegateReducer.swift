//
//  AppDelegateReducer.swift
//  EhPanda
//

import SwiftUI
import SwiftyBeaver
import ComposableArchitecture

@Reducer
struct AppDelegateReducer {
    @ObservableState
    struct State: Equatable {
        var migrationState = MigrationReducer.State()
    }

    enum Action: Equatable {
        case onLaunchFinish
        case removeExpiredImageURLs

        case migration(MigrationReducer.Action)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.libraryClient) private var libraryClient
    @Dependency(\.cookieClient) private var cookieClient

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .onLaunchFinish:
                return .merge(
                    .run(operation: { _ in libraryClient.initializeLogger() }),
                    .run(operation: { _ in libraryClient.initializeWebImage() }),
                    .run(operation: { _ in cookieClient.removeYay() }),
                    .run(operation: { _ in cookieClient.syncExCookies() }),
                    .run(operation: { _ in cookieClient.ignoreOffensive() }),
                    .run(operation: { _ in cookieClient.fulfillAnotherHostField() }),
                    .send(.migration(.prepareDatabase))
                )

            case .removeExpiredImageURLs:
                return .run(operation: { _ in await databaseClient.removeExpiredImageURLs() })

            case .migration:
                return .none
            }
        }

        Scope(state: \.migrationState, action: \.migration, child: MigrationReducer.init)
    }
}

// MARK: AppDelegate
class AppDelegate: UIResponder, UIApplicationDelegate {
    let store = Store(initialState: .init()) {
        AppReducer()
    }

    /// 由閱讀/設定頁面明確指定的方向覆蓋值；nil 表示跟隨即時寬度預設
    static var orientationMaskOverride: UIInterfaceOrientationMask?

    /// 即時預設：寬視窗（iPad、摺疊內屏）允許全部方向，窄視窗（外屏、一般手機）鎖直向
    static var defaultOrientationMask: UIInterfaceOrientationMask {
        DeviceUtil.isWideWidth ? .all : [.portrait, .portraitUpsideDown]
    }

    static var orientationMask: UIInterfaceOrientationMask {
        orientationMaskOverride ?? defaultOrientationMask
    }

    func application(
        _ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask { AppDelegate.orientationMask }

    func application(
        _ application: UIApplication, didFinishLaunchingWithOptions
        launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if !AppUtil.isTesting {
            store.send(.appDelegate(.onLaunchFinish))
        }
        return true
    }
}
