import Foundation

public enum KakuActivePaneParser {
    public static func activePaneID(from json: Any) -> String? {
        var activeTabs: [[String: Any]] = []
        collectActiveTabs(json, into: &activeTabs)

        guard activeTabs.count == 1,
              let tab = activeTabs.first,
              let panes = tab["panes"] as? [[String: Any]] else {
            return nil
        }

        let activePanes = panes.filter { ($0["is_active"] as? Bool) == true }
        guard activePanes.count == 1,
              let pane = activePanes.first?["pane_id"] else {
            return nil
        }
        return String(describing: pane)
    }

    private static func collectActiveTabs(
        _ value: Any,
        into result: inout [[String: Any]]
    ) {
        if let dictionary = value as? [String: Any] {
            if dictionary["panes"] is [[String: Any]],
               (dictionary["is_active"] as? Bool) == true {
                result.append(dictionary)
            }
            for child in dictionary.values {
                collectActiveTabs(child, into: &result)
            }
        } else if let array = value as? [Any] {
            for child in array {
                collectActiveTabs(child, into: &result)
            }
        }
    }
}
