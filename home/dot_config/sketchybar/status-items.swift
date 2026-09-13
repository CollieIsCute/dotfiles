import AppKit
import ApplicationServices

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
            guard matches.count == 1, let match = matches.first,
                  let owner = match.element[kCGWindowOwnerName as String] as? String,
                  let name = match.element[kCGWindowName as String] as? String else { continue }
            result.append(StatusItem(bundle: id, source: "\(owner),\(name)(\(match.offset + 1))",
                                     window: name, help: attribute(element, kAXHelpAttribute) as? String ?? "",
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
guard AXIsProcessTrusted() else {
    fputs("sb-status-items: the launcher needs Accessibility permission.\n", stderr)
    exit(1)
}
if arguments.count == 2 && arguments[1] == "list" {
    let rows = statusItems().map { ["bundle": $0.bundle, "source": $0.source, "window": $0.window, "help": $0.help] }
    do {
        let data = try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    } catch { fputs("sb-status-items: \(error)\n", stderr); exit(1) }
} else if arguments.count == 4 && arguments[1] == "click" {
    let matches = statusItems(bundle: arguments[2]).filter { $0.window == arguments[3] }
    guard matches.count == 1, let item = matches.first else {
        fputs("sb-status-items: missing or ambiguous status item; reload SketchyBar.\n", stderr)
        exit(1)
    }
    let status = AXUIElementPerformAction(item.element, kAXPressAction as CFString)
    guard status == .success else {
        fputs("sb-status-items: native click failed (\(status.rawValue)).\n", stderr)
        exit(1)
    }
} else {
    fputs("usage: sb-status-items list | click BUNDLE_ID WINDOW_NAME\n", stderr)
    exit(64)
}
