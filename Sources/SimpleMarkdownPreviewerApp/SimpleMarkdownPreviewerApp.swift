import AppKit

@main
enum SimpleMarkdownPreviewerApp {
    static func main() {
        StartupProbe.mark("main.entry")
        let application = NSApplication.shared
        StartupProbe.mark("nsapplication.shared")
        let delegate = AppDelegate()

        application.delegate = delegate
        application.setActivationPolicy(.regular)
        application.finishLaunching()
        StartupProbe.mark("after.finishLaunching")
        delegate.start()
        StartupProbe.mark("before.run")
        application.run()
    }
}
