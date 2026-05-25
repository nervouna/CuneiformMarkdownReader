import AppKit

@main
enum SimpleMarkdownPreviewerApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()

        application.delegate = delegate
        application.setActivationPolicy(.regular)
        application.finishLaunching()
        delegate.start()
        application.run()
    }
}
