import AppKit
import ApplicationServices
import Carbon

// https://developer.apple.com/documentation/applicationservices/axuielement_h
func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success ? value : nil
}

func statusItems(bundle: String) -> [AXUIElement] {
    var result: [AXUIElement] = []
    for app in NSWorkspace.shared.runningApplications {
        guard let id = app.bundleIdentifier, app.processIdentifier != getpid(),
              bundle == id,
              ["com.apple.TextInputMenuAgent", "eu.exelban.Stats", "com.steipete.codexbar"].contains(id) else { continue }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.2)
        guard let bar = attribute(root, kAXExtrasMenuBarAttribute) else { continue }
        let elements = attribute(bar as! AXUIElement, kAXChildrenAttribute) as? [AXUIElement] ?? []
        for element in elements {
            AXUIElementSetMessagingTimeout(element, 0.2)
            guard let size = attribute(element, kAXSizeAttribute) else { continue }
            var dimensions = CGSize.zero
            guard AXValueGetValue(size as! AXValue, .cgSize, &dimensions),
                  dimensions.width > 0, dimensions.height > 0 else { continue }
            result.append(element)
        }
    }
    return result
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
if (arguments.count == 4 && arguments[1] == "click") ||
          (arguments.count == 2 && arguments[1] == "input-menu") {
    let inputMenu = arguments[1] == "input-menu"
    let matches = statusItems(bundle: inputMenu ? "com.apple.TextInputMenuAgent" : arguments[2])
        .filter { inputMenu || attribute($0, "AXIdentifier") as? String == arguments[3] }
    guard matches.count == 1, let item = matches.first else {
        fputs("sb-status-items: missing or ambiguous status item; reload SketchyBar.\n", stderr)
        exit(1)
    }
    // An opened menu tracks modally, so the AX reply times out even on success.
    let status = AXUIElementPerformAction(item, kAXPressAction as CFString)
    guard status == .success || status == .cannotComplete else {
        fputs("sb-status-items: native click failed (\(status.rawValue)).\n", stderr)
        exit(1)
    }
} else {
    fputs("usage: sb-status-items input-source | input-menu | click BUNDLE_ID AX_IDENTIFIER\n", stderr)
    exit(64)
}
