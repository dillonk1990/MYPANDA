//
//  ControlPanel.swift
//  EhPanda
//

import SwiftUI
import Kingfisher

// MARK: ControlPanel
struct ControlPanel<G: Gesture>: View {
    @Binding private var showsPanel: Bool
    @Binding private var showsSliderPreview: Bool
    @Binding private var sliderValue: Float
    @Binding private var setting: Setting
    @Binding private var enablesLiveText: Bool
    @Binding private var autoPlayPolicy: AutoPlayPolicy

    private let range: ClosedRange<Float>
    private let previewURLs: [Int: URL]
    private let dismissGesture: G
    private let dismissAction: () -> Void
    private let navigateSettingAction: () -> Void
    private let reloadAllImagesAction: () -> Void
    private let retryAllFailedImagesAction: () -> Void
    private let fetchPreviewURLsAction: (Int) -> Void

    init(
        showsPanel: Binding<Bool>, showsSliderPreview: Binding<Bool>, sliderValue: Binding<Float>,
        setting: Binding<Setting>, enablesLiveText: Binding<Bool>, autoPlayPolicy: Binding<AutoPlayPolicy>,
        range: ClosedRange<Float>, previewURLs: [Int: URL], dismissGesture: G,
        dismissAction: @escaping () -> Void,
        navigateSettingAction: @escaping () -> Void,
        reloadAllImagesAction: @escaping () -> Void,
        retryAllFailedImagesAction: @escaping () -> Void,
        fetchPreviewURLsAction: @escaping (Int) -> Void
    ) {
        _showsPanel = showsPanel
        _showsSliderPreview = showsSliderPreview
        _sliderValue = sliderValue
        _setting = setting
        _enablesLiveText = enablesLiveText
        _autoPlayPolicy = autoPlayPolicy
        self.range = range
        self.previewURLs = previewURLs
        self.dismissGesture = dismissGesture
        self.dismissAction = dismissAction
        self.navigateSettingAction = navigateSettingAction
        self.reloadAllImagesAction = reloadAllImagesAction
        self.retryAllFailedImagesAction = retryAllFailedImagesAction
        self.fetchPreviewURLsAction = fetchPreviewURLsAction
    }

    private var title: String {
        ["\(max(Int(sliderValue), 1))", "\(Int(range.upperBound))"].joined(separator: " / ")
    }

