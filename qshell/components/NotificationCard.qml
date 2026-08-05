import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs.config
import qs.services

// One notification. Used by the popup stack (flat: false — bordered card
// with a drop shadow) and the bell menu list (flat: true — bare row on the
// menu surface). `wrapper` is a Notifs entry: { n: Notification, at: ms }.
Item {
    id: root

    required property var wrapper

    property bool flat: false

    readonly property real radius: Appearance.s(14)

    // n can go null for a frame while a dismissed notification is destroyed —
    // every read below is null-guarded.
    readonly property var n: wrapper?.n ?? null
    readonly property bool critical: n?.urgency === NotificationUrgency.Critical

    // The freedesktop "default" action is the body-click verb, not a button:
    // rendered as a pill it shows up literally labeled "default". It gets
    // filtered out of the pill row and wired to clicks instead.
    readonly property var defaultAction: (n?.actions ?? []).find(a => a.identifier === "default") ?? null
    readonly property var pillActions: (n?.actions ?? []).filter(a => a.identifier !== "default")

    // Menu mode only: a click unfolds the 3-line body cap.
    property bool expanded: false

    // The default action, with the same destroyed-mid-handler care as the
    // pills: invoke() usually closes the notification, killing this delegate.
    // In popup mode the animated exit starts BEFORE invoking — doDismiss with
    // requestDismiss set only starts an animation, nothing dies synchronously,
    // and the exit's own dismissal is null-guarded. In flat mode dismissal is
    // immediate, so it must stay AFTER invoke, using locals.
    function invokeDefault(): void {
        const notif = root.n;
        const act = root.defaultAction;
        const resident = notif?.resident ?? false;
        if (!act)
            return;
        if (root.requestDismiss) {
            if (notif && !resident)
                root.doDismiss();
            if (!Notifs.runAction(notif, act.identifier))
                act.invoke();
        } else {
            if (!Notifs.runAction(notif, act.identifier))
                act.invoke();
            if (!root.flat && notif && !resident)
                notif.dismiss();
        }
    }

    // What a body click (or Enter, from the menu's keyboard nav) does. Never
    // dismissal: destroying the notification was the old behavior, and in the
    // bell menu a misclick while scrolling silently ate it with no undo — the
    // × is the only dismissal now. Order matters: expand first, THEN the
    // default action on the next activation — a long-body notification with a
    // default action needs both reachable, and collapse loses to invoke (the
    // primary action beats re-folding; × still dismisses).
    function activate(): void {
        if (root.flat && body.truncated && !root.expanded)
            root.expanded = true;
        else if (root.defaultAction)
            root.invokeDefault();
        else if (root.flat && root.expanded)
            root.expanded = false;
        else if (!root.flat)
            root.doDismiss();
    }
    // A picture the notification is *about* (screenshot, album art, an
    // attachment) rather than an icon identifying its sender. Shown full width
    // under the body — the capture pipeline has been putting the path on the
    // card all along with nothing rendering it.
    readonly property string bigImage: {
        if (n?.image)
            return n.image;
        // qshell's own capture toasts carry the file as the app icon, which is
        // how the notification's buttons find it too.
        const ai = n?.appIcon ?? "";
        return /^\/.+\.(png|jpe?g|webp|gif|bmp)$/i.test(ai) ? `file://${ai}` : "";
    }

    readonly property string imageSource: {
        // The big preview already shows it; the small slot then identifies the
        // sender instead of repeating the picture at 34px.
        if (n?.image && root.bigImage === "")
            return n.image;
        if (n?.appIcon && root.bigImage !== `file://${n.appIcon}`)
            return Quickshell.iconPath(n.appIcon, true) || "";
        // Chat clients and portal-mediated Flatpaks often send no appIcon but
        // a valid desktopEntry (or at least a resolvable appName) — try both
        // before every card gets the same dim bell.
        const e = Apps.entryFor(n?.desktopEntry ?? "") ?? Apps.entryFor(n?.appName ?? "");
        return e?.icon ? (Quickshell.iconPath(e.icon, true) || "") : "";
    }

    // True while the reply field holds focus. The popup stack watches this to
    // take the keyboard — a layer surface that never asks for it can't be
    // typed into, and toasts deliberately don't ask by default.
    property bool replying: false

    function sendReply(): void {
        const notif = root.n;
        const text = replyField.text;
        if (!notif?.hasInlineReply || text === "")
            return;
        replyField.text = "";
        replyField.focus = false;
        notif.sendInlineReply(text);
        // Chat clients close the notification themselves once the reply lands;
        // the ones that don't would otherwise leave a card sitting there
        // looking unsent.
        if (!(notif.resident ?? false))
            root.doDismiss();
    }

    // The popup stack swaps in an animated exit before the real dismissal —
    // everything that dismisses goes through here so both paths animate.
    property var requestDismiss: null

    function doDismiss(): void {
        if (root.requestDismiss)
            root.requestDismiss();
        else
            root.n?.dismiss();
    }

    // Via a HoverHandler on the root, NOT cardArea.containsMouse: the close
    // button and action pills are hover-enabled MouseAreas stacked above the
    // card area that steal mouse hover — and pausing expiry is needed most
    // exactly while the pointer rests on those targets.
    readonly property bool hovered: hh.hovered

    HoverHandler {
        id: hh
    }

    function ago(): string {
        // wrapper can legitimately be null — the bell menu's flat row delegate
        // holds one card for every row shape, including the headers.
        const s = Math.max(0, (Notifs.now - (wrapper?.at ?? Notifs.now)) / 1000);
        if (s < 60)
            return "now";
        if (s < 3600)
            return `${Math.floor(s / 60)}m`;
        if (s < 86400)
            return `${Math.floor(s / 3600)}h`;
        return `${Math.floor(s / 86400)}d`;
    }

    implicitHeight: content.implicitHeight + Appearance.s(24)

    Elevation {
        visible: !root.flat
        anchors.fill: bg
        radius: root.radius
        level: 3
    }

    Rectangle {
        id: bg

        anchors.fill: parent
        radius: root.radius
        color: root.flat ? "transparent" : Theme.surfaceBg
        border.width: root.flat ? 0 : 1
        border.color: root.critical ? Theme.urgent : Theme.surfaceBorder
    }

    MouseArea {
        id: cardArea

        anchors.fill: parent
        // Hover state feeds the popup stack's expiry pause.
        hoverEnabled: true
        // The hand only where a click does something, so an inert card
        // doesn't advertise one.
        cursorShape: !root.flat || root.defaultAction || body.truncated || root.expanded ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.activate()
    }

    Column {
        id: content

        x: Appearance.s(12)
        y: Appearance.s(12)
        width: parent.width - Appearance.s(24)
        spacing: Appearance.s(6)

        Item {
            width: parent.width
            implicitHeight: Math.max(iconBox.implicitHeight, textCol.implicitHeight)

            ClippingRectangle {
                id: iconBox

                implicitWidth: Appearance.s(34)
                implicitHeight: Appearance.s(34)
                radius: Appearance.s(8)
                color: "transparent"
                visible: root.imageSource !== ""

                Image {
                    anchors.fill: parent
                    source: root.imageSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            FIcon {
                visible: root.imageSource === ""
                anchors.verticalCenter: iconBox.verticalCenter
                width: iconBox.visible ? 0 : Appearance.s(34)
                icon: "bell_fill"
                font.pixelSize: Appearance.s(19)
                color: Theme.surfaceFgDim
            }

            Column {
                id: textCol

                anchors.left: parent.left
                anchors.leftMargin: Appearance.s(44)
                anchors.right: closeBtn.left
                anchors.rightMargin: Appearance.s(8)
                spacing: Appearance.s(1)

                Item {
                    width: parent.width
                    implicitHeight: appLabel.implicitHeight

                    // Critical treatment in the menu: flat mode has no border,
                    // so once a critical toast landed in the bell menu it
                    // looked like everything else.
                    Rectangle {
                        id: urgentDot

                        visible: root.flat && root.critical
                        anchors.left: parent.left
                        anchors.verticalCenter: appLabel.verticalCenter
                        width: Appearance.s(7)
                        height: width
                        radius: width / 2
                        color: Theme.urgent
                    }

                    StyledText {
                        id: appLabel

                        anchors.left: parent.left
                        anchors.leftMargin: urgentDot.visible ? Appearance.s(11) : 0
                        anchors.right: timeLabel.left
                        text: root.n?.appName || "notification"
                        color: Theme.surfaceFgDim
                        font.pixelSize: Appearance.font.size.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        id: timeLabel

                        anchors.right: parent.right
                        text: root.ago()
                        color: Theme.surfaceFgDim
                        font.pixelSize: Appearance.font.size.small
                    }
                }

                StyledText {
                    width: parent.width
                    text: root.n?.summary ?? ""
                    color: Theme.surfaceFg
                    elide: Text.ElideRight
                }

                StyledText {
                    id: body

                    width: parent.width
                    visible: (root.n?.body?.length ?? 0) > 0
                    text: root.n?.body ?? ""
                    textFormat: Text.StyledText
                    color: Theme.surfaceFgDim
                    font.pixelSize: Appearance.font.size.small
                    font.weight: Font.Normal
                    wrapMode: Text.Wrap
                    // Toasts stay capped; in the menu a click unfolds the rest
                    // (the whole shell had nowhere to read a long body).
                    maximumLineCount: root.expanded ? 10000 : 3
                    elide: Text.ElideRight
                    // Links used to render styled and then dismiss the
                    // notification when clicked — the card MouseArea sits
                    // below this Text, so link clicks stop here.
                    linkColor: Theme.accent
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }
            }

            Item {
                id: closeBtn

                anchors.right: parent.right
                width: Appearance.s(22)
                height: Appearance.s(22)

                StateLayer {
                    radius: width / 2
                    color: Theme.surfaceFg
                    onClicked: root.doDismiss()
                }

                FIcon {
                    anchors.centerIn: parent
                    icon: "xmark"
                    color: Theme.surfaceFgDim
                    font.pixelSize: Appearance.font.size.small
                }
            }
        }

        // What the notification is about, when that's a picture. Cropped to a
        // band rather than fit: a full-height screenshot would make the card
        // taller than the toast stack, and the point is recognition, not
        // inspection — clicking opens the file.
        ClippingRectangle {
            width: parent.width
            height: visible ? Math.min(Appearance.s(150), width * 0.5) : 0
            visible: root.bigImage !== "" && preview.status === Image.Ready
            radius: Appearance.s(10)
            color: Qt.alpha(Theme.surfaceFg, 0.06)

            Image {
                id: preview

                anchors.fill: parent
                source: root.bigImage
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                sourceSize.width: Appearance.s(760)
            }
        }

        // Inline reply, for the clients that ask for it (the server advertises
        // the capability now — it always could, it just didn't say so). Enter
        // sends; the field only exists on cards that carry the hint.
        Rectangle {
            id: replyBox

            width: parent.width
            height: visible ? Appearance.s(32) : 0
            visible: root.n?.hasInlineReply ?? false
            radius: height / 2
            color: Theme.surfaceHoverBg

            // The pill's padding — the bands above and below the one-line
            // field, and the left inset — take no input of their own, so a
            // press there fell through to the card and *dismissed* the
            // notification you were aiming to reply to. Declared first so the
            // field and the send button stay above it.
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onClicked: replyField.forceActiveFocus()
            }

            TextInput {
                id: replyField

                anchors.left: parent.left
                anchors.leftMargin: Appearance.s(14)
                anchors.right: sendBtn.left
                anchors.rightMargin: Appearance.s(6)
                anchors.verticalCenter: parent.verticalCenter

                color: Theme.surfaceFg
                font.family: Appearance.font.family
                font.pixelSize: Appearance.font.size.small
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentFg
                clip: true

                // The surface holding this card has to take the keyboard for
                // typing to arrive; the popup window watches this.
                onActiveFocusChanged: root.replying = activeFocus

                onAccepted: root.sendReply()
                // Esc gives the field back before the panel takes the key —
                // otherwise starting a reply and changing your mind closes the
                // whole notification centre.
                Keys.onEscapePressed: event => {
                    if (replyField.text !== "") {
                        replyField.text = "";
                        event.accepted = true;
                    } else {
                        replyField.focus = false;
                        event.accepted = true;
                    }
                }

                StyledText {
                    visible: !replyField.text
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.n?.inlineReplyPlaceholder || "Reply…"
                    color: Theme.surfaceFgDim
                    font.pixelSize: Appearance.font.size.small
                }
            }

            Item {
                id: sendBtn

                anchors.right: parent.right
                anchors.rightMargin: Appearance.s(3)
                anchors.verticalCenter: parent.verticalCenter
                width: Appearance.s(26)
                height: width

                StateLayer {
                    radius: width / 2
                    color: Theme.surfaceFg
                    enabled: replyField.text !== ""
                    onClicked: root.sendReply()
                }

                FIcon {
                    anchors.centerIn: parent
                    icon: "arrow_up_circle_fill"
                    font.pixelSize: Appearance.s(16)
                    color: replyField.text !== "" ? Theme.accent : Theme.surfaceFgDim
                }
            }
        }

        // Flow, not Row: three actions or long localized labels used to paint
        // straight past the card's rounded edge.
        Flow {
            width: parent.width
            visible: root.pillActions.length > 0
            spacing: Appearance.s(6)

            Repeater {
                model: root.pillActions

                Rectangle {
                    required property NotificationAction modelData

                    implicitWidth: Math.min(actionLabel.implicitWidth + Appearance.s(20), Appearance.s(220))
                    implicitHeight: Appearance.s(26)
                    radius: height / 2
                    color: Theme.surfaceHoverBg
                    clip: true

                    StateLayer {
                        radius: parent.radius
                        color: Theme.surfaceFg
                        // Everything is read into locals *before* invoking:
                        // invoke() usually makes the client close the
                        // notification, which drops it from the model and
                        // destroys this delegate mid-handler. The rest of the
                        // function then runs without a QML context, and
                        // `root` — the card — resolves to nothing.
                        // (Observed: "ReferenceError: root is not defined",
                        // which is why action buttons appeared to do nothing.)
                        // Popup mode starts the animated exit before invoking
                        // (safe: it only starts an animation); flat mode keeps
                        // dismissal after, via the locals.
                        onClicked: {
                            const notif = root.n;
                            const act = parent.modelData;
                            const resident = notif?.resident ?? false;
                            if (root.requestDismiss) {
                                if (notif && !resident)
                                    root.doDismiss();
                                if (!Notifs.runAction(notif, act.identifier))
                                    act.invoke();
                            } else {
                                if (!Notifs.runAction(notif, act.identifier))
                                    act.invoke();
                                if (notif && !resident)
                                    notif.dismiss();
                            }
                        }
                    }

                    StyledText {
                        id: actionLabel

                        anchors.centerIn: parent
                        text: parent.modelData.text || parent.modelData.identifier
                        color: Theme.surfaceFg
                        font.pixelSize: Appearance.font.size.small
                    }
                }
            }
        }
    }
}
