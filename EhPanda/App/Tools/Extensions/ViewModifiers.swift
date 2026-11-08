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
    @State private var leadingBleed: CGFloat = 0
    @State private var mirrorHeader = false

    func body(content: Content) -> some View {
        content
            .padding(.leading, leadingBleed)
            .environment(\.duoMirrorHeader, mirrorHeader)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { refresh(in: proxy) }
                        .onChange(of: DuoGeometrySignature(size: proxy.size, insets: proxy.safeAreaInsets)) { _, _ in
                            refresh(in: proxy)
                        }
                }
            )
            // （已拆）墊高用的 topBarLeading 空白 ToolbarItem：iOS 27 Duo 模式
            // 會把工具列項目轉成圓形按鈕，它變成 ‹ 旁邊一顆無作用空白圓鈕，
            // 而且 ‹⋯ 位置也沒有真的被推下（IMG_0313），整塊移除。
    }

    private func refresh(in proxy: GeometryProxy) {
        let leftPane = Self.isPinnedLeftPane(in: proxy)
        mirrorHeader = leftPane
        // （已關）leadingBleed：IMG_0308/0309 實測左右半邊內容寬度都是 385pt，
        // 本來就一致、沒有「幽靈留白」；開啟反而會把內容滑進系統圓鈕列底下。
        leadingBleed = 0
    }

    // 釘選側判斷（IMG_0308/0309 黃字實測 ground truth）：
    // 釘選時系統總是在其中一側保留 83pt（圓鈕列/狀態群那側）的安全區——
    //   左半邊：leading 83 / trailing 0（o301,-24 的 occlusion 是幽靈區，不可當訊號）
    //   右半邊：leading 0 / trailing 83
    //   全螢幕：兩側都是 0
    // 舊的「看到 occlusion 就是右半邊」判斷在左半邊會誤判（幽靈遮擋區），故改用安全區方向。
    static func isPinnedLeftPane(in proxy: GeometryProxy) -> Bool {
        guard #available(iOS 27.1, *), DeviceUtil.isPhone else { return false }
        let l = proxy.safeAreaInsets.leading
        let r = proxy.safeAreaInsets.trailing
        return l > 60 && l > r + 40
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
