import UIKit

// One low-cost scroll observer for all surfaces. Rendering still uses the
// upstream non-continuous renderer; the observer only invalidates on movement.
private protocol DOBackdropClient: AnyObject {
    var backdropView: UIView { get }
    func refreshBackdrop()
}

private final class DOBackdropDriver {
    static let shared = DOBackdropDriver()
    private let clients = NSHashTable<AnyObject>.weakObjects()
    private var link: DisplayLinkDriver.Link?
    private var lastState: [CGFloat] = []

    func register(_ client: DOBackdropClient) {
        clients.add(client)
        if link == nil {
            link = DisplayLinkDriver.shared.add(framesPerSecond: .fps(30), priority: .animation) { [weak self] _ in
                self?.tick()
            }
        }
        link?.isPaused = false
        lastState = []
    }

    func unregister(_ client: DOBackdropClient) {
        clients.remove(client)
        if clients.allObjects.isEmpty {
            link?.invalidate()
            link = nil
            lastState = []
        }
    }

    private func tick() {
        let visible = clients.allObjects.compactMap { $0 as? DOBackdropClient }.filter {
            let v = $0.backdropView
            guard v.window != nil else { return false }
            var current: UIView? = v
            while let node = current {
                if node.isHidden || node.alpha < 0.01 { return false }
                current = node.superview
            }
            return true
        }
        guard !visible.isEmpty else { return }
        var roots: [UIView] = []
        for client in visible {
            if let root = client.backdropView.window?.rootViewController?.view,
               !roots.contains(where: { $0 === root }) { roots.append(root) }
        }
        var state: [CGFloat] = []
        func visit(_ view: UIView) {
            guard !view.isHidden, view.alpha > 0.01 else { return }
            if view is TheseusView || view is DOTheseusTabBar { return }
            if let scroll = view as? UIScrollView {
                state += [scroll.contentOffset.x, scroll.contentOffset.y,
                          scroll.bounds.width, scroll.bounds.height,
                          scroll.contentSize.width, scroll.contentSize.height]
            }
            view.subviews.forEach(visit)
        }
        roots.forEach(visit)
        guard state != lastState else { return }
        lastState = state
        visible.forEach { $0.refreshBackdrop() }
    }
}

@objc(DOTheseusGlassView)
final class DOTheseusGlassView: TheseusView, DOBackdropClient {
    private var active = true
    private var configuredRadius: CGFloat?
    var backdropView: UIView { self }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        providesCaptureSnapshot = true
        continuousUpdate = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = false
        providesCaptureSnapshot = true
    }

    @objc(configureWithCornerRadius:tintColor:tintIntensity:)
    func configure(cornerRadius: CGFloat, tintColor: UIColor, tintIntensity: CGFloat) {
        // Use the stock material. The theme does not replace its optics, tint
        // model or shader with a visually similar implementation.
        _ = tintColor
        _ = tintIntensity
        guard configuredRadius != cornerRadius else { return }
        configuredRadius = cornerRadius
        var config = TheseusConfiguration.regular
        config.captureMethod = TheseusCapability.isDeviceSupported ? .layerRendering : .surfaceBased
        config.shape.cornerRadius = max(0, cornerRadius)
        configuration = config
        invalidateBackground()
    }

    @objc(setCaptureSourceView:)
    func setCaptureSourceView(_ source: UIView?) {
        sourceView = window?.rootViewController?.view ?? source
        if let host = superview { setCaptureExcludedViews([host]) }
        invalidateBackground()
    }

    @objc(invalidateBackdrop)
    func refreshBackdrop() { invalidateBackground() }

    @objc(setRenderingActive:)
    func setRenderingActive(_ value: Bool) {
        active = value
        if value && window != nil {
            resumeRendering()
            DOBackdropDriver.shared.register(self)
            invalidateBackground()
        } else {
            DOBackdropDriver.shared.unregister(self)
            pauseRendering()
        }
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if let host = superview { setCaptureExcludedViews([host]) }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let root = window?.rootViewController?.view { setCaptureSourceView(root) }
        setRenderingActive(active)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let host = superview, host.layer.cornerRadius > 0,
           configuredRadius != host.layer.cornerRadius {
            configure(cornerRadius: host.layer.cornerRadius, tintColor: .clear, tintIntensity: 0)
        }
        invalidateBackground()
    }

    deinit { DOBackdropDriver.shared.unregister(self) }
}