    var body: some View {
        ZStack {
            VStack {
                if !Self.usesSideControlBar {
                    UpperPanel(
                        title: title,
                        setting: $setting,
                        enablesLiveText: $enablesLiveText,
                        autoPlayPolicy: $autoPlayPolicy,
                        dismissAction: dismissAction,
                        navigateSettingAction: navigateSettingAction,
                        reloadAllImagesAction: reloadAllImagesAction,
                        retryAllFailedImagesAction: retryAllFailedImagesAction
                    )
                    .offset(y: showsPanel ? 0 : -50)
                }
                Spacer()
                if range.upperBound > range.lowerBound {
                    LowerPanel(
                        showsSliderPreview: $showsSliderPreview,
                        sliderValue: $sliderValue, previewURLs: previewURLs, range: range,
                        isReversed: setting.readingDirection == .rightToLeft,
                        dismissGesture: dismissGesture, dismissAction: dismissAction,
                        fetchPreviewURLsAction: fetchPreviewURLsAction,
                        dismissButtonHidden: Self.usesSideControlBar
                    )
                    .padding(.bottom, 24)
                    .animation(.default, value: showsSliderPreview)
                    .offset(y: showsPanel ? 0 : 50)
                }
            }

            if Self.usesSideControlBar {
                GeometryReader { geo in
                    let onLeading = Self.sideBarOnLeading(in: geo)
                    let topPad = Self.sideBarTopInset(in: geo)
                    let centered = Self.isVerticallyCentered(in: geo)
                    // 直式全螢幕：控制欄貼右緣（IMG_0298 使用者指定往右靠邊）。
                    let sidePad = centered ? 16 : Self.sideBarSideInset(in: geo, onLeading: onLeading)
                    SideControlBar(
                        title: title,
                        setting: $setting,
                        enablesLiveText: $enablesLiveText,
                        autoPlayPolicy: $autoPlayPolicy,
                        dismissAction: dismissAction,
                        navigateSettingAction: navigateSettingAction,
                        reloadAllImagesAction: reloadAllImagesAction,
                        retryAllFailedImagesAction: retryAllFailedImagesAction
                    )
                    .frame(width: 46, alignment: .top)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: centered ? .trailing : (onLeading ? .topLeading : .topTrailing)
                    )
                    .padding(onLeading ? .leading : .trailing, sidePad)
                    .padding(.top, centered ? 0 : topPad)
                    .offset(y: showsPanel ? 0 : -40)
                }
            }
        }
        .opacity(showsPanel ? 1 : 0).disabled(!showsPanel)
    }

    /// On iPhone with iOS 27.1+ (iPhone Duo style system UI with vertical side
    /// controls), place the reading toolbar vertically along the trailing edge,
    /// per Apple's "Designing for iPhone Duo" guidance.
    static var usesSideControlBar: Bool {
        if #available(iOS 27.1, *) {
            return DeviceUtil.isPhone
        }
        return false
    }

    /// Duo 模式控制條放哪一側（IMG_0302 使用者糾正：左半邊釘選要放回左緣/外緣，
    /// wip5 的「一律右緣」是誤會，恢復 wip4 的三訊號判斷）：
    /// 1) 摺痕(division) region 偏右 → 本窗是左半邊 → 控制條放左緣（外緣）。
    /// 2) 系統狀態膠囊(occlusion)在本視窗內 → 這是膠囊那側（右）→ 維持右緣。
    /// 3) 窄窗（內屏 pane 寬度）且看不到狀態膠囊 → 左半邊 → 控制條放左緣。
    static func sideBarOnLeading(in proxy: GeometryProxy) -> Bool {
        guard #available(iOS 27.1, *) else { return false }
        let width = proxy.size.width
        for region in proxy.reservedRegions(kind: .division, options: .includeInactive) where region.isActive {
            guard region.frame.width > 0 else { continue }
            if region.frame.midX > width * 0.6 { return true }
            if region.frame.midX < width * 0.4 { return false }
        }
        for region in proxy.reservedRegions(kind: .occlusion, options: .includeInactive) where region.isActive {
            guard region.frame.width > 0, region.frame.height > 0 else { continue }
            return false
        }
        return width >= 430 && width < 550
    }

    /// 側邊控制條的頂部間距：起點落在系統狀態群（時鐘/訊號圈）預留區下緣 +12pt。
    /// （不做封頂：封頂曾把控制條頂進預留區，✕ 被系統訊號圈擋住——IMG_0294 實測。）
    static func sideBarTopInset(in proxy: GeometryProxy) -> CGFloat {
        if #available(iOS 27.1, *) {
            var lowest: CGFloat = -1
            for region in proxy.reservedRegions(kind: .occlusion, options: .includeInactive) where region.isActive {
                guard region.frame.width > 0, region.frame.height > 0 else { continue }
                guard region.frame.midY < proxy.size.height * 0.35 else { continue }
                lowest = max(lowest, region.frame.maxY)
            }
            if lowest >= 0 { return max(lowest + 12, proxy.safeAreaInsets.top + 12) }
        }
        // 釘選 pane 這一側看不到狀態圖：用右半邊實測值（預留區下緣 112pt + 12pt）對稱。
        if proxy.size.width >= 430 && proxy.size.width < 550 { return 124 }
        return proxy.safeAreaInsets.top + 16
    }

    /// 直式全螢幕：控制條放右緣垂直置中（使用者指定位置），不貼頂部狀態群。
    static func isVerticallyCentered(in proxy: GeometryProxy) -> Bool {
        let width = proxy.size.width
        let isPaneMode = width >= 430 && width < 550
        return proxy.size.height > width && !isPaneMode
    }

    /// 側邊控制條的水平內縮：讓按鈕列的中軸對齊同側狀態圖（時鐘/訊號圈）的中心 x，
    /// 使「✕」正好排在訊號圈正下方同一條直線上。
    /// 取「最寬」的同側頂部狀態區（訊號圈寬度大於時鐘文字/投影圖示，最不易被拉偏）。
    static func sideBarSideInset(in proxy: GeometryProxy, onLeading: Bool) -> CGFloat {
        let width = proxy.size.width
        if #available(iOS 27.1, *) {
            var chosen: CGRect?
            for region in proxy.reservedRegions(kind: .occlusion, options: .includeInactive) where region.isActive {
                let f = region.frame
                guard f.width > 0, f.height > 0, f.midY < proxy.size.height * 0.35 else { continue }
                let sameSide = onLeading ? f.midX < width * 0.4 : f.midX > width * 0.6
                guard sameSide else { continue }
                if chosen == nil || f.width > chosen!.width { chosen = f }
            }
            if let f = chosen {
                let pad = onLeading ? f.midX - 23 : width - f.midX - 23
                if pad > -60 && pad < 220 { return min(max(pad, 0), 220) }
            }
        }
        // 這一側看不到狀態圖：鏡像右半邊實測位置（按鈕列中心距右緣 ≈82pt）→ 內縮 59pt。
        if width >= 430 && width < 550 { return 59 }
        return 10
    }
}

