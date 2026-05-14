/*
    SPDX-FileCopyrightText: 2012 Marco Martin <mart@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.okular as Okular
import org.kde.kirigami as Kirigami

Kirigami.Page {
    id: root

    property alias document: pageArea.document
    property alias page: pageArea.page
    readonly property bool chromeVisible: document.opened && applicationWindow().controlsVisible
    readonly property bool compactControls: width < Kirigami.Units.gridUnit * 36
    readonly property real toolbarTopInset: Math.max(0, fileBrowserRoot.topSystemInset)
    readonly property real toolbarContentHeight: Math.max(48, Math.min(54, Kirigami.Units.gridUnit * 2.55))
    readonly property color readerToolbarSurface: Qt.rgba(0.98, 0.97, 0.94, 0.95)
    readonly property color readerToolbarBorder: Qt.rgba(0.12, 0.10, 0.08, 0.16)
    readonly property color readerToolbarTextColor: "#24211f"
    readonly property color readerToolbarMutedColor: Qt.rgba(0.10, 0.09, 0.08, 0.62)
    readonly property color readerToolbarAccentColor: "#e91e63"

    function revealControls() {
        if (!document.opened) {
            return
        }
        applicationWindow().controlsVisible = true
        autoHideControls.restart()
    }

    function hideControls() {
        autoHideControls.stop()
        applicationWindow().controlsVisible = false
    }

    function keepControlsWarm() {
        if (root.chromeVisible) {
            autoHideControls.restart()
        }
    }

    leftPadding: 0
    topPadding: 0
    rightPadding: 0
    bottomPadding: 0
    background: Rectangle {
        color: document.opened ? "#111316" : Kirigami.Theme.backgroundColor
    }

    Okular.DocumentView {
        id: pageArea
        fitMode: fileBrowserRoot.readerFitMode
        continuousMode: fileBrowserRoot.readerContinuousMode
        anchors {
            fill: parent
        }

        onClicked: {
            if (root.chromeVisible) {
                root.hideControls()
            } else {
                root.revealControls()
            }
        }
        onUrlOpened: welcomeView.saveRecentDocument(document.url)
    }

    Connections {
        target: root.document

        function onError(text, duration) {
            inlineMessage.showMessage(Kirigami.MessageType.Error, text,  duration);
        }

        function onWarning(text, duration) {
            inlineMessage.showMessage(Kirigami.MessageType.Warning, text,  duration);
        }

        function onNotice(text, duration) {
            inlineMessage.showMessage(Kirigami.MessageType.Information, text,  duration);
        }
    }

    Kirigami.InlineMessage {
        id: inlineMessage

        width: parent.width
        position: Kirigami.InlineMessage.Header

        function showMessage(type, text, duration) {
            inlineMessage.type = type;
            inlineMessage.text = text;
            inlineMessage.visible = true;
            inlineMessageTimer.interval = duration > 0 ? duration : 500 + 100 * text.length;
        }

        onVisibleChanged: {
            if (visible) {
                inlineMessageTimer.start()
            } else {
                inlineMessageTimer.stop()
            }
        }

        Timer {
            id: inlineMessageTimer
            onTriggered: inlineMessage.visible = false
        }
    }

    WelcomeView {
        id: welcomeView
    }

    Timer {
        id: autoHideControls
        interval: 3600
        repeat: false
        onTriggered: {
            if (!contextDrawer.drawerOpen) {
                applicationWindow().controlsVisible = false
            }
        }
    }

    Connections {
        target: contextDrawer

        function onDrawerOpenChanged() {
            if (contextDrawer.drawerOpen) {
                applicationWindow().controlsVisible = true
                autoHideControls.stop()
            } else if (root.chromeVisible) {
                autoHideControls.restart()
            }
        }
    }

    Rectangle {
        id: readerToolbar
        z: 100
        visible: root.chromeVisible
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: root.toolbarTopInset + Math.round(Kirigami.Units.smallSpacing * 0.75)
            leftMargin: Math.round(Kirigami.Units.smallSpacing * 0.75)
            rightMargin: Math.round(Kirigami.Units.smallSpacing * 0.75)
        }
        height: root.toolbarContentHeight
        radius: Math.round(height * 0.36)
        color: root.readerToolbarSurface
        border.color: root.readerToolbarBorder
        Kirigami.Theme.inherit: false
        Kirigami.Theme.colorSet: Kirigami.Theme.View
        Kirigami.Theme.textColor: root.readerToolbarTextColor
        Kirigami.Theme.highlightColor: root.readerToolbarAccentColor

        RowLayout {
            anchors {
                fill: parent
                leftMargin: Math.max(6, Kirigami.Units.smallSpacing)
                rightMargin: Math.max(6, Kirigami.Units.smallSpacing)
                bottomMargin: 0
            }
            spacing: Math.max(3, Kirigami.Units.smallSpacing / 2)

            QQC2.ToolButton {
                icon.name: "document-open"
                text: i18n("Open")
                display: root.compactControls ? QQC2.AbstractButton.IconOnly : QQC2.AbstractButton.TextBesideIcon
                icon.color: Kirigami.Theme.textColor
                Layout.preferredHeight: root.toolbarContentHeight
                onClicked: {
                    root.keepControlsWarm()
                    openDocumentAction.trigger()
                }
            }

            QQC2.Label {
                visible: !root.compactControls
                text: document.windowTitleForDocument ? document.windowTitleForDocument : i18n("Okular")
                color: Kirigami.Theme.textColor
                elide: Text.ElideMiddle
                Layout.fillWidth: visible
            }

            Rectangle {
                visible: document.pageCount > 0
                color: Qt.rgba(0.91, 0.89, 0.85, 0.82)
                radius: Math.round(height * 0.28)
                border.color: Qt.rgba(0.12, 0.10, 0.08, 0.08)
                Layout.preferredWidth: root.compactControls ? Kirigami.Units.gridUnit * 3.1 : Kirigami.Units.gridUnit * 4.1
                Layout.preferredHeight: Math.max(28, root.toolbarContentHeight - 10)

                QQC2.Label {
                    anchors.centerIn: parent
                    text: i18nc("current page and page count", "%1 / %2", document.currentPage + 1, document.pageCount)
                    color: root.readerToolbarMutedColor
                    font.pixelSize: Math.max(11, Math.round(Kirigami.Units.gridUnit * 0.68))
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            QQC2.ToolButton {
                icon.name: pageArea.page.bookmarked ? "bookmark-remove" : "bookmarks-organize"
                text: pageArea.page.bookmarked ? i18n("Saved") : i18n("Mark")
                display: root.compactControls ? QQC2.AbstractButton.IconOnly : QQC2.AbstractButton.TextBesideIcon
                icon.color: Kirigami.Theme.textColor
                checkable: true
                checked: pageArea.page.bookmarked
                Layout.preferredHeight: root.toolbarContentHeight
                onClicked: {
                    root.keepControlsWarm()
                    pageArea.page.bookmarked = !pageArea.page.bookmarked
                }
            }

            QQC2.ToolButton {
                text: i18n("Crop")
                display: QQC2.AbstractButton.TextOnly
                checkable: true
                checked: pageArea.trimMargins
                Layout.preferredHeight: root.toolbarContentHeight
                onClicked: {
                    root.keepControlsWarm()
                    pageArea.trimMargins = checked
                }
            }

            QQC2.ToolButton {
                text: fileBrowserRoot.readerContinuousMode ? i18n("Scroll") : i18n("Flip")
                display: QQC2.AbstractButton.TextOnly
                checkable: true
                checked: fileBrowserRoot.readerContinuousMode
                Layout.preferredHeight: root.toolbarContentHeight
                onClicked: {
                    root.keepControlsWarm()
                    fileBrowserRoot.readerContinuousMode = checked
                    if (checked && fileBrowserRoot.readerFitMode === fileBrowserRoot.fillScreenMode) {
                        fileBrowserRoot.readerFitMode = fileBrowserRoot.fitWidthMode
                    }
                }
            }

            QQC2.ToolButton {
                text: pageArea.fitMode === fileBrowserRoot.fitWidthMode ? i18n("Width") : pageArea.fitMode === fileBrowserRoot.fitPageMode ? i18n("Page") : i18n("Fill")
                display: QQC2.AbstractButton.TextOnly
                Layout.preferredHeight: root.toolbarContentHeight
                onClicked: {
                    root.keepControlsWarm()
                    fileBrowserRoot.readerFitMode = (fileBrowserRoot.readerFitMode + 1) % 3
                }
            }

            QQC2.ToolButton {
                icon.name: "view-preview"
                text: i18n("Nav")
                display: root.compactControls ? QQC2.AbstractButton.IconOnly : QQC2.AbstractButton.TextBesideIcon
                icon.color: Kirigami.Theme.textColor
                Layout.preferredHeight: root.toolbarContentHeight
                onClicked: {
                    contextDrawer.drawerOpen = !contextDrawer.drawerOpen
                    root.keepControlsWarm()
                }
            }
        }
    }

    Rectangle {
        z: 99
        visible: readerToolbar.visible
        anchors {
            top: readerToolbar.bottom
            left: parent.left
            right: parent.right
        }
        height: Kirigami.Units.gridUnit
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop {
                position: 0.0
                color: Qt.rgba(0, 0, 0, 0.16)
            }
            GradientStop {
                position: 1.0
                color: "transparent"
            }
        }
    }

    Rectangle {
        id: progressTrack
        z: 99
        visible: document.opened
        opacity: root.chromeVisible ? 1 : 0.38
        height: root.chromeVisible ? Math.max(3, Math.round(Kirigami.Units.smallSpacing / 2)) : 2
        color: Qt.rgba(0.14, 0.15, 0.16, root.chromeVisible ? 0.32 : 0.12)
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            bottomMargin: root.chromeVisible ? fileBrowserRoot.bottomSystemInset : 0
        }

        Rectangle {
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }
            width: parent.width * (document.pageCount > 0 ? ((document.currentPage + 1) / document.pageCount) : 0)
            color: root.readerToolbarAccentColor
        }
    }
}