@objc(DOTheseusTabBar)
final class DOTheseusTabBar: UIView, DOBackdropClient {
    private let tabBar = TheseusTabBar()
    private var active = true
    var backdropView: UIView { self }

    @objc var selectedIndex: Int {
        get { tabBar.selectedIndex }
        set { if tabBar.items.indices.contains(newValue) { tabBar.selectedIndex = newValue } }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    private func configureView() {
        backgroundColor = .clear
        clipsToBounds = false
        isOpaque = false
        tabBar.accessibilityIdentifier = "DOStockTheseusTabBar"
        tabBar.frame = bounds
        tabBar.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(tabBar)
        tabBar.onItemSelected = { [weak self] index in
            guard let self else { return }
            NotificationCenter.default.post(name: Notification.Name("DOTheseusTabBarSelection"),
                                            object: self, userInfo: ["index": index])
        }
    }

    @objc(configureWithTitles:symbolNames:selectedIndex:)
    func configure(titles: [String], symbolNames: [String], selectedIndex: Int) {
        tabBar.items = titles.enumerated().map { index, title in
            let image = symbolNames.indices.contains(index) ? UIImage(systemName: symbolNames[index]) : nil
            return TheseusTabBarItem(icon: image, selectedIcon: image, title: title)
        }
        self.selectedIndex = selectedIndex
    }

    @objc(setSelectedIndex:animated:)
    func setSelectedIndex(_ index: Int, animated: Bool) {
        _ = animated
        selectedIndex = index
    }

    @objc(invalidateBackdrop)
    func refreshBackdrop() { tabBar.invalidateBackground() }

    @objc(setRenderingActive:)
    func setRenderingActive(_ value: Bool) {
        active = value
        if value && window != nil {
            if tabBar.superview == nil {
                addSubview(tabBar)
                tabBar.frame = bounds
                tabBar.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                tabBar.translatesAutoresizingMaskIntoConstraints = true
            }
            DOBackdropDriver.shared.register(self)
            tabBar.invalidateBackground()
        } else {
            DOBackdropDriver.shared.unregister(self)
            // Upstream didMoveToWindow(nil) tears down the ancestor drag lens.
            tabBar.removeFromSuperview()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        setRenderingActive(active)
    }

    deinit { DOBackdropDriver.shared.unregister(self) }
}

@objc(DOTheseusSwitchOverlay)
final class DOTheseusSwitchOverlay: UIView {
    private weak var original: UISwitch?
    private let toggle = TheseusSwitch()
    private var observation: NSKeyValueObservation?

    @objc(initWithSwitch:)
    init(source: UISwitch) {
        original = source
        super.init(frame: source.bounds)
        accessibilityIdentifier = "DOStockTheseusSwitch"
        backgroundColor = .clear
        clipsToBounds = false
        toggle.isOn = source.isOn
        toggle.isEnabled = source.isEnabled
        toggle.accessibilityLabel = source.accessibilityLabel
        addSubview(toggle)
        toggle.onValueChanged = { [weak self] value in
            guard let source = self?.original, source.isEnabled else { return }
            source.setOn(value, animated: false)
            source.sendActions(for: .valueChanged)
        }
        source.addTarget(self, action: #selector(syncState), for: .valueChanged)
        observation = source.observe(\.isOn, options: [.new]) { [weak self] _, _ in
            self?.syncState()
        }
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    required init?(coder: NSCoder) { return nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = toggle.intrinsicContentSize
        toggle.frame = CGRect(x: (bounds.width - size.width) / 2,
                              y: (bounds.height - size.height) / 2,
                              width: size.width, height: size.height)
        syncState()
    }

    @objc private func syncState() {
        guard let source = original else { return }
        toggle.isOn = source.isOn
        toggle.isEnabled = source.isEnabled
        for view in source.subviews where view !== self { view.alpha = 0 }
        source.isAccessibilityElement = false
    }
}