// MARK: UpperPanel
private struct UpperPanel: View {
    @Binding private var setting: Setting
    @Binding private var enablesLiveText: Bool
    @Binding private var autoPlayPolicy: AutoPlayPolicy

    private let title: String
    private let dismissAction: () -> Void
    private let navigateSettingAction: () -> Void
    private let reloadAllImagesAction: () -> Void
    private let retryAllFailedImagesAction: () -> Void

    @State private var duoReservedTrailing: CGFloat = 0

    init(
        title: String,
        setting: Binding<Setting>,
        enablesLiveText: Binding<Bool>,
        autoPlayPolicy: Binding<AutoPlayPolicy>,
        dismissAction: @escaping () -> Void,
        navigateSettingAction: @escaping () -> Void,
        reloadAllImagesAction: @escaping () -> Void,
        retryAllFailedImagesAction: @escaping () -> Void
    ) {
        self.title = title
        _setting = setting
        _enablesLiveText = enablesLiveText
        _autoPlayPolicy = autoPlayPolicy
        self.dismissAction = dismissAction
        self.navigateSettingAction = navigateSettingAction
        self.reloadAllImagesAction = reloadAllImagesAction
        self.retryAllFailedImagesAction = retryAllFailedImagesAction
    }

    var body: some View {
        HStack {
            HStack(spacing: 16) {
                Button(action: dismissAction) {
                    Image(systemSymbol: .xmark)
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .glassEffect(.regular.interactive())

                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .lineLimit(1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassEffect(.regular.interactive())
            }

            Spacer()

            HStack(spacing: 20) {
                Button {
                    enablesLiveText.toggle()
                } label: {
                    Image(systemSymbol: .viewfinderCircle)
                        .symbolVariant(enablesLiveText ? .fill : .none)
                        .font(.title2)
                }

                if DeviceUtil.isLandscape && setting.readingDirection != .vertical {
                    Menu {
                        Button {
                            setting.enablesDualPageMode.toggle()
                        } label: {
                            Text(L10n.Localizable.ReadingView.ToolbarItem.Title.dualPageMode)
                            if setting.enablesDualPageMode {
                                Image(systemSymbol: .checkmark)
                            }
                        }
                        Button {
                            setting.exceptCover.toggle()
                        } label: {
                            Text(L10n.Localizable.ReadingView.ToolbarItem.Title.exceptTheCover)
                            if setting.exceptCover {
                                Image(systemSymbol: .checkmark)
                            }
                        }
                        .disabled(!setting.enablesDualPageMode)
                    } label: {
                        Image(systemSymbol: .rectangleSplit2x1)
                            .symbolVariant(setting.enablesDualPageMode ? .fill : .none)
                            .font(.title2)
                    }
                }

                Menu {
                    Text(L10n.Localizable.ReadingView.ToolbarItem.Title.autoPlay).foregroundColor(.secondary)
                    ForEach(AutoPlayPolicy.allCases) { policy in
                        Button {
                            autoPlayPolicy = policy
                        } label: {
                            Text(policy.value)
                            if autoPlayPolicy == policy {
                                Image(systemSymbol: .checkmark)
                            }
                        }
                    }
                } label: {
                    Image(systemSymbol: .timer)
                        .font(.title2)
                }
                .buttonStyle(.borderless)

                ToolbarFeaturesMenu {
                    Button(action: retryAllFailedImagesAction) {
                        Image(systemSymbol: .exclamationmarkArrowTriangle2Circlepath)
                        Text(L10n.Localizable.ReadingView.ToolbarItem.Button.retryAllFailedImages)
                    }
                    Button(action: reloadAllImagesAction) {
                        Image(systemSymbol: .arrowCounterclockwise)
                        Text(L10n.Localizable.ReadingView.ToolbarItem.Button.reloadAllImages)
                    }
                    Button(action: navigateSettingAction) {
                        Image(systemSymbol: .gear)
                        Text(L10n.Localizable.ReadingView.ToolbarItem.Button.readingSetting)
                    }
                }
                .buttonStyle(.borderless)
                .font(.title2)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .glassEffect(.regular.interactive())
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 20)
        .padding(.trailing, duoReservedTrailing)
        .background(alignment: .topLeading) {
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: DuoReservedTrailingKey.self,
                        value: Self.duoReservedTrailing(in: proxy)
                    )
            }
        }
        .onPreferenceChange(DuoReservedTrailingKey.self) { duoReservedTrailing = $0 }
    }

    /// Extra trailing inset so the right-side toolbar icons stay clear of system
    /// reserved regions (iPhone Duo vertical status cluster / front camera).
    /// Uses the iOS 27.1 ReservedRegion API; returns 0 on older systems.
    private static func duoReservedTrailing(in proxy: GeometryProxy) -> CGFloat {
        guard #available(iOS 27.1, *) else { return 0 }
        let width = proxy.size.width
        var needed: CGFloat = 0
        for region in proxy.reservedRegions(kind: .occlusion, options: .includeInactive) where region.isActive {
            guard region.frame.midX > width / 2, region.frame.width > 0 else { continue }
            // Subtract the 20pt base padding already applied, keep an 8pt visual gap.
            needed = max(needed, width - region.frame.minX - 20 + 8)
        }
        return Swift.max(0, needed)
    }
}

// MARK: DuoReservedTrailingKey
private struct DuoReservedTrailingKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = Swift.max(value, nextValue())
    }
}

