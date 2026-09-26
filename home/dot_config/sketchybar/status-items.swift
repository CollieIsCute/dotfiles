import AppKit
import ApplicationServices
import Carbon

// macOS 26 hosts many status windows in ControlCenter as identical "Item-0".
// Match their geometry to each app's public AXExtrasMenuBar, not the host name.
// https://developer.apple.com/documentation/applicationservices/axuielement_h
func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success ? value : nil
}

struct StatusItem {
    let bundle: String
    let source: String
    let window: String
    let help: String
    let identifier: String
    let element: AXUIElement
}

func statusItems(bundle: String? = nil) -> [StatusItem] {
    let windows = (CGWindowListCopyWindowInfo(.optionAll, 0) as? [[String: Any]] ?? [])
        .filter {
            $0[kCGWindowLayer as String] as? Int == Int(CGWindowLevelForKey(.statusWindow))
                && $0[kCGWindowOwnerName as String] as? String != "Window Server"
                && $0[kCGWindowName as String] != nil
        }
        .sorted { bounds($0).minX > bounds($1).minX }
    var result: [StatusItem] = []
    for app in NSWorkspace.shared.runningApplications {
        guard let id = app.bundleIdentifier, app.processIdentifier != getpid(),
              bundle == nil || bundle == id,
              ["com.apple.TextInputMenuAgent", "eu.exelban.Stats", "com.steipete.codexbar"].contains(id) else { continue }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.2)
        guard let bar = attribute(root, kAXExtrasMenuBarAttribute) else { continue }
        let elements = attribute(bar as! AXUIElement, kAXChildrenAttribute) as? [AXUIElement] ?? []
        for element in elements {
            AXUIElementSetMessagingTimeout(element, 0.2)
            guard let position = attribute(element, kAXPositionAttribute),
                  let size = attribute(element, kAXSizeAttribute) else { continue }
            var origin = CGPoint.zero
            var dimensions = CGSize.zero
            guard AXValueGetValue(position as! AXValue, .cgPoint, &origin),
                  AXValueGetValue(size as! AXValue, .cgSize, &dimensions),
                  dimensions.width > 0, dimensions.height > 0 else { continue }
            let center = CGPoint(x: origin.x + dimensions.width / 2, y: origin.y + dimensions.height / 2)
            // Zero-size AX placeholders and non-status windows never match.
            let matches = windows.enumerated().filter { bounds($0.element).contains(center) }
            var source = "", name = ""
            if matches.count == 1, let match = matches.first,
               let owner = match.element[kCGWindowOwnerName as String] as? String,
               let window = match.element[kCGWindowName as String] as? String {
                source = "\(owner),\(window)(\(match.offset + 1))"
                name = window
            }
            result.append(StatusItem(bundle: id, source: source, window: name,
                                     help: attribute(element, kAXHelpAttribute) as? String ?? "",
                                     identifier: attribute(element, "AXIdentifier") as? String ?? "",
                                     element: element))
        }
    }
    return result
}

func bounds(_ window: [String: Any]) -> CGRect {
    guard let value = window[kCGWindowBounds as String] as? NSDictionary else { return .null }
    return CGRect(dictionaryRepresentation: value) ?? .null
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
if arguments.count == 2 && arguments[1] == "list" {
    // Only items with a capturable window can become a SketchyBar alias.
    let rows = statusItems().filter { !$0.source.isEmpty }
        .map { ["bundle": $0.bundle, "source": $0.source, "window": $0.window, "help": $0.help] }
    do {
        let data = try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    } catch { fputs("sb-status-items: \(error)\n", stderr); exit(1) }
} else if (arguments.count == 4 && arguments[1] == "click") ||
          (arguments.count == 2 && arguments[1] == "input-menu") {
    // Pressing needs only the AX element, so match the identifier when no window exists.
    let inputMenu = arguments[1] == "input-menu"
    let matches = statusItems(bundle: inputMenu ? "com.apple.TextInputMenuAgent" : arguments[2])
        .filter { inputMenu || $0.window == arguments[3] || $0.identifier == arguments[3] }
    guard matches.count == 1, let item = matches.first else {
        fputs("sb-status-items: missing or ambiguous status item; reload SketchyBar.\n", stderr)
        exit(1)
    }
    // An opened menu tracks modally, so the AX reply times out even on success.
    let status = AXUIElementPerformAction(item.element, kAXPressAction as CFString)
    guard status == .success || status == .cannotComplete else {
        fputs("sb-status-items: native click failed (\(status.rawValue)).\n", stderr)
        exit(1)
    }
} else {
    fputs("usage: sb-status-items list | input-source | input-menu | click BUNDLE_ID WINDOW_NAME_OR_AX_IDENTIFIER\n", stderr)
    exit(64)
}
