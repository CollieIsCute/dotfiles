import AppKit
import Carbon
import CoreGraphics

// CarbonEvents.h documents these public events as broadcasts to all processes:
// kEventMenuBarShown / kEventMenuBarHidden. No event tap or private SkyLight API.
let arguments = CommandLine.arguments
guard arguments.count == 4, let barPID = Int32(arguments[3]), barPID > 0 else {
    fputs("usage: sb-menu-events watch|sync SKETCHYBAR_PATH BAR_PID\n", stderr)
    exit(64)
}
let executable = URL(fileURLWithPath: arguments[2])
var lastHidden: Bool?

func nativeBarVisible() -> Bool {
    // NSMenu.menuBarVisible() describes this app, not the foreground app.
    // https://developer.apple.com/documentation/coregraphics/cgwindowlistcopywindowinfo(_:_:)
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], 0)
        as? [[String: Any]] ?? []
    return windows.contains {
        $0[kCGWindowOwnerName as String] as? String == "Window Server"
            && $0[kCGWindowName as String] as? String == "Menubar"
    }
}

func setHidden(_ hidden: Bool) {
    guard lastHidden != hidden else { return }
    let command = Process()
    command.executableURL = executable
    command.arguments = ["--bar", "hidden=\(hidden ? "on" : "off")"]
    do {
        try command.run()
        command.waitUntilExit()
        guard command.terminationStatus == 0 else { exit(1) }
        lastHidden = hidden
    } catch {
        fputs("sb-menu-events: \(error)\n", stderr)
        exit(1)
    }
}

guard arguments[1] == "watch" || arguments[1] == "sync" else { exit(64) }
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
if arguments[1] == "sync" {
    setHidden(nativeBarVisible())
    exit(0)
}

var eventTypes = [
    EventTypeSpec(eventClass: OSType(kEventClassMenu), eventKind: UInt32(kEventMenuBarShown)),
    EventTypeSpec(eventClass: OSType(kEventClassMenu), eventKind: UInt32(kEventMenuBarHidden)),
]
let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
    // ponytail: hide all displays together; use per-display bar IDs if needed.
    setHidden(GetEventKind(event) == kEventMenuBarShown || nativeBarVisible())
    return OSStatus(eventNotHandledErr)
}, eventTypes.count, &eventTypes, nil, nil)
guard status == noErr else {
    fputs("sb-menu-events: cannot subscribe to menu events (\(status))\n", stderr)
    exit(1)
}

let workspace = NSWorkspace.shared.notificationCenter
for name in [NSWorkspace.didWakeNotification, NSWorkspace.activeSpaceDidChangeNotification] {
    workspace.addObserver(forName: name, object: nil, queue: .main) { _ in
        setHidden(nativeBarVisible())
    }
}
NotificationCenter.default.addObserver(
    forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
) { _ in setHidden(nativeBarVisible()) }

// The launching shell restores the bar even after SIGKILL or a helper crash.
let barExit = DispatchSource.makeProcessSource(identifier: barPID, eventMask: .exit, queue: .main)
barExit.setEventHandler { exit(0) }
barExit.resume()
setHidden(nativeBarVisible())
app.run()