// MARK: SideControlBar
private struct SideControlBar: View {
    @Binding private var setting: Setting
    @Binding private var enablesLiveText: Bool
    @Binding private var autoPlayPolicy: AutoPlayPolicy

    private let title: String
    private let dismissAction: () -> Void
    private let navigateSettingAction: () -> Void
    private let reloadAllImagesAction: () -> Void
    private let retryAllFailedImagesAction: () -> Void

    init(
        title: String,
        setting: Binding<Setting>,
        enablesLiveText: Binding<Bool>,
        autoPlayPolicy: Binding<AutoPlayPolicy>,
        dismissAction: @escaping () -> Void,
        navigateSettingAction: @escaping () -> Void,
        reloadAllImagesAction: @escaping () -> Void,
        retryAllFailedImagesAction: @escaping () -> Void
    ) {
        self.title = title
        _setting = setting
        _enablesLiveText = enablesLiveText
        _autoPlayPolicy = autoPlayPolicy
        self.dismissAction = dismissAction
        self.navigateSettingAction = navigateSettingAction
        self.reloadAllImagesAction = reloadAllImagesAction
        self.retryAllFailedImagesAction = retryAllFailedImagesAction
    }

    var body: some View {
        VStack(spacing: 10) {
            Button(action: dismissAction) {
                Image(systemSymbol: .xmark)
                    .font(.title3)
                    .frame(width: 46, height: 46)
            }
            .glassEffect(.regular.interactive(), in: Circle())

            Text(title)
                .font(.footnote)
                .fontWeight(.bold)
                .monospacedDigit()
                .fixedSize()
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .glassEffect(.regular, in: Capsule())

            Button {
                enablesLiveText.toggle()
            } label: {
                Image(systemSymbol: .viewfinderCircle)
                    .symbolVariant(enablesLiveText ? .fill : .none)
                    .font(.title3)
                    .frame(width: 46, height: 46)
            }
            .glassEffect(.regular.interactive(), in: Circle())

            if DeviceUtil.isLandscape && setting.readingDirection != .vertical {
                Menu {
                    Button {
                        setting.enablesDualPageMode.toggle()
                    } label: {
                        Text(L10n.Localizable.ReadingView.ToolbarItem.Title.dualPageMode)
                        if setting.enablesDualPageMode {
                            Image(systemSymbol: .checkmark)
                        }
                    }
                    Button {
                        setting.exceptCover.toggle()
                    } label: {
                        Text(L10n.Localizable.ReadingView.ToolbarItem.Title.exceptTheCover)
                        if setting.exceptCover {
                            Image(systemSymbol: .checkmark)
                        }
                    }
                    .disabled(!setting.enablesDualPageMode)
                } label: {
                    Image(systemSymbol: .rectangleSplit2x1)
                        .symbolVariant(setting.enablesDualPageMode ? .fill : .none)
                        .font(.title3)
                        .frame(width: 46, height: 46)
                }
                .glassEffect(.regular.interactive(), in: Circle())
            }

            Menu {
                Text(L10n.Localizable.ReadingView.ToolbarItem.Title.autoPlay).foregroundColor(.secondary)
                ForEach(AutoPlayPolicy.allCases) { policy in
                    Button {
                        autoPlayPolicy = policy
                    } label: {
                        Text(policy.value)
                        if autoPlayPolicy == policy {
                            Image(systemSymbol: .checkmark)
                        }
                    }
                }
            } label: {
                Image(systemSymbol: .timer)
                    .font(.title3)
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(.borderless)
            .glassEffect(.regular.interactive(), in: Circle())

            ToolbarFeaturesMenu {
                Button(action: retryAllFailedImagesAction) {
                    Image(systemSymbol: .exclamationmarkArrowTriangle2Circlepath)
                    Text(L10n.Localizable.ReadingView.ToolbarItem.Button.retryAllFailedImages)
                }
                Button(action: reloadAllImagesAction) {
                    Image(systemSymbol: .arrowCounterclockwise)
                    Text(L10n.Localizable.ReadingView.ToolbarItem.Button.reloadAllImages)
                }
                Button(action: navigateSettingAction) {
                    Image(systemSymbol: .gear)
                    Text(L10n.Localizable.ReadingView.ToolbarItem.Button.readingSetting)
                }
            }
            .buttonStyle(.borderless)
            .font(.title3)
            .frame(width: 46, height: 46)
            .glassEffect(.regular.interactive(), in: Circle())
        }
        .foregroundStyle(.primary)
    }
}

// MARK: LowerPanel
private struct LowerPanel<G: Gesture>: View {
    @Environment(\.readingContainerWidth) private var containerWidth
    @Binding private var showsSliderPreview: Bool
    @Binding private var sliderValue: Float
    private let previewURLs: [Int: URL]
    private let range: ClosedRange<Float>
    private let isReversed: Bool
    private let dismissGesture: G
    private let dismissAction: () -> Void
    private let fetchPreviewURLsAction: (Int) -> Void
    private let dismissButtonHidden: Bool

