import AppKit
import Foundation

enum StartupProbe {
    private static let clock = ContinuousClock()
    private static let start = clock.now
    static let isEnabled = ProcessInfo.processInfo.environment["CUNEIFORM_STARTUP_PROBE"] == "1"
    private static let autoTerminate = ProcessInfo.processInfo.environment["CUNEIFORM_STARTUP_PROBE_QUIT"] == "1"

    static func mark(_ label: String) {
        guard isEnabled else { return }
        let elapsed = start.duration(to: clock.now)
        let milliseconds = Double(elapsed.components.seconds) * 1_000
            + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000
        write(String(format: "startup_probe %.2fms %@\n", milliseconds, label))
    }

    @MainActor
    static func finish(_ label: String) {
        mark(label)
        guard isEnabled, autoTerminate else { return }
        NSApp.terminate(nil)
    }

    private static func write(_ line: String) {
        if let logPath = ProcessInfo.processInfo.environment["CUNEIFORM_STARTUP_PROBE_LOG"] {
            if FileManager.default.fileExists(atPath: logPath),
               let handle = FileHandle(forWritingAtPath: logPath) {
                handle.seekToEndOfFile()
                handle.write(Data(line.utf8))
                try? handle.close()
            } else {
                try? line.write(toFile: logPath, atomically: true, encoding: .utf8)
            }
        } else {
            FileHandle.standardError.write(Data(line.utf8))
        }
    }
}
