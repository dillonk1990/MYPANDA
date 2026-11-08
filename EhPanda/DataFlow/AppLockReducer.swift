//
//  AppLockReducer.swift
//  EhPanda
//

import SwiftUI
import ComposableArchitecture

@Reducer
struct AppLockReducer {
    @ObservableState
    struct State: Equatable {
        var blurRadius: Double = 0
        var becameInactiveDate: Date?
        var isAppLocked = false

        // Setting `blurRadius` to zero causes the NavigationBar to collapse
        mutating func setBlurRadius(_ radius: Double) {
            blurRadius = max(0.00001, radius)
        }
    }

    enum Action: Equatable {
        case onBecomeActive(Int, Double)
        case onBecomeInactive(Double)
        case lockApp(Double)
        case unlockApp
        case authorize
        case authorizeDone(Bool)
    }

    @Dependency(\.authorizationClient) private var authorizationClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onBecomeActive(let threshold, let blurRadius):
                if let date = state.becameInactiveDate, threshold >= 0,
                   Date.now.timeIntervalSince(date) >= Double(threshold)
                {
                    return .merge(
                        .send(.authorize),
                        .send(.lockApp(blurRadius))
                    )
                } else {
                    return .send(.unlockApp)
                }

            case .onBecomeInactive(let blurRadius):
                state.setBlurRadius(blurRadius)
                state.becameInactiveDate = .now
                return .none

            case .lockApp(let blurRadius):
                state.setBlurRadius(blurRadius)
                state.isAppLocked = true
                return .none

            case .unlockApp:
                state.setBlurRadius(0)
                state.isAppLocked = false
                state.becameInactiveDate = nil
                return .none

            case .authorize:
                return .run { send in
                    // scenePhase 轉 .active 的瞬間 App 尚未完全回到前台，
                    // 這時呼叫 evaluatePolicy 會被系統靜默拒絕（Face ID 視窗不出現）。
                    // 等一下再觸發，自動與手動點鎖頭兩條路徑都覆蓋。
                    try? await Task.sleep(for: .milliseconds(400))
                    let success = await authorizationClient.localAuthroize(L10n.Localizable.LocalAuthorization.reason)
                    await send(.authorizeDone(success))
                }

            case .authorizeDone(let isSucceeded):
                return isSucceeded ? .send(.unlockApp) : .none
            }
        }
    }
}
