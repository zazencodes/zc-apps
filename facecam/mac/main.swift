// Facecam: a menu bar webcam mirror. Click the icon to show or hide a floating, resizable window of
// your camera, ready for screen recording. Right-click the icon for camera, mirror and quit.
import AppKit
import AVFoundation

// Draws frames as soon as they arrive and drops any it cannot take, so delay cannot build up in the app.
final class VideoView: NSView {
    let displayLayer = AVSampleBufferDisplayLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true
        displayLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(displayLayer)
    }

    required init?(coder: NSCoder) { fatalError("VideoView is created in code") }

    override var mouseDownCanMoveWindow: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    var isMirrored = false {
        didSet { needsLayout = true }
    }

    var zoom: CGFloat = 1 {
        didSet { needsLayout = true }
    }

    override func scrollWheel(with event: NSEvent) {
        zoom = min(4, max(1, zoom * exp(event.scrollingDeltaY * 0.005)))
        UserDefaults.standard.set(Double(zoom), forKey: AppDelegate.zoomKey)
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer.bounds = bounds
        displayLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        displayLayer.setAffineTransform(CGAffineTransform(scaleX: isMirrored ? -zoom : zoom, y: zoom))
        CATransaction.commit()
    }
}

final class Camera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "facecam.session")
    private let frameQueue = DispatchQueue(label: "facecam.frames", qos: .userInteractive)
    private let renderer: AVSampleBufferVideoRenderer
    private(set) var current: AVCaptureDevice?

    init(renderer: AVSampleBufferVideoRenderer) {
        self.renderer = renderer
        super.init()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ]
        output.setSampleBufferDelegate(self, queue: frameQueue)
        session.addOutput(output)
    }

    static func available() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external, .builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        ).devices.filter { !$0.isContinuityCamera }
    }

    // The fastest 1080p mode the camera offers.
    private static func bestFormat(of device: AVCaptureDevice) -> (AVCaptureDevice.Format, AVFrameRateRange)? {
        var best: (AVCaptureDevice.Format, AVFrameRateRange)?
        for format in device.formats {
            let description = format.formatDescription
            let size = CMVideoFormatDescriptionGetDimensions(description)
            guard size.width == 1920, size.height == 1080,
                  CMFormatDescriptionGetMediaSubType(description) == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
            else { continue }
            for range in format.videoSupportedFrameRateRanges
            where range.maxFrameRate > (best?.1.maxFrameRate ?? 0) {
                best = (format, range)
            }
        }
        return best
    }

    // Passing nil turns the camera off.
    func use(_ device: AVCaptureDevice?, onError: @escaping (String) -> Void) {
        current = device
        sessionQueue.async { [self] in
            session.stopRunning()
            renderer.flush(removingDisplayedImage: true, completionHandler: nil)
            session.beginConfiguration()
            session.inputs.forEach(session.removeInput)
            guard let device else {
                session.commitConfiguration()
                return
            }
            do {
                guard let (format, range) = Self.bestFormat(of: device) else {
                    throw NSError(domain: "Facecam", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "\(device.localizedName) has no 1080p mode."
                    ])
                }
                session.addInput(try AVCaptureDeviceInput(device: device))
                session.commitConfiguration()
                // The lock is held through startRunning so the session keeps this format.
                try device.lockForConfiguration()
                device.activeFormat = format
                device.activeVideoMinFrameDuration = range.minFrameDuration
                device.activeVideoMaxFrameDuration = range.minFrameDuration
                session.startRunning()
                device.unlockForConfiguration()
            } catch {
                session.commitConfiguration()
                onError(error.localizedDescription)
            }
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        if renderer.requiresFlushToResumeDecoding || renderer.status == .failed {
            renderer.flush()
        }
        guard renderer.isReadyForMoreMediaData else { return }
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true),
              CFArrayGetCount(attachments) > 0
        else { return }
        let dictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
        CFDictionarySetValue(
            dictionary,
            Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
            Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
        )
        renderer.enqueue(sampleBuffer)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let cameraKey = "cameraID"
    private static let mirroredKey = "mirrored"
    private static let frameName = "Facecam"
    static let zoomKey = "zoom"

    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private let videoView = VideoView(frame: NSRect(x: 0, y: 0, width: 360, height: 360))
    private lazy var camera = Camera(renderer: videoView.displayLayer.sampleBufferRenderer)
    private let menu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [Self.mirroredKey: true, Self.zoomKey: 1.0])
        videoView.isMirrored = UserDefaults.standard.bool(forKey: Self.mirroredKey)
        videoView.zoom = UserDefaults.standard.double(forKey: Self.zoomKey)
        menu.delegate = self
        buildWindow()
        buildStatusItem()

        for name in [AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification] {
            NotificationCenter.default.addObserver(
                self, selector: #selector(updateCamera), name: name, object: nil
            )
        }
    }

    private func buildWindow() {
        window = NSWindow(
            contentRect: videoView.frame,
            styleMask: [.titled, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        for button: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(button)?.isHidden = true
        }
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.backgroundColor = .black
        window.minSize = NSSize(width: 120, height: 120)
        window.contentView = videoView
    }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button!.target = self
        statusItem.button!.action = #selector(statusItemClicked)
        statusItem.button!.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button!.image = Self.apertureIcon()
    }

    // A solid disc cut by six slits that run along the sides of a hexagonal opening.
    private static func apertureIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let context = NSGraphicsContext.current!.cgContext
            let center = CGPoint(x: 9, y: 9)
            let radius: CGFloat = 8.5
            context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))

            context.setBlendMode(.clear)
            let corners = (0..<6).map { index -> CGPoint in
                let angle = CGFloat(index) * .pi / 3 + 5 * .pi / 180
                return CGPoint(x: center.x + radius * 0.42 * cos(angle), y: center.y + radius * 0.42 * sin(angle))
            }
            context.addLines(between: corners)
            context.closePath()
            context.fillPath()

            context.setLineWidth(radius * 0.17)
            for (index, start) in corners.enumerated() {
                let next = corners[(index + 1) % 6]
                context.move(to: start)
                context.addLine(to: CGPoint(x: start.x + (next.x - start.x) * 4, y: start.y + (next.y - start.y) * 4))
            }
            context.strokePath()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Facecam"
        return image
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            statusItem.menu = menu
            statusItem.button!.performClick(nil)
            statusItem.menu = nil
        } else if window.isVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }

    private func showWindow() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                guard granted else {
                    return self.show(error: "Allow Facecam in System Settings > Privacy & Security > Camera.")
                }
                self.placeWindow()
                self.window.orderFrontRegardless()
                self.updateCamera()
            }
        }
    }

    // Opens under the menu bar icon until the window has been moved or resized, then stays where it was left.
    private func placeWindow() {
        guard window.frameAutosaveName.isEmpty else { return }
        if !window.setFrameUsingName(Self.frameName) {
            let icon = statusItem.button!.window!.frame
            let screen = statusItem.button!.window!.screen!.visibleFrame
            let x = min(icon.midX - window.frame.width / 2, screen.maxX - window.frame.width - 8)
            window.setFrameOrigin(NSPoint(x: x, y: icon.minY - window.frame.height - 8))
        }
        window.setFrameAutosaveName(Self.frameName)
    }

    private func hideWindow() {
        window.orderOut(nil)
        updateCamera()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let saved = UserDefaults.standard.string(forKey: Self.cameraKey)
        let chosen = Self.chooseCamera(from: Camera.available(), saved: saved)
        for device in Camera.available() {
            let item = menu.addItem(withTitle: device.localizedName, action: #selector(pickCamera(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = device.uniqueID
            item.state = device.uniqueID == chosen?.uniqueID ? .on : .off
        }
        menu.addItem(.separator())
        let mirror = menu.addItem(withTitle: "Mirror", action: #selector(toggleMirror), keyEquivalent: "")
        mirror.target = self
        mirror.state = videoView.isMirrored ? .on : .off
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Facecam", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
    }

    @objc private func pickCamera(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.representedObject as? String, forKey: Self.cameraKey)
        updateCamera()
    }

    @objc private func toggleMirror() {
        videoView.isMirrored.toggle()
        UserDefaults.standard.set(videoView.isMirrored, forKey: Self.mirroredKey)
    }

    // The saved camera whenever it is plugged in, otherwise the first one available.
    private static func chooseCamera(from devices: [AVCaptureDevice], saved: String?) -> AVCaptureDevice? {
        devices.first { $0.uniqueID == saved } ?? devices.first
    }

    // The camera only runs while the window is showing.
    @objc private func updateCamera() {
        let saved = UserDefaults.standard.string(forKey: Self.cameraKey)
        let wanted = window.isVisible ? Self.chooseCamera(from: Camera.available(), saved: saved) : nil
        guard wanted?.uniqueID != camera.current?.uniqueID else { return }
        camera.use(wanted) { message in
            DispatchQueue.main.async {
                self.hideWindow()
                self.show(error: message)
            }
        }
    }

    private func show(error message: String) {
        let alert = NSAlert()
        alert.messageText = "Facecam can't show the camera"
        alert.informativeText = message
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
