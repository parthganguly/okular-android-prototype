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
    readonly property real thumbnailStripHeight: Math.max(72, Kirigami.Units.gridUnit * 3.9)
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

    function shareCurrentDocument() {
        if (typeof uriHandler !== "undefined") {
            root.keepControlsWarm()
            uriHandler.shareCurrentDocument()
        }
    }

    function confirmDeleteCurrentDocument() {
        if (typeof uriHandler !== "undefined") {
            root.keepControlsWarm()
            deleteDocumentDialog.open()
        }
    }

    function returnToLibrary() {
        contextDrawer.drawerOpen = false
        applicationWindow().controlsVisible = false
        document.close()
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

        function onUrlChanged() {
            pageArea.trimMargins = false
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
                id: libraryBackButton
                text: i18n("Library")
                display: QQC2.AbstractButton.TextOnly
                Layout.preferredWidth: root.compactControls
                        ? root.toolbarContentHeight
                        : Math.max(root.toolbarContentHeight * 1.9, libraryBackButtonContent.implicitWidth + 18)
                Layout.preferredHeight: root.toolbarContentHeight
                contentItem: RowLayout {
                    id: libraryBackButtonContent
                    spacing: Math.max(2, Math.round(Kirigami.Units.smallSpacing * 0.25))

                    QQC2.Label {
                        text: "\u2039"
                        color: Kirigami.Theme.textColor
                        font.pixelSize: Math.round(root.toolbarContentHeight * 0.82)
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        Layout.preferredWidth: Math.round(root.toolbarContentHeight * 0.42)
                        Layout.fillHeight: true
                    }

                    QQC2.Label {
                        visible: !root.compactControls
                        text: libraryBackButton.text
                        color: Kirigami.Theme.textColor
                        font.pixelSize: Math.max(11, Math.round(Kirigami.Units.gridUnit * 0.70))
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                onClicked: {
                    root.returnToLibrary()
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
                text: i18n("Share")
                display: QQC2.AbstractButton.TextOnly
                Layout.preferredHeight: root.toolbarContentHeight
                onClicked: root.shareCurrentDocument()
            }

            QQC2.ToolButton {
                text: root.compactControls ? i18n("Del") : i18n("Delete")
                display: QQC2.AbstractButton.TextOnly
                Layout.preferredHeight: root.toolbarContentHeight
                onClicked: root.confirmDeleteCurrentDocument()
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

    QQC2.Dialog {
        id: deleteDocumentDialog
        modal: true
        focus: true
        anchors.centerIn: parent
        title: i18n("Delete File?")
        standardButtons: QQC2.Dialog.Yes | QQC2.Dialog.Cancel

        contentItem: QQC2.Label {
            text: i18n("Delete this file from storage? This cannot be undone.")
            wrapMode: Text.WordWrap
            width: Math.min(root.width - Kirigami.Units.gridUnit * 3, Kirigami.Units.gridUnit * 18)
        }

        onAccepted: {
            if (typeof uriHandler !== "undefined" && uriHandler.deleteCurrentDocument()) {
                root.returnToLibrary()
            }
        }
    }

    Rectangle {
        id: topThumbnailStrip
        z: 100
        visible: root.chromeVisible && document.pageCount > 1
        anchors {
            top: readerToolbar.bottom
            left: readerToolbar.left
            right: readerToolbar.right
            topMargin: Math.round(Kirigami.Units.smallSpacing * 0.75)
        }
        height: root.thumbnailStripHeight
        radius: Math.round(Kirigami.Units.gridUnit * 0.9)
        color: root.readerToolbarSurface
        border.color: root.readerToolbarBorder
        clip: true

        ListView {
            id: pageThumbnailList
            anchors {
                fill: parent
                leftMargin: Kirigami.Units.smallSpacing
                rightMargin: Kirigami.Units.smallSpacing
                topMargin: Kirigami.Units.smallSpacing
                bottomMargin: Kirigami.Units.smallSpacing
            }
            orientation: ListView.Horizontal
            boundsBehavior: Flickable.StopAtBounds
            spacing: Kirigami.Units.smallSpacing
            model: document.pageCount
            currentIndex: document.currentPage
            clip: true

            delegate: Rectangle {
                id: thumbnailCard
                required property int index

                width: Math.round(topThumbnailStrip.height * 0.62)
                height: pageThumbnailList.height
                radius: Math.round(Kirigami.Units.smallSpacing * 0.8)
                color: index === document.currentPage ? Qt.rgba(0.91, 0.12, 0.39, 0.12) : "#ffffff"
                border.width: index === document.currentPage ? 2 : 1
                border.color: index === document.currentPage ? root.readerToolbarAccentColor : root.readerToolbarBorder
                clip: true

                Okular.ThumbnailItem {
                    anchors {
                        fill: parent
                        margins: Math.round(Kirigami.Units.smallSpacing * 0.45)
                    }
                    document: root.document
                    pageNumber: thumbnailCard.index
                }

                Rectangle {
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                        margins: 2
                    }
                    width: Math.max(18, pageNumberLabel.implicitWidth + 8)
                    height: Math.max(16, pageNumberLabel.implicitHeight + 3)
                    radius: height / 2
                    color: index === document.currentPage ? root.readerToolbarAccentColor : Qt.rgba(0.98, 0.97, 0.94, 0.88)

                    QQC2.Label {
                        id: pageNumberLabel
                        anchors.centerIn: parent
                        text: thumbnailCard.index + 1
                        color: thumbnailCard.index === document.currentPage ? "#ffffff" : root.readerToolbarMutedColor
                        font.pixelSize: Math.max(9, Math.round(Kirigami.Units.gridUnit * 0.5))
                        font.bold: thumbnailCard.index === document.currentPage
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        document.currentPage = thumbnailCard.index
                        pageThumbnailList.currentIndex = thumbnailCard.index
                        pageThumbnailList.positionViewAtIndex(thumbnailCard.index, ListView.Center)
                        root.keepControlsWarm()
                    }
                }
            }

            onVisibleChanged: {
                if (visible) {
                    positionViewAtIndex(document.currentPage, ListView.Center)
                }
            }
        }

        Connections {
            target: document
            function onCurrentPageChanged() {
                if (topThumbnailStrip.visible) {
                    pageThumbnailList.currentIndex = document.currentPage
                    pageThumbnailList.positionViewAtIndex(document.currentPage, ListView.Center)
                }
            }
        }
    }

    Rectangle {
        z: 99
        visible: readerToolbar.visible
        anchors {
            top: topThumbnailStrip.visible ? topThumbnailStrip.bottom : readerToolbar.bottom
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