    init(
        showsSliderPreview: Binding<Bool>, sliderValue: Binding<Float>,
        previewURLs: [Int: URL], range: ClosedRange<Float>, isReversed: Bool,
        dismissGesture: G, dismissAction: @escaping () -> Void,
        fetchPreviewURLsAction: @escaping (Int) -> Void,
        dismissButtonHidden: Bool
    ) {
        _showsSliderPreview = showsSliderPreview
        _sliderValue = sliderValue
        self.previewURLs = previewURLs
        self.range = range
        self.isReversed = isReversed
        self.dismissGesture = dismissGesture
        self.dismissAction = dismissAction
        self.fetchPreviewURLsAction = fetchPreviewURLsAction
        self.dismissButtonHidden = dismissButtonHidden
    }

    var body: some View {
        VStack(spacing: dismissButtonHidden ? 0 : 30) {
            if !dismissButtonHidden {
                Button(action: dismissAction) {
                    Image(systemSymbol: .xmark)
                        .foregroundColor(.primary)
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .glassEffect(.regular.interactive())
                .gesture(dismissGesture)
                .opacity(showsSliderPreview ? 0 : 1)
            }

            VStack(spacing: 0) {
                SliderPreivew(
                    showsSliderPreview: $showsSliderPreview,
                    sliderValue: $sliderValue,
                    previewURLs: previewURLs,
                    range: range,
                    isReversed: isReversed,
                    fetchPreviewURLsAction: fetchPreviewURLsAction
                )

                HStack {
                    Text(isReversed ? "\(Int(range.upperBound))" : "\(Int(range.lowerBound))")
                        .fontWeight(.medium)
                        .font(.caption)
                        .padding()

                    Slider(
                        value: $sliderValue,
                        in: range,
                        onEditingChanged: { if !$0 { showsSliderPreview = false } }
                    )
                    .frame(width: (containerWidth > 0 ? containerWidth : DeviceUtil.windowW) * 0.6)
                    .rotationEffect(.init(degrees: isReversed ? 180 : 0))
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity)
                            .onChanged({ if $0 { showsSliderPreview = true } })
                    )

                    Text(isReversed ? "\(Int(range.lowerBound))" : "\(Int(range.upperBound))")
                        .fontWeight(.medium)
                        .font(.caption)
                        .padding()
                }
            }
            .glassEffect(in: .rect(cornerRadius: 16))
            .padding(.horizontal, SliderPreivew.outerPadding)
        }
    }
}

