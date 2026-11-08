//
//  ViewModifiers.swift
//  EhPanda
//

import SwiftUI
import Combine
import Kingfisher

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }

    @ViewBuilder func withHorizontalSpacing(width: CGFloat = 8, height: CGFloat? = nil) -> some View {
        Color.clear.frame(width: width, height: height)
        self
        Color.clear.frame(width: width, height: height)
    }

    func withArrow(isVisible: Bool = true) -> some View {
        HStack {
            self
            Spacer()
            Image(systemSymbol: .chevronRight)
                .foregroundColor(.secondary)
                .imageScale(.small)
                .opacity(isVisible ? 0.5 : 0)
        }
    }

    func autoBlur(radius: Double) -> some View {
        blur(radius: radius)
            .allowsHitTesting(radius < 1)
            .animation(.linear(duration: 0.1), value: radius)
    }

    func synchronize<Value: Equatable>(
        _ first: Binding<Value>,
        _ second: Binding<Value>,
        initial: (first: Bool, second: Bool) = (false, false)
    ) -> some View {
        self
            .onChange(of: first.wrappedValue, initial: initial.first) { _, newValue in
                second.wrappedValue = newValue
            }
            .onChange(of: second.wrappedValue, initial: initial.second) { _, newValue in
                first.wrappedValue = newValue
            }
    }

    func synchronize<Value>(
        _ first: Binding<Value>,
        _ second: FocusState<Value>.Binding,
        initial: (first: Bool, second: Bool) = (false, false)
    ) -> some View {
        self
            .onChange(of: first.wrappedValue, initial: initial.first) { _, newValue in
                second.wrappedValue = newValue
            }
            .onChange(of: second.wrappedValue, initial: initial.second) { _, newValue in
                first.wrappedValue = newValue
            }
    }
}

struct PlainLinearProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: ProgressViewStyleConfiguration) -> some View {
        ProgressView(value: CGFloat(configuration.fractionCompleted ?? 0), total: 1)
    }
}
extension ProgressViewStyle where Self == PlainLinearProgressViewStyle {
    static var plainLinear: PlainLinearProgressViewStyle {
        PlainLinearProgressViewStyle()
    }
}

// MARK: Image Modifier
struct CornersModifier: ImageModifier {
    let radius: CGFloat?

    init(radius: CGFloat? = nil) {
        self.radius = radius
    }

    func modify(_ image: KFCrossPlatformImage) -> KFCrossPlatformImage {
        if let radius = radius {
            return image.withRoundedCorners(radius: radius) ?? image
        } else {
            return image
        }
    }
}

struct OffsetModifier: ImageModifier {
    private let size: CGSize?
    private let offset: CGSize?

    init(size: CGSize?, offset: CGSize?) {
        self.size = size
        self.offset = offset
    }

    func modify(_ image: KFCrossPlatformImage) -> KFCrossPlatformImage {
        guard let size = size, let offset = offset
        else { return image }

        return image.cropping(size: size, offset: offset) ?? image
    }
}

struct RoundedOffsetModifier: ImageModifier {
    private let size: CGSize?
    private let offset: CGSize?

    init(size: CGSize?, offset: CGSize?) {
        self.size = size
        self.offset = offset
    }

    func modify(_ image: KFCrossPlatformImage) -> KFCrossPlatformImage {
        guard let size = size, let offset = offset,
              let croppedImg = image.cropping(size: size, offset: offset),
              let roundedCroppedImg = croppedImg.withRoundedCorners(radius: 5)
        else { return image.withRoundedCorners(radius: 5) ?? image }

        return roundedCroppedImg
    }
}

struct WebtoonModifier: ImageModifier {
    private let minAspect: CGFloat
    private let idealAspect: CGFloat

    init(minAspect: CGFloat, idealAspect: CGFloat) {
        self.minAspect = minAspect
        self.idealAspect = idealAspect
    }

    func modify(_ image: KFCrossPlatformImage) -> KFCrossPlatformImage {
        let width = image.size.width
        let height = image.size.height
        let idealHeight = width / idealAspect
        guard width / height < minAspect else { return image }
        return image.cropping(size: CGSize(width: width, height: idealHeight), offset: .zero) ?? image
    }
}

