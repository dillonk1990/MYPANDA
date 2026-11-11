//
//  DuoMotion.swift
//  EhPanda
//
//  全站統一的彈簧動態語言：所有狀態切換都用同一組曲線，
//  讓動畫節奏一致、收尾有微微回彈，接近概念演示的滑順感。
//

import SwiftUI

// MARK: - Shared springs

extension Animation {
    /// 主彈簧：資料/版面切換、面板進出、列表增減
    static let duoSpring = Animation.spring(response: 0.38, dampingFraction: 0.68)
    /// 輕快彈簧：開關、按鈕回饋、小元件狀態變化
    static let duoSpringSnappy = Animation.spring(response: 0.26, dampingFraction: 0.8)
}

// MARK: - Soft card shadow

extension View {
    /// 卡片風共用的柔和陰影：淺而散，讓卡片浮起來
    func duoCardShadow(radius: CGFloat = 8, opacity: Double = 0.10) -> some View {
        shadow(color: Color.black.opacity(opacity), radius: radius, x: 0, y: 4)
    }
}

// MARK: - Chip background

extension Color {
    /// chip／小卡片底色：淺深模式各自適應
    static func duoChip(dark: Bool) -> Color {
        dark ? Color(.systemGray5) : Color(.systemGray6)
    }
}

// MARK: - Press feedback

/// 按壓縮放：按下微微縮小、放開彈回，卡片與按鈕通用的手感
struct DuoPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.955 : 1)
            .animation(.duoSpringSnappy, value: configuration.isPressed)
    }
}