// MARK: SliderPreview
private struct SliderPreivew: View {
    @Environment(\.readingContainerWidth) private var containerWidth
    @Binding private var showsSliderPreview: Bool
    @Binding var sliderValue: Float
    private let previewURLs: [Int: URL]
    private let range: ClosedRange<Float>
    private let isReversed: Bool
    private let fetchPreviewURLsAction: (Int) -> Void

    static let outerPadding: CGFloat = 8

    init(
        showsSliderPreview: Binding<Bool>,
        sliderValue: Binding<Float>,
        previewURLs: [Int: URL],
        range: ClosedRange<Float>,
        isReversed: Bool,
        fetchPreviewURLsAction: @escaping (Int) -> Void
    ) {
        _showsSliderPreview = showsSliderPreview
        _sliderValue = sliderValue
        self.previewURLs = previewURLs
        self.range = range
        self.isReversed = isReversed
        self.fetchPreviewURLsAction = fetchPreviewURLsAction
    }

    var body: some View {
        HStack(spacing: previewSpacing) {
            ForEach(previewsIndices, id: \.self) { index in
                let (url, modifier) = PreviewResolver.getPreviewConfigs(originalURL: previewURLs[index])
                VStack {
                    KFImage.url(url, cacheKey: previewURLs[index]?.absoluteString)
                        .placeholder({ Placeholder(style: .activity(ratio: Defaults.ImageSize.previewAspect)) })
                        .fade(duration: 0.25)
                        .imageModifier(modifier)
                        .resizable()
                        .scaledToFit()
                        .frame(width: previewWidth, height: showsSliderPreview ? previewHeight : 0)

                    Text("\(index)")
                        .font(DeviceUtil.isPadWidth ? .callout : .caption)
                        .foregroundColor(index == Int(sliderValue) ? .accentColor : .secondary)
                }
                .onAppear {
                    if previewURLs[index] == nil && checkIndex(index) {
                        fetchPreviewURLsAction(index)
                    }
                }
                .opacity(checkIndex(index) ? 1 : 0)
            }
        }
        .opacity(showsSliderPreview ? 1 : 0)
        .padding(.vertical, verticalPadding)
        .padding(.horizontal, horizontalPadding)
        .frame(height: showsSliderPreview ? previewHeight + verticalPadding * 2 : 0)
    }
}

private extension SliderPreivew {
    var verticalPadding: CGFloat {
        DeviceUtil.isPadWidth ? 30 : 20
    }
    var horizontalPadding: CGFloat { verticalPadding * 0.5 }
    var previewsCount: Int {
        DeviceUtil.isPadWidth ? DeviceUtil.isLandscape ? 7 : 5 : 3
    }
    var previewsIndices: [Int] {
        guard !previewURLs.isEmpty else { return [] }
        let currentIndex = Int(sliderValue)
        let distance = (previewsCount - 1) / 2
        let lowerBound = currentIndex - distance
        let upperBound = currentIndex + distance

        let indices = Array(lowerBound...upperBound)
        return isReversed ? indices.reversed() : indices
    }
    var previewSpacing: CGFloat { 10 }
    var previewHeight: CGFloat {
        previewWidth / Defaults.ImageSize.previewAspect
    }
    var previewWidth: CGFloat {
        guard previewsCount > 0 else { return 0 }
        let count = CGFloat(previewsCount)
        let spacing = (count + 1) * previewSpacing + horizontalPadding * 2 + Self.outerPadding * 2
        let base = containerWidth > 0 ? containerWidth : DeviceUtil.windowW
        return (base - spacing) / count
    }
    func checkIndex(_ index: Int) -> Bool {
        index >= Int(range.lowerBound) && index <= Int(range.upperBound)
    }
}