extension KFImage {
    func defaultModifier(withRoundedCorners: Bool = true) -> KFImage {
        self
            .imageModifier(CornersModifier(
                radius: withRoundedCorners ? 5 : nil
            ))
            .fade(duration: 0.25)
            .resizable()
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(
                width: radius,
                height: radius
            )
        )
        return Path(path.cgPath)
    }
}

struct PreviewResolver {
    static func getPreviewConfigs(originalURL: URL?) -> (URL?, ImageModifier) {
        guard let url = originalURL,
              let (plainURL, size, offset) = Parser.parsePreviewConfigs(url: url)
        else {
            return (originalURL, RoundedOffsetModifier(size: nil, offset: nil))
        }
        return (plainURL, RoundedOffsetModifier(size: size, offset: offset))
    }
}

// Duo (iOS 27.1+)：系統把主選單轉成側邊圓形按鈕直欄。
// 系統搜尋介面收合後偶爾忘記把該直欄放回（只有重開 App 才恢復）。
// 觸發時機在「搜尋收合的瞬間」，所以除了進入分頁時補一次，
// 另由 DuoSearchDismissWatcher 偵測 isSearching 由 true→false 發通知，收到再補一次。
extension Notification.Name {
    static let duoSearchSessionEnded = Notification.Name("duoSearchSessionEnded")
}

struct DuoTabBarKeeperModifier: ViewModifier {
    @State private var forceVisible = false

    func body(content: Content) -> some View {
        content
            .toolbar(
                forceVisible ? .visible : .automatic,
                for: .tabBar
            )
            .onAppear { nudge() }
            .onReceive(NotificationCenter.default.publisher(for: .duoSearchSessionEnded)) { _ in
                nudge()
            }
    }

    private func nudge() {
        guard #available(iOS 27.1, *), DeviceUtil.isPhone else { return }
        forceVisible = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            forceVisible = true
        }
    }
}

// 放在 searchable 內容子樹內：搜尋介面收合（isSearching true→false）時發通知。
struct DuoSearchDismissWatcher: View {
    @Environment(\.isSearching) private var isSearching

    var body: some View {
        Color.clear
            .onChange(of: isSearching) { oldValue, newValue in
                guard oldValue && !newValue else { return }
                NotificationCenter.default.post(name: .duoSearchSessionEnded, object: nil)
            }
    }
}

extension View {
    func duoTabBarKeeper() -> some View {
        modifier(DuoTabBarKeeperModifier())
    }
}

// Duo 實驗(B)：app 釘在內屏左半邊時，頂部沒有時鐘/訊號當錨點，
// 系統的側邊圓形按鈕直欄（返回/更多）就從最頂端開始排，看起來比右半邊高。
// 解法一：往頂部插一根隱形墊高柱（110pt），把系統按鈕往下推，讓兩側起點對齊。
// 解法二：左半邊系統還會替圓鈕列保留約 100pt 的「幽靈留白」，內容被擠窄，
//         用等量負邊距抵銷，使左右兩側內容都滿版（欄數一致）。
// 偵測邏輯與閱讀頁側邊控制條相同（三訊號複合判斷）。
// 幾何訊號包裝：Swift 的元組無法直接符合 Equatable 協定，用結構包住供 onChange 比對。
struct DuoGeometrySignature: Equatable {
    let size: CGSize
    let insets: EdgeInsets
}

struct DuoTopSpacerModifier: ViewModifier {
    @State private var showSpacer = false
    @State private var leadingBleed: CGFloat = 0
    @State private var mirrorHeader = false
    @State private var geoSummary = ""

