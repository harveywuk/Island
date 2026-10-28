pragma ComponentBehavior: Bound

// polkit's password prompt as the expanded Island, after macOS's
// authentication sheet: a lock (a check once it worked), "Authentication
// Required" over polkit's message, the password as dots, Cancel and
// Authenticate. Fixed 408 x 160 so nothing reflows while the Island grows.
// Port of crates/shoji-island/src/island/auth.rs (:23-34 layout, :179-299
// view). The whole content shakes on a wrong password (Auth.shakeOffset).
//
// Keys go to a hidden password TextInput that keeps no text: each key is
// handed to Auth (Return submits, Escape cancels). The window must give the
// Island the keyboard while Auth.active (WP-D: WlrLayershell.keyboardFocus).

import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Item {
    id: root

    // island/mod.rs:169 EXPANDED width; auth.rs:23 HEIGHT.
    property real targetWidth: Theme.expandedWidth
    property real targetHeight: 160
    // island/mod.rs:171 EXPANDED_RADIUS.
    property real targetRadius: Theme.expandedRadius

    // auth.rs:24-33.
    readonly property real margin: 18
    readonly property real top: 16
    readonly property real header: 48
    readonly property real gap: 8
    readonly property real fieldTop: top + header + gap            // 72
    readonly property real fieldHeight: 34
    readonly property real buttonsTop: fieldTop + fieldHeight + gap // 114
    readonly property real buttonHeight: 30
    readonly property real buttonGap: 10
    readonly property real inner: targetWidth - 2 * margin          // 372
    readonly property real buttonWidth: (inner - buttonGap) / 2
    // auth.rs:84 MESSAGE_CHARS.
    readonly property int messageChars: 50
    // auth.rs:236-244: the hint's slot at the field's end.
    readonly property real hintWidth: 140

    // theme.rs label tiers (iOS dark); auth.rs colours, Rust #RRGGBBAA
    // rewritten as Qt's #AARRGGBB.
    readonly property color labelColor: Theme.label
    readonly property color secondaryColor: Theme.secondaryLabel
    readonly property color tertiaryColor: Theme.tertiaryLabel
    readonly property color symbolBackground: "#1fffffff"   // auth.rs:206 #ffffff1f
    readonly property color successBackground: "#3330d158"  // auth.rs:206 #30d15833
    readonly property color fieldBackground: "#1affffff"    // auth.rs:225 #ffffff1a
    readonly property color failureRed: "#ff453a"           // auth.rs:226, :244
    readonly property color hintColor: "#99ebebf5"          // auth.rs:244 #ebebf599
    readonly property color cancelBackground: "#24ffffff"   // auth.rs:262 #ffffff24
    // island/mod.rs:397-400 accent_fill: the accent's gradient, deep to light.
    readonly property color accentDeep: Theme.accentDeep
    readonly property color accentLight: Theme.accent
    readonly property string fontFamily: Theme.fontFamily

    readonly property bool failed: Auth.state === "failed"
    readonly property bool succeeded: Auth.state === "succeeded"
    readonly property var lines: root.messageLines(Auth.message, root.messageChars)
    readonly property string hint: Auth.state === "checking" ? "Checking…" : root.failed ? Auth.failureText : ""

    // auth.rs:86-105 message_lines: break at a word into two lines, the
    // second ending in "…" when it is still too long.
    function messageLines(message: string, chars: int): var {
        const words = message.split(/\s+/).filter(w => w.length > 0);
        const len = s => Array.from(s).length;
        let first = "";
        let i = 0;
        while (i < words.length) {
            const width = len(first) + (first === "" ? 0 : 1) + len(words[i]);
            if (width > chars && first !== "")
                break;
            first += (first === "" ? "" : " ") + words[i];
            i++;
        }
        const rest = words.slice(i).join(" ");
        let second = rest;
        if (len(rest) > chars)
            second = Array.from(rest).slice(0, chars - 1).join("").replace(/\s+$/, "") + "…";
        return [first, second];
    }

    function focusInput(): void {
        input.forceActiveFocus();
    }

    width: targetWidth
    height: targetHeight

    Component.onCompleted: root.focusInput()

    Connections {
        target: Auth
        function onActiveChanged() {
            if (Auth.active)
                root.focusInput();
        }
    }

    // Takes the keys; holds no text (the password lives in Auth).
    TextInput {
        id: input

        width: 1
        height: 1
        opacity: 0
        focus: true
        echoMode: TextInput.Password
        inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
        activeFocusOnPress: false

        Keys.onPressed: event => {
            event.accepted = true;
            switch (event.key) {
            case Qt.Key_Escape:
                Auth.cancel();
                return;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                Auth.submit();
                return;
            case Qt.Key_Backspace:
                Auth.backspace();
                return;
            }
            if (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier))
                return;
            if (event.text !== "")
                Auth.type(event.text);
        }
        // Text that arrives without a key event (an input method's commit).
        onTextEdited: {
            if (input.text !== "") {
                Auth.type(input.text);
                input.text = "";
            }
        }
    }

    Item {
        id: content

        x: Auth.shakeOffset
        width: root.targetWidth
        height: root.targetHeight

        // A modal prompt: a click outside the buttons only gives the field focus.
        MouseArea {
            anchors.fill: parent
            onPressed: root.focusInput()
        }

        // ---- header (auth.rs:200-221)
        Rectangle {
            id: symbol

            x: root.margin
            y: root.top + (root.header - height) / 2
            width: 40
            height: 40
            radius: 20
            color: root.succeeded ? root.successBackground : root.symbolBackground

            Icon {
                anchors.centerIn: parent
                size: 20
                name: root.succeeded ? "check" : "lock"
            }
        }

        Item {
            x: root.margin + 52
            y: root.top
            width: root.inner - 52
            height: root.header
            clip: true

            Column {
                width: parent.width
                spacing: 1

                Text {
                    width: parent.width
                    height: 19 // round(15 * 1.25)
                    verticalAlignment: Text.AlignVCenter
                    text: "Authentication Required"
                    color: root.labelColor
                    font.family: root.fontFamily
                    font.pixelSize: 15
                    font.weight: 600
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                Repeater {
                    model: root.lines

                    Text {
                        required property string modelData

                        width: parent.width
                        height: 14
                        verticalAlignment: Text.AlignVCenter
                        text: modelData
                        color: root.secondaryColor
                        font.family: root.fontFamily
                        font.pixelSize: 12
                        font.weight: 400
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        textFormat: Text.PlainText
                    }
                }
            }
        }

        // ---- field (auth.rs:223-247)
        Rectangle {
            id: field

            x: root.margin
            y: root.fieldTop
            width: root.inner
            height: root.fieldHeight
            radius: 10
            color: root.fieldBackground
            border.width: 1
            border.color: root.failed ? root.failureRed : "transparent"

            Text {
                x: 12
                width: root.inner - root.hintWidth
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: "•".repeat(Auth.typed)
                color: root.labelColor
                font.family: root.fontFamily
                font.pixelSize: 20
                font.weight: 700
                elide: Text.ElideLeft
                maximumLineCount: 1
            }
            Text {
                x: 12
                width: root.inner - root.hintWidth
                height: parent.height
                visible: Auth.typed === 0
                verticalAlignment: Text.AlignVCenter
                text: "Password for " + Auth.user
                color: root.tertiaryColor
                font.family: root.fontFamily
                font.pixelSize: 13
                font.weight: 400
                elide: Text.ElideRight
                maximumLineCount: 1
                textFormat: Text.PlainText
            }
            Text {
                x: parent.width - 12 - width
                width: root.hintWidth
                height: parent.height
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                text: root.hint
                color: root.failed ? root.failureRed : root.hintColor
                font.family: root.fontFamily
                font.pixelSize: 12
                font.weight: 500
                elide: Text.ElideRight
                maximumLineCount: 1
                textFormat: Text.PlainText
            }
        }

        // ---- buttons (auth.rs:249-286)
        Rectangle {
            x: root.margin
            y: root.buttonsTop
            width: root.buttonWidth
            height: root.buttonHeight
            radius: root.buttonHeight / 2
            color: root.cancelBackground
            opacity: cancelTap.pressed ? 0.7 : 1

            Text {
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "Cancel"
                color: root.labelColor
                font.family: root.fontFamily
                font.pixelSize: 13
                font.weight: 600
            }
            MouseArea {
                id: cancelTap

                anchors.fill: parent
                onClicked: Auth.cancel()
            }
        }

        Rectangle {
            x: root.margin + root.buttonWidth + root.buttonGap
            y: root.buttonsTop
            width: root.buttonWidth
            height: root.buttonHeight
            radius: root.buttonHeight / 2
            opacity: authTap.pressed ? 0.7 : 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: root.accentDeep
                }
                GradientStop {
                    position: 1
                    color: root.accentLight
                }
            }

            Text {
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "Authenticate"
                color: "#ffffff"
                font.family: root.fontFamily
                font.pixelSize: 13
                font.weight: 600
            }
            MouseArea {
                id: authTap

                anchors.fill: parent
                onClicked: {
                    Auth.submit();
                    root.focusInput();
                }
            }
        }
    }
}
