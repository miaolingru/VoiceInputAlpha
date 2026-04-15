import Cocoa

final class CapsuleWindowController {
    private var panel: NSPanel?
    private var waveformView: WaveformView?
    private var textLabel: NSTextField?
    private var refiningLabel: NSTextField?
    private var contentView: NSView?

    private let capsuleHeight: CGFloat = 50
    private let cornerRadius: CGFloat = 25
    private let waveformWidth: CGFloat = 24
    private let waveformLeadingOffset: CGFloat = 8
    private let waveformTextGap: CGFloat = 12
    private let minTextWidth: CGFloat = 144
    private let maxTextWidth: CGFloat = 504
    private let horizontalPadding: CGFloat = 24

    /// 动画起始/结束时的小胶囊宽度（正圆形）
    private let pillWidth: CGFloat = 50

    private var isDynamicIsland: Bool {
        UserDefaults.standard.string(forKey: "animationStyle") != "minimal"
    }

    // MARK: - 计算目标帧

    private func targetFrame(fullWidth: CGFloat, screenFrame: NSRect) -> NSRect {
        NSRect(
            x: screenFrame.midX - fullWidth / 2,
            y: screenFrame.minY + 54,
            width: fullWidth,
            height: capsuleHeight
        )
    }

    private func fullWidth(for textWidth: CGFloat) -> CGFloat {
        textWidth + waveformWidth + waveformLeadingOffset + horizontalPadding * 2 + waveformTextGap
    }

    // MARK: - Show