    func body(content: Content) -> some View {
        content
            .padding(.leading, leadingBleed)
            .environment(\.duoMirrorHeader, mirrorHeader)
            .overlay(alignment: .topLeading) {
                // Duo wip 除錯標籤：確認釘選偵測與留白數值；正式發布前移除。
                VStack(alignment: .leading, spacing: 2) {
                    Text("pinL=\(showSpacer ? 1 : 0) bleed=\(Int(leadingBleed)) mirr=\(mirrorHeader ? 1 : 0)")
                    Text(geoSummary)
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.yellow)
                .padding(6)
                .background(Color.black.opacity(0.6))
                .offset(x: 60, y: 8)
                .allowsHitTesting(false)
            }
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { refresh(in: proxy) }
                        .onChange(of: DuoGeometrySignature(size: proxy.size, insets: proxy.safeAreaInsets)) { _, _ in
                            refresh(in: proxy)
                        }
                }
            )
            .toolbar {
                if showSpacer {
                    ToolbarItem(placement: .topBarLeading) {
                        Color.clear
                            .frame(width: 1, height: 124)
                            .allowsHitTesting(false)
                    }
                }
            }
    }

    private func refresh(in proxy: GeometryProxy) {
        let leftPane = Self.isPinnedLeftPane(in: proxy)
        showSpacer = leftPane
        mirrorHeader = leftPane
        // 左半邊：抵銷系統替側邊圓鈕列保留的 leading 安全區（合理範圍內才動作）
        let inset = proxy.safeAreaInsets.leading
        leadingBleed = (leftPane && inset > 24 && inset < 160) ? -inset : 0
        if #available(iOS 27.1, *) {
            var parts: [String] = []
            for region in proxy.reservedRegions(kind: .occlusion, options: .includeInactive) where region.isActive {
                let f = region.frame
                guard f.width > 0, f.height > 0 else { continue }
                parts.append("o\(Int(f.minX)),\(Int(f.minY)) \(Int(f.width))x\(Int(f.height))")
            }
            for region in proxy.reservedRegions(kind: .division, options: .includeInactive) where region.isActive {
                let f = region.frame
                guard f.width > 0, f.height > 0 else { continue }
                parts.append("d\(Int(f.minX)),\(Int(f.minY)) \(Int(f.width))x\(Int(f.height))")
            }
            geoSummary = "w=\(Int(proxy.size.width)) L\(Int(proxy.safeAreaInsets.leading)) R\(Int(proxy.safeAreaInsets.trailing)) "
                + (parts.isEmpty ? "none" : parts.joined(separator: "|"))
        }
    }

    // 三訊號複合判斷：
    // 1) 摺痕 region 偏右 -> 左 pane；偏左 -> 右 pane
    // 2) 有作用中的 occlusion（狀態膠囊/時鐘）-> 該 pane 是「有狀態那側」，維持右
    // 3) 窄窗（snap 寬）且無 occlusion -> 左 pane
    static func isPinnedLeftPane(in proxy: GeometryProxy) -> Bool {
        guard #available(iOS 27.1, *), DeviceUtil.isPhone else { return false }
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
}

extension View {
    func duoTopSpacer() -> some View {
        modifier(DuoTopSpacerModifier())
    }
}

// Duo：詳情頁頁頭是否需要鏡像（封面與文字區塊對調，讓「閱讀」鈕靠外緣）。
// 由 DuoTopSpacerModifier 依釘選側自動設定。
private struct DuoMirrorHeaderKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var duoMirrorHeader: Bool {
        get { self[DuoMirrorHeaderKey.self] }
        set { self[DuoMirrorHeaderKey.self] = newValue }
    }
}

// Duo：內容右緣自動停在系統側邊圓鈕欄（與時鐘/訊號圈同軸）之前，
// 避免橫向全螢幕或釘右半邊時，橫向卡片列延伸到系統按鈕下方。
struct DuoReservedTrailingModifier: ViewModifier {
    @State private var inset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.trailing, inset)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { refresh(in: proxy) }
                        .onChange(of: DuoGeometrySignature(size: proxy.size, insets: proxy.safeAreaInsets)) { _, _ in refresh(in: proxy) }
                }
            )
    }

    private func refresh(in proxy: GeometryProxy) {
        var value: CGFloat = 0
        if #available(iOS 27.1, *) {
            let width = proxy.size.width, height = proxy.size.height
            var minX: CGFloat = .greatestFiniteMagnitude
            for region in proxy.reservedRegions(kind: .occlusion, options: .includeInactive) where region.isActive {
                let f = region.frame
                guard f.width > 0, f.height > 0, f.midY < height * 0.35, f.midX > width * 0.55 else { continue }
                minX = min(minX, f.minX)
            }
            if minX < .greatestFiniteMagnitude {
                value = max(0, width - minX + 12)
            }
        }
        inset = value
    }
}

extension View {
    func duoReservedTrailing() -> some View {
        modifier(DuoReservedTrailingModifier())
    }
}
