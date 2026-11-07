import AppKit
import ApplicationServices
import Carbon

// https://developer.apple.com/documentation/applicationservices/axuielement_h
func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success ? value : nil
}

// MenuBarAgent hosts the buttons; their AX process IDs still identify the owning apps.
func statusItems(bundle: String, identifier: String? = nil) -> [AXUIElement] {
    let apps = NSWorkspace.shared.runningApplications
    guard let owner = apps.first(where: { $0.bundleIdentifier == bundle }),
          let host = apps.first(where: { $0.bundleIdentifier == "com.apple.MenuBarAgent" }) else { return [] }
    func find(_ element: AXUIElement, depth: Int) -> [AXUIElement] {
        guard depth <= 4 else { return [] }
        if attribute(element, kAXRoleAttribute) as? String == kAXButtonRole {
            var pid: pid_t = 0
            guard AXUIElementGetPid(element, &pid) == .success, pid == owner.processIdentifier,
                  identifier == nil || attribute(element, "AXIdentifier") as? String == identifier else { return [] }
            return [element]
        }
        let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
        return children.flatMap { find($0, depth: depth + 1) }
    }
    let root = AXUIElementCreateApplication(host.processIdentifier)
    AXUIElementSetMessagingTimeout(root, 0.2)
    return find(root, depth: 0)
}

let arguments = CommandLine.arguments
if arguments.count == 2 && arguments[1] == "input-source" {
    let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    func property(_ key: CFString, from source: TISInputSource) -> String {
        guard let value = TISGetInputSourceProperty(source, key) else { return "" }
        return Unmanaged<CFString>.fromOpaque(value).takeUnretainedValue() as String
    }
    let id = property(kTISPropertyInputSourceID, from: source).lowercased()
    let name = property(kTISPropertyLocalizedName, from: source)
    if id.hasPrefix("org.atelierinmu.inputmethod.vchewing.") {
        // vChewing 4.8.5 SessionProtocol.setKeyLayout updates this on Shift.
        // ponytail: equal/missing layouts cannot identify the mode; show only the IME name.
        let prefs = UserDefaults.standard.persistentDomain(forName: "org.atelierInmu.inputmethod.vChewing") ?? [:]
        if let chinese = prefs["BasicKeyboardLayout"] as? String,
           let english = prefs["AlphanumericalKeyboardLayout"] as? String,
           chinese != english,
           let layout = TISCopyInputMethodKeyboardLayoutOverride()?.takeRetainedValue() {
            let layoutID = property(kTISPropertyInputSourceID, from: layout)
            print(layoutID == english ? "唯A" : layoutID == chinese ? "唯注" : "唯")
        } else { print("唯") }
    }
    else if id.contains("bopomofo") { print("注") }
    else if id.contains(".abc") || id.contains(".us") { print("A") }
    else { print(name.isEmpty ? "⌨" : String(name.prefix(1))) }
    exit(0)
}
guard AXIsProcessTrusted() else {
    fputs("sb-status-items: the launcher needs Accessibility permission.\n", stderr)
    exit(1)
}
let matches: [AXUIElement]
if arguments.count == 2 && arguments[1] == "input-menu" {
    matches = statusItems(bundle: "com.apple.TextInputMenuAgent")
} else if arguments.count == 3 && arguments[1] == "click", ["codex", "claude"].contains(arguments[2]) {
    matches = statusItems(bundle: "com.steipete.codexbar", identifier: "CodexBar.StatusItem.\(arguments[2])")
} else {
    fputs("usage: sb-status-items input-source | input-menu | click codex|claude\n", stderr)
    exit(64)
}
guard matches.count == 1, let item = matches.first else {
    fputs("sb-status-items: missing or ambiguous status item.\n", stderr)
    exit(1)
}
// An opened menu tracks modally, so the AX reply times out even on success.
let status = AXUIElementPerformAction(item, kAXPressAction as CFString)
guard status == .success || status == .cannotComplete else {
    fputs("sb-status-items: native click failed (\(status.rawValue)).\n", stderr)
    exit(1)
}