    func show() {
        if panel != nil { return }

        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let fw = fullWidth(for: minTextWidth)
        let target = targetFrame(fullWidth: fw, screenFrame: screenFrame)

        let panel = NSPanel(
            contentRect: target,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.styleMask.remove(.titled)

        // 内容容器
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let waveform = WaveformView(frame: .zero)
        waveform.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(waveform)

        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13.5, weight: .medium)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingHead
        label.maximumNumberOfLines = 1
        label.cell?.truncatesLastVisibleLine = true
        container.addSubview(label)

        let refLabel = NSTextField(labelWithString: "优化中...")
        refLabel.translatesAutoresizingMaskIntoConstraints = false
        refLabel.font = .systemFont(ofSize: 12, weight: .regular)
        refLabel.textColor = .secondaryLabelColor
        refLabel.isHidden = true
        container.addSubview(refLabel)

        // label 最小宽度低优先级——初始动画小帧时允许违反
        let textMinWidth = label.widthAnchor.constraint(greaterThanOrEqualToConstant: minTextWidth)
        textMinWidth.priority = .defaultLow
        let textMaxWidth = label.widthAnchor.constraint(lessThanOrEqualToConstant: maxTextWidth)

        // 背景：macOS 26 液态玻璃 / 旧系统毛玻璃
        if #available(macOS 26.0, *) {
            let glassView = NSGlassEffectView()
            glassView.cornerRadius = cornerRadius
            glassView.style = .regular
            glassView.translatesAutoresizingMaskIntoConstraints = false
            glassView.contentView = container
            panel.contentView?.addSubview(glassView)
            NSLayoutConstraint.activate([
                glassView.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor),
                glassView.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor),
                glassView.topAnchor.constraint(equalTo: panel.contentView!.topAnchor),
                glassView.bottomAnchor.constraint(equalTo: panel.contentView!.bottomAnchor),
                container.leadingAnchor.constraint(equalTo: glassView.leadingAnchor, constant: horizontalPadding),
                container.trailingAnchor.constraint(equalTo: glassView.trailingAnchor, constant: -horizontalPadding),
                container.topAnchor.constraint(equalTo: glassView.topAnchor),
                container.bottomAnchor.constraint(equalTo: glassView.bottomAnchor),
            ])
        } else {
            let effectView = NSVisualEffectView(frame: panel.contentView!.bounds)
            effectView.autoresizingMask = [.width, .height]
            effectView.material = .hudWindow
            effectView.state = .active
            effectView.blendingMode = .behindWindow
            effectView.wantsLayer = true
            effectView.layer?.cornerRadius = cornerRadius
            effectView.layer?.masksToBounds = true
            effectView.layer?.cornerCurve = .continuous
            panel.contentView?.addSubview(effectView)
            panel.contentView?.addSubview(container)
            NSLayoutConstraint.activate([
                container.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor, constant: horizontalPadding),
                container.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor, constant: -horizontalPadding),
                container.topAnchor.constraint(equalTo: panel.contentView!.topAnchor),
                container.bottomAnchor.constraint(equalTo: panel.contentView!.bottomAnchor),
            ])
        }

        NSLayoutConstraint.activate([
            waveform.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: waveformLeadingOffset),
            waveform.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            waveform.widthAnchor.constraint(equalToConstant: waveformWidth),
            waveform.heightAnchor.constraint(equalToConstant: 29),
            label.leadingAnchor.constraint(equalTo: waveform.trailingAnchor, constant: waveformTextGap),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            textMinWidth, textMaxWidth,
            refLabel.leadingAnchor.constraint(equalTo: waveform.trailingAnchor, constant: waveformTextGap),
            refLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        self.panel = panel
        self.waveformView = waveform
        self.textLabel = label
        self.refiningLabel = refLabel
        self.contentView = container

        if isDynamicIsland {
            animateInDynamicIsland(panel: panel, container: container, targetFrame: target)
        } else {
            animateInMinimal(panel: panel, targetFrame: target)
        }
    }

    // MARK: - 灵动岛入场
    // 从正下方小圆胶囊弹出，同时内容高斯模糊清晰化
    // 用 NSWindow.setFrame 而非 CATransform，避免 anchorPoint 问题和方形边框

    private func animateInDynamicIsland(panel: NSPanel, container: NSView, targetFrame: NSRect) {
        // 起始帧：正圆形胶囊，位于目标底部下方 16pt
        let startFrame = NSRect(
            x: targetFrame.midX - pillWidth / 2,
            y: targetFrame.minY - 16,
            width: pillWidth,
            height: capsuleHeight
        )

        // 内容模糊（被 glass/effect view 圆角裁剪，不会超出胶囊边界）
        container.wantsLayer = true
        let blur = CIFilter(name: "CIGaussianBlur")!
        blur.setValue(12.0, forKey: kCIInputRadiusKey)
        container.layer?.filters = [blur]
        container.layer?.masksToBounds = false

        panel.setFrame(startFrame, display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        // 模糊消除（比窗口动画稍慢，内容在展开后段才清晰）
        let blurAnim = CABasicAnimation(keyPath: "filters.CIGaussianBlur.inputRadius")
        blurAnim.fromValue = 12.0
        blurAnim.toValue = 0.0
        blurAnim.duration = 0.4
        blurAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        blurAnim.fillMode = .forwards
        blurAnim.isRemovedOnCompletion = false
        container.layer?.add(blurAnim, forKey: "blurIn")

        // 窗口从下方弹起 + 横向展开，spring 回弹感
        // controlPoints: 近似 response=0.45, bounce=0.25 的弹簧曲线
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.45
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.4, 0.64, 1.0)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(targetFrame, display: true)
        }, completionHandler: {
            container.layer?.filters = nil
            container.layer?.removeAnimation(forKey: "blurIn")
        })
    }

    // MARK: - 简约模式入场

    private func animateInMinimal(panel: NSPanel, targetFrame: NSRect) {
        panel.contentView?.wantsLayer = true
        panel.alphaValue = 0
        var startFrame = targetFrame
        startFrame.origin.y -= 8
        panel.setFrame(startFrame, display: false)
        panel.contentView?.layer?.transform = CATransform3DMakeScale(0.92, 0.92, 1.0)
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true
            panel.animator().alphaValue = 1
            panel.animator().setFrame(targetFrame, display: true)
            panel.contentView?.layer?.transform = CATransform3DIdentity
        })
    }

    // MARK: - Update

    func updateBands(_ bands: [Float]) {
        waveformView?.updateBands(bands)
    }

    func updateText(_ text: String) {
        guard let label = textLabel, let panel = panel else { return }
        label.stringValue = text

        let textSize = (text as NSString).size(withAttributes: [.font: label.font!])
        let desiredTextWidth = min(max(textSize.width + 18, minTextWidth), maxTextWidth)
        let totalWidth = fullWidth(for: desiredTextWidth)

        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        var frame = panel.frame
        frame.size.width = totalWidth
        frame.origin.x = screenFrame.midX - totalWidth / 2

        // 直接动画窗口帧，Auto Layout 跟着 contentView 自动更新
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        })
    }

    func showRefining() {
        textLabel?.isHidden = true
        refiningLabel?.isHidden = false
        waveformView?.stopAnimating()
    }

    // MARK: - Dismiss

    func dismiss(completion: (() -> Void)? = nil) {
        guard let panel = panel else { completion?(); return }
        if isDynamicIsland {
            dismissDynamicIsland(panel: panel, completion: completion)
        } else {
            dismissMinimal(panel: panel, completion: completion)
        }
    }

    // MARK: - 灵动岛退场
    // 向下缩回小圆胶囊，内容同时模糊消失

    private func dismissDynamicIsland(panel: NSPanel, completion: (() -> Void)?) {
        // 收缩到正圆形，向下偏移 16pt（与入场对称）
        let endFrame = NSRect(
            x: panel.frame.midX - pillWidth / 2,
            y: panel.frame.minY - 16,
            width: pillWidth,
            height: capsuleHeight
        )

        if let container = contentView {
            container.wantsLayer = true
            let blur = CIFilter(name: "CIGaussianBlur")!
            blur.setValue(0.0, forKey: kCIInputRadiusKey)
            container.layer?.filters = [blur]
            container.layer?.masksToBounds = false

            let blurAnim = CABasicAnimation(keyPath: "filters.CIGaussianBlur.inputRadius")
            blurAnim.fromValue = 0.0
            blurAnim.toValue = 12.0
            blurAnim.duration = 0.24
            blurAnim.timingFunction = CAMediaTimingFunction(name: .easeIn)
            blurAnim.fillMode = .forwards
            blurAnim.isRemovedOnCompletion = false
            container.layer?.add(blurAnim, forKey: "blurOut")
        }

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(endFrame, display: true)
        }, completionHandler: { [weak self] in
            panel.orderOut(nil)
            self?.cleanup()
            completion?()
        })
    }

    // MARK: - 简约模式退场

    private func dismissMinimal(panel: NSPanel, completion: (() -> Void)?) {
        var endFrame = panel.frame
        endFrame.origin.y -= 8

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            ctx.allowsImplicitAnimation = true
            panel.animator().alphaValue = 0
            panel.animator().setFrame(endFrame, display: true)
            panel.contentView?.layer?.transform = CATransform3DMakeScale(0.92, 0.92, 1.0)
        }, completionHandler: { [weak self] in
            panel.orderOut(nil)
            self?.cleanup()
            completion?()
        })
    }

    // MARK: - Cleanup

    private func cleanup() {
        waveformView?.stopAnimating()
        waveformView = nil
        textLabel = nil
        refiningLabel = nil
        contentView = nil
        panel = nil
    }
}
