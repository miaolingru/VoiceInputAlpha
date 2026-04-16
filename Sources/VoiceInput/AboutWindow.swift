import Cocoa

final class AboutWindowController: NSObject {
    private var window: NSWindow?

    func showWindow() {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
            if #available(macOS 14.0, *) { NSApp.activate() }
            else { NSApp.activate(ignoringOtherApps: true) }
            return
        }
        buildWindow()
    }

    private func buildWindow() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = loc("about.title")
        w.isReleasedWhenClosed = false

        guard let cv = w.contentView else { return }

        let vStack = NSStackView()
        vStack.orientation = .vertical
        vStack.alignment = .centerX
        vStack.spacing = 0
        vStack.translatesAutoresizingMaskIntoConstraints = false
        vStack.edgeInsets = NSEdgeInsets(top: 24, left: 20, bottom: 20, right: 20)
        cv.addSubview(vStack)
        NSLayoutConstraint.activate([
            vStack.topAnchor.constraint(equalTo: cv.topAnchor),
            vStack.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
            vStack.trailingAnchor.constraint(equalTo: cv.trailingAnchor),
            vStack.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
        ])

        // ── App 图标 ───────────────────────────────────────────
        let iconView = NSImageView()
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 80).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 80).isActive = true
        vStack.addArrangedSubview(iconView)
        vStack.setCustomSpacing(12, after: iconView)

        // ── 应用名称 ──────────────────────────────────────────
        let nameLabel = NSTextField(labelWithString: "VoiceInput")
        nameLabel.font = .boldSystemFont(ofSize: 18)
        nameLabel.textColor = .labelColor
        vStack.addArrangedSubview(nameLabel)
        vStack.setCustomSpacing(4, after: nameLabel)

        // ── 版本号 ────────────────────────────────────────────
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.9"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let versionLabel = NSTextField(labelWithString: loc("about.version", version, build))
        versionLabel.font = .systemFont(ofSize: 12)
        versionLabel.textColor = .secondaryLabelColor
        vStack.addArrangedSubview(versionLabel)
        vStack.setCustomSpacing(20, after: versionLabel)

        // ── 分割线 ────────────────────────────────────────────
        let sep1 = makeSeparator()
        vStack.addArrangedSubview(sep1)
        sep1.widthAnchor.constraint(equalTo: vStack.widthAnchor, constant: -40).isActive = true
        vStack.setCustomSpacing(16, after: sep1)

        // ── 作者名 ────────────────────────────────────────────
        let authorLabel = NSTextField(labelWithString: "缪凌儒BlackSquare")
        authorLabel.font = .systemFont(ofSize: 13, weight: .medium)
        authorLabel.textColor = .labelColor
        vStack.addArrangedSubview(authorLabel)
        vStack.setCustomSpacing(14, after: authorLabel)

        // ── 链接区 ────────────────────────────────────────────
        let linksStack = NSStackView()
        linksStack.orientation = .vertical
        linksStack.alignment = .leading
        linksStack.spacing = 8

        linksStack.addArrangedSubview(makeLinkRow(
            svgName: "bilibili",
            fallbackSymbol: "play.circle.fill",
            fallbackColor: .systemPink,
            title: loc("about.bilibili"),
            url: "https://space.bilibili.com/404899"
        ))
        linksStack.addArrangedSubview(makeLinkRow(
            svgName: "github",
            fallbackSymbol: "chevron.left.forwardslash.chevron.right",
            fallbackColor: .labelColor,
            title: loc("about.github"),
            url: "https://github.com/BlackSquarre/VoiceInputAlpha"
        ))

        vStack.addArrangedSubview(linksStack)
        vStack.setCustomSpacing(20, after: linksStack)

        // ── 分割线 ────────────────────────────────────────────
        let sep2 = makeSeparator()
        vStack.addArrangedSubview(sep2)
        sep2.widthAnchor.constraint(equalTo: vStack.widthAnchor, constant: -40).isActive = true
        vStack.setCustomSpacing(12, after: sep2)

        // ── 版权 ──────────────────────────────────────────────
        let copyright = NSTextField(labelWithString: loc("about.copyright"))
        copyright.font = .systemFont(ofSize: 11)
        copyright.textColor = .tertiaryLabelColor
        vStack.addArrangedSubview(copyright)

        self.window = w
        w.center()
        w.makeKeyAndOrderFront(nil)
        if #available(macOS 14.0, *) { NSApp.activate() }
        else { NSApp.activate(ignoringOtherApps: true) }
    }

    // MARK: - Helpers

    private func makeSeparator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        return box
    }

    private func makeLinkRow(svgName: String, fallbackSymbol: String,
                              fallbackColor: NSColor, title: String, url: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY

        // 官方 SVG 图标，加载失败降级为 SF Symbol
        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 18).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 18).isActive = true

        if let svgURL = Bundle.main.url(forResource: svgName, withExtension: "svg",
                                         subdirectory: "Icons"),
           let svgImage = NSImage(contentsOf: svgURL) {
            svgImage.size = NSSize(width: 18, height: 18)
            icon.image = svgImage
            // 适配深浅色：通过 template 模式让系统着色
            icon.image?.isTemplate = true
            icon.contentTintColor = fallbackColor
        } else {
            // 降级到 SF Symbol
            let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            icon.image = NSImage(systemSymbolName: fallbackSymbol,
                                  accessibilityDescription: nil)?
                .withSymbolConfiguration(cfg)
            icon.contentTintColor = fallbackColor
        }

        // 链接按钮（下划线 + linkColor）
        let btn = NSButton(title: title, target: self, action: #selector(openLink(_:)))
        btn.isBordered = false
        btn.identifier = NSUserInterfaceItemIdentifier(url)
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .font: NSFont.systemFont(ofSize: 13),
        ]
        btn.attributedTitle = NSAttributedString(string: title, attributes: attrs)
        btn.toolTip = url

        row.addArrangedSubview(icon)
        row.addArrangedSubview(btn)
        return row
    }

    @objc private func openLink(_ sender: NSButton) {
        guard let urlStr = sender.identifier?.rawValue,
              let url = URL(string: urlStr) else { return }
        NSWorkspace.shared.open(url)
    }
}
