import AppKit
import SimpleMarkdownPreviewerCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pendingOpenURLs: [URL] = []
    private let appState = AppState()
    private var window: NSWindow?
    private var didStart = false

    var openURLHandler: ((URL) -> Void)? {
        didSet {
            guard let openURLHandler else { return }
            pendingOpenURLs.forEach(openURLHandler)
            pendingOpenURLs.removeAll()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        start()
    }

    func start() {
        guard !didStart else { return }
        didStart = true
        configureMenu()
        createWindow()
        openURLHandler = appState.open

        if let firstPath = CommandLine.arguments.dropFirst().first {
            appState.open(URL(fileURLWithPath: firstPath))
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        for filename in filenames {
            let url = URL(fileURLWithPath: filename)
            if let openURLHandler {
                openURLHandler(url)
            } else {
                pendingOpenURLs.append(url)
            }
        }
        sender.reply(toOpenOrPrint: .success)
    }

    @objc private func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "md")!,
            UTType(filenameExtension: "markdown")!
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            appState.open(url)
        }
    }

    @objc private func reloadDocument(_ sender: Any?) {
        appState.reload()
    }

    @objc private func increaseTextSize(_ sender: Any?) {
        appState.updatePreferences { preferences in
            preferences.fontScale = min(preferences.fontScale + 0.1, 1.6)
        }
    }

    @objc private func decreaseTextSize(_ sender: Any?) {
        appState.updatePreferences { preferences in
            preferences.fontScale = max(preferences.fontScale - 0.1, 0.8)
        }
    }

    @objc private func setSystemAppearance(_ sender: Any?) {
        setAppearance(.system)
    }

    @objc private func setLightAppearance(_ sender: Any?) {
        setAppearance(.light)
    }

    @objc private func setDarkAppearance(_ sender: Any?) {
        setAppearance(.dark)
    }

    private func setAppearance(_ mode: AppearanceMode) {
        appState.updatePreferences { preferences in
            preferences.appearanceMode = mode
        }
    }

    private func createWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SimpleMarkdownPreviewer"
        window.center()
        window.contentView = NSHostingView(rootView: ContentView(appState: appState))
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    private func configureMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Quit SimpleMarkdownPreviewer",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(
            withTitle: "Open...",
            action: #selector(openDocument(_:)),
            keyEquivalent: "o"
        )
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(
            withTitle: "Reload",
            action: #selector(reloadDocument(_:)),
            keyEquivalent: "r"
        )
        viewMenu.addItem(
            withTitle: "Increase Text Size",
            action: #selector(increaseTextSize(_:)),
            keyEquivalent: "+"
        )
        viewMenu.addItem(
            withTitle: "Decrease Text Size",
            action: #selector(decreaseTextSize(_:)),
            keyEquivalent: "-"
        )
        viewMenu.addItem(.separator())
        viewMenu.addItem(
            withTitle: "System Appearance",
            action: #selector(setSystemAppearance(_:)),
            keyEquivalent: ""
        )
        viewMenu.addItem(
            withTitle: "Light Appearance",
            action: #selector(setLightAppearance(_:)),
            keyEquivalent: ""
        )
        viewMenu.addItem(
            withTitle: "Dark Appearance",
            action: #selector(setDarkAppearance(_:)),
            keyEquivalent: ""
        )
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        NSApp.mainMenu = mainMenu
    }
}
