//
//  DeviceUtil.swift
//  EhPanda
//

import SwiftUI
import Foundation

struct DeviceUtil {
    static var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    static var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    static var isPadWidth: Bool {
        windowW >= 744
    }

    // 視窗目前的實際寬度（會隨轉向、摺疊開合變化）
    static var presentWindowW: CGFloat {
        keyWindow?.frame.size.width ?? absScreenW
    }

    // 視窗目前的實際高度
    static var presentWindowH: CGFloat {
        keyWindow?.frame.size.height ?? absScreenH
    }

    // size class 判斷：iPhone Duo 內屏（含半摺）為 regular，外屏為 compact。
    // 內屏 pt 尺寸與外屏幾乎相同（4x 縮放），不能用 pt 寬度辨識
    static var isInRegularWidth: Bool {
        keyWindow?.traitCollection.horizontalSizeClass == .regular
    }

    // 寬版模式：iPad、或 size class 為 regular 的寬容器（摺疊內屏）
    static var isWideWidth: Bool {
        isInRegularWidth || presentWindowW >= 550
    }

    // 雙頁模式觸發條件：橫向 或 寬度足夠（摺疊內屏直向也夠寬）
    static var dualPageCapable: Bool {
        isLandscape || isWideWidth
    }

    static var isSEWidth: Bool {
        windowW <= 320
    }

    static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .compactMap({ $0 as? UIWindowScene }).last?
            .windows.filter({ $0.isKeyWindow }).last
    }

    // Duo 雙開/釘選模式：視窗被釘在螢幕左半邊時回 true（控制條要換到左緣）
    static var snapsToLeadingEdge: Bool {
        guard let scene = keyWindow?.windowScene else { return false }
        if #available(iOS 17.0, *) {
            let pane = scene.effectiveGeometry.displayBounds
            let display = scene.effectiveGeometry.device.screen.bounds
            let full = max(display.width, display.height)
            let isHalfPane = pane.width < full * 0.8
            return isHalfPane && pane.origin.x < full * 0.25
        }
        return false
    }
    static var anyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).last?
            .windows.last
    }

    static var isLandscape: Bool {
        // iPhone Duo 上 Apple 明確建議：不要靠 interfaceOrientation 判斷方向，
        // 直接比較視窗幾何的寬高
        presentWindowW > presentWindowH
    }

    static var isPortrait: Bool {
        presentWindowW <= presentWindowH
    }

    static var windowW: CGFloat {
        min(absWindowW, absWindowH)
    }

    static var windowH: CGFloat {
        max(absWindowW, absWindowH)
    }

    static var screenW: CGFloat {
        min(absScreenW, absScreenH)
    }

    static var screenH: CGFloat {
        max(absScreenW, absScreenH)
    }

    static var absWindowW: CGFloat {
        keyWindow?.frame.size.width ?? absScreenW
    }

    static var absWindowH: CGFloat {
        keyWindow?.frame.size.height ?? absScreenH
    }

    static var absScreenW: CGFloat {
        UIScreen.main.bounds.size.width
    }

    static var absScreenH: CGFloat {
        UIScreen.main.bounds.size.height
    }
}
