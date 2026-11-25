import Foundation
import AgentDotCore

func runKakuActivePaneParserTests() {
    runTest("KakuActivePaneParser returns the single active tab's active pane") {
        let json: [String: Any] = [
            "windows": [
                [
                    "tabs": [
                        [
                            "is_active": true,
                            "panes": [
                                ["pane_id": 3, "is_active": true],
                                ["pane_id": 4, "is_active": false]
                            ]
                        ],
                        [
                            "is_active": false,
                            "panes": [
                                ["pane_id": 5, "is_active": true]
                            ]
                        ]
                    ]
                ]
            ]
        ]
        expectEqual(KakuActivePaneParser.activePaneID(from: json), "3")
    }

    runTest("KakuActivePaneParser refuses multiple active tabs") {
        let json: [String: Any] = [
            "windows": [
                [
                    "tabs": [
                        ["is_active": true, "panes": [["pane_id": 3, "is_active": true]]],
                        ["is_active": true, "panes": [["pane_id": 4, "is_active": true]]]
                    ]
                ]
            ]
        ]
        expectNil(KakuActivePaneParser.activePaneID(from: json))
    }

    runTest("KakuActivePaneParser refuses multiple active panes in one tab") {
        let json: [String: Any] = [
            "windows": [
                [
                    "tabs": [
                        [
                            "is_active": true,
                            "panes": [
                                ["pane_id": 3, "is_active": true],
                                ["pane_id": 4, "is_active": true]
                            ]
                        ]
                    ]
                ]
            ]
        ]
        expectNil(KakuActivePaneParser.activePaneID(from: json))
    }

    runTest("KakuActivePaneParser refuses schema without tab activity") {
        let json: [String: Any] = [
            "windows": [
                [
                    "tabs": [
                        ["panes": [["pane_id": 3, "is_active": true]]]
                    ]
                ]
            ]
        ]
        expectNil(KakuActivePaneParser.activePaneID(from: json))
    }
}
