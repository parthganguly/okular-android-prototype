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
    readonly property color readerToolbarTextColor: "#24211F"
    readonly property color readerToolbarMutedColor: Qt.rgba(0.10, 0.09, 0.08, 0.62)
    readonly property color primaryAccentColor: "#D81B60"
    property bool moreActionsVisible: false
    property var ttsEngines: []
    property var ttsVoices: []
    property string ttsState: "initializing"
    property string ttsErrorCode: ""
    property string ttsStatusMessage: ""
    property string ttsEnginePackage: ""
    property string ttsVoiceName: ""
    property real ttsRate: 1.0
    property int ttsRequestedPage: -1
    property bool ttsWaitingForText: false

    function revealControls() {
        if (!document.opened) {
            return
        }
        applicationWindow().controlsVisible = true
        autoHideControls.restart()
    }

    function hideControls() {
        autoHideControls.stop()
        root.moreActionsVisible = false
        applicationWindow().controlsVisible = false
    }

    function keepControlsWarm() {
        if (root.chromeVisible) {
            autoHideControls.restart()
        }
    }

    function parseJsonArray(json) {
        if (!json) {
            return []
        }
        try {
            const value = JSON.parse(json)
            return Array.isArray(value) ? value : []
        } catch (error) {
            return []
        }
    }

    function refreshTtsState() {
        if (typeof uriHandler === "undefined") {
            root.ttsState = "unavailable"
            root.ttsErrorCode = "init_failed"
            return
        }

        try {
            const state = JSON.parse(uriHandler.ttsStateJson())
            root.ttsState = state.state || "unavailable"
            root.ttsErrorCode = state.errorCode || ""
            root.ttsStatusMessage = state.message || ""
            root.ttsEnginePackage = state.enginePackage || root.ttsEnginePackage
            root.ttsVoiceName = state.voiceName || root.ttsVoiceName
            if (state.rate > 0) {
                root.ttsRate = state.rate
            }
        } catch (error) {
            root.ttsState = "unavailable"
            root.ttsErrorCode = "init_failed"
        }
    }

    function refreshTtsDiscovery() {
        if (typeof uriHandler === "undefined") {
            root.ttsEngines = []
            root.ttsVoices = []
            return
        }
        root.ttsEngines = root.parseJsonArray(uriHandler.ttsEnginesJson())
        if (!root.ttsEnginePackage && root.ttsEngines.length > 0) {
            for (let i = 0; i < root.ttsEngines.length; ++i) {
                if (root.ttsEngines[i].selected || root.ttsEngines[i].isDefault) {
                    root.ttsEnginePackage = root.ttsEngines[i]["package"]
                    break
                }
            }
        }
        root.ttsVoices = root.parseJsonArray(uriHandler.ttsVoicesJson(root.ttsEnginePackage))
    }

    function refreshTtsData() {
        root.refreshTtsState()
        root.refreshTtsDiscovery()
    }

    function ttsEngineIndex() {
        for (let i = 0; i < root.ttsEngines.length; ++i) {
            if (root.ttsEngines[i]["package"] === root.ttsEnginePackage) {
                return i
            }
        }
        return root.ttsEngines.length > 0 ? 0 : -1
    }

    function ttsVoiceIndex() {
        for (let i = 0; i < root.ttsVoices.length; ++i) {
            if (root.ttsVoices[i].name === root.ttsVoiceName || root.ttsVoices[i].selected) {
                return i
            }
        }
        return root.ttsVoices.length > 0 ? 0 : -1
    }

    function friendlyTtsStatus() {
        if (root.ttsWaitingForText) {
            return i18n("Preparing text from page %1...", root.ttsRequestedPage + 1)
        }
        if (root.ttsState === "initializing") {
            return i18n("Preparing Android text-to-speech...")
        }
        if (root.ttsEngines.length === 0) {
            return i18n("No TTS engine installed.")
        }
        if (root.ttsErrorCode === "missing_voice_data") {
            return i18n("Voice data missing; install voice data in Android TTS settings.")
        }
        if (root.ttsState === "error") {
            return root.ttsStatusMessage || i18n("TTS engine failed to initialize.")
        }
        if (root.ttsState === "speaking") {
            return i18n("Reading page %1", root.ttsRequestedPage + 1)
        }
        if (!document.supportsSearching) {
            return i18n("This document does not expose extractable text. Scanned pages need OCR, which is not included yet.")
        }
        return i18n("Ready to read the current page with Android's installed TTS engine.")
    }

    function openTtsPanel() {
        root.moreActionsVisible = false
        applicationWindow().controlsVisible = true
        autoHideControls.stop()
        root.refreshTtsData()
        ttsPanel.open()
    }

    function playCurrentPage() {
        root.refreshTtsData()
        if (root.ttsState === "initializing") {
            inlineMessage.showMessage(Kirigami.MessageType.Information, i18n("Preparing Android text-to-speech..."), 2500)
            return
        }
        if (root.ttsEngines.length === 0) {
            inlineMessage.showMessage(Kirigami.MessageType.Error, i18n("No TTS engine installed."), 4000)
            return
        }
        if (!document.supportsSearching) {
            inlineMessage.showMessage(Kirigami.MessageType.Warning, i18n("This page has no extractable text. Scanned PDFs need OCR later."), 4500)
            return
        }

        root.ttsRequestedPage = document.currentPage
        root.ttsWaitingForText = true
        document.requestTextForPage(root.ttsRequestedPage)
    }

    function stopTts() {
        root.ttsWaitingForText = false
        root.ttsRequestedPage = -1
        if (typeof uriHandler !== "undefined") {
            uriHandler.ttsStop()
            root.refreshTtsData()
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

    function toggleBookmark() {
        root.keepControlsWarm()
        pageArea.page.bookmarked = !pageArea.page.bookmarked
    }

    function toggleCrop() {
        root.keepControlsWarm()
        pageArea.trimMargins = !pageArea.trimMargins
    }

    function returnToLibrary() {
        contextDrawer.drawerOpen = false
        root.moreActionsVisible = false
        ttsPanel.close()
        root.stopTts()
        applicationWindow().controlsVisible = false
        document.close()
        if (typeof uriHandler !== "undefined") {
            uriHandler.clearCurrentDocument()
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
        anchors.fill: parent

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
            root.stopTts()
        }

        function onCurrentPageChanged() {
            if (root.ttsWaitingForText || root.ttsState === "speaking") {
                root.stopTts()
            }
        }

        function onPageTextReady(pageNumber, text) {
            if (!root.ttsWaitingForText || pageNumber !== root.ttsRequestedPage) {
                return
            }
            root.ttsWaitingForText = false
            if (!text || !text.trim()) {
                inlineMessage.showMessage(Kirigami.MessageType.Warning, i18n("This page has no extractable text. Scanned PDFs need OCR later."), 4500)
                return
            }
            if (typeof uriHandler === "undefined" || !uriHandler.ttsSpeak(text)) {
                root.refreshTtsData()
                const message = root.ttsErrorCode === "missing_voice_data"
                        ? i18n("Voice data missing; install voice data in Android TTS settings.")
                        : i18n("TTS engine failed to initialize.")
                inlineMessage.showMessage(Kirigami.MessageType.Error, message, 4500)
                return
            }
            root.refreshTtsData()
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
            if (!contextDrawer.drawerOpen && !ttsPanel.visible) {
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
        Kirigami.Theme.highlightColor: root.primaryAccentColor

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
                text: document.windowTitleForDocument ? document.windowTitleForDocument : i18n("Parthicle Reader")
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
                visible: !root.compactControls
                display: root.compactControls ? QQC2.AbstractButton.IconOnly : QQC2.AbstractButton.TextBesideIcon
                icon.color: Kirigami.Theme.textColor
                checkable: true
                checked: pageArea.page.bookmarked
                Layout.preferredHeight: root.toolbarContentHeight
                onClicked: root.toggleBookmark()
            }

            QQC2.ToolButton {
                text: i18n("Crop")
                visible: !root.compactControls
                display: QQC2.AbstractButton.TextOnly
                checkable: true
                checked: pageArea.trimMargins
                Layout.preferredHeight: root.toolbarContentHeight
                onClicked: root.toggleCrop()
            }

            QQC2.ToolButton {
                text: fileBrowserRoot.readerContinuousMode ? i18n("Scroll") : i18n("Flip")
                display: QQC2.AbstractButton.TextOnly
                checkable: true
                checked: fileBrowserRoot.readerContinuousMode
                Layout.preferredHeight: root.toolbarContentHeight
                Layout.preferredWidth: root.compactControls ? Kirigami.Units.gridUnit * 3.65 : implicitWidth
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
                Layout.preferredWidth: root.compactControls ? Kirigami.Units.gridUnit * 3.35 : implicitWidth
                onClicked: {
                    root.keepControlsWarm()
                    fileBrowserRoot.readerFitMode = (fileBrowserRoot.readerFitMode + 1) % 3
                }
            }

            QQC2.ToolButton {
                text: i18n("Share")
                visible: !root.compactControls
                display: QQC2.AbstractButton.TextOnly
                Layout.preferredHeight: root.toolbarContentHeight
                onClicked: root.shareCurrentDocument()
            }

            QQC2.ToolButton {
                text: root.compactControls ? i18n("Del") : i18n("Delete")
                visible: !root.compactControls
                display: QQC2.AbstractButton.TextOnly
                Layout.preferredHeight: root.toolbarContentHeight
                onClicked: root.confirmDeleteCurrentDocument()
            }

            QQC2.ToolButton {
                id: moreActionsButton
                visible: typeof uriHandler !== "undefined" || root.compactControls
                text: "\u22ee"
                display: QQC2.AbstractButton.TextOnly
                Layout.preferredWidth: root.toolbarContentHeight
                Layout.preferredHeight: root.toolbarContentHeight
                onClicked: {
                    root.keepControlsWarm()
                    root.moreActionsVisible = !root.moreActionsVisible
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
        id: moreActionsPanel
        z: 101
        visible: root.chromeVisible && root.moreActionsVisible
        anchors {
            top: readerToolbar.bottom
            right: readerToolbar.right
            topMargin: Math.round(Kirigami.Units.smallSpacing * 0.75)
        }
        width: Math.min(root.width - Kirigami.Units.gridUnit * 2, Kirigami.Units.gridUnit * 10.5)
        height: moreActionsColumn.implicitHeight + Kirigami.Units.smallSpacing * 2
        radius: Math.round(Kirigami.Units.gridUnit * 0.75)
        color: root.readerToolbarSurface
        border.color: root.readerToolbarBorder

        ColumnLayout {
            id: moreActionsColumn
            anchors {
                fill: parent
                margins: Kirigami.Units.smallSpacing
            }
            spacing: 0

            QQC2.ToolButton {
                text: i18n("Listen")
                visible: typeof uriHandler !== "undefined"
                display: QQC2.AbstractButton.TextOnly
                Layout.fillWidth: true
                onClicked: root.openTtsPanel()
            }

            QQC2.ToolButton {
                text: pageArea.page.bookmarked ? i18n("Remove Bookmark") : i18n("Bookmark")
                checkable: true
                checked: pageArea.page.bookmarked
                display: QQC2.AbstractButton.TextOnly
                Layout.fillWidth: true
                onClicked: {
                    root.toggleBookmark()
                    root.moreActionsVisible = false
                }
            }

            QQC2.ToolButton {
                text: i18n("Crop Margins")
                checkable: true
                checked: pageArea.trimMargins
                display: QQC2.AbstractButton.TextOnly
                Layout.fillWidth: true
                onClicked: {
                    root.toggleCrop()
                    root.moreActionsVisible = false
                }
            }

            QQC2.ToolButton {
                text: i18n("Share")
                display: QQC2.AbstractButton.TextOnly
                Layout.fillWidth: true
                onClicked: {
                    root.shareCurrentDocument()
                    root.moreActionsVisible = false
                }
            }

            QQC2.ToolButton {
                text: i18n("Delete")
                display: QQC2.AbstractButton.TextOnly
                Layout.fillWidth: true
                onClicked: {
                    root.confirmDeleteCurrentDocument()
                    root.moreActionsVisible = false
                }
            }
        }
    }

    QQC2.Popup {
        id: ttsPanel
        z: 250
        modal: true
        focus: true
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
        padding: Math.max(14, Kirigami.Units.gridUnit)
        width: Math.min(root.width - Kirigami.Units.gridUnit * 1.5, Kirigami.Units.gridUnit * 26)
        height: Math.min(root.height - root.toolbarTopInset - fileBrowserRoot.bottomSystemInset - Kirigami.Units.gridUnit * 2,
                         ttsPanelContent.implicitHeight + topPadding + bottomPadding)
        x: Math.round((root.width - width) / 2)
        y: Math.max(root.toolbarTopInset + Kirigami.Units.gridUnit,
                    root.height - height - fileBrowserRoot.bottomSystemInset - Kirigami.Units.gridUnit)

        background: Rectangle {
            color: "#FBFAF7"
            radius: Math.round(Kirigami.Units.gridUnit * 1.15)
            border.color: root.readerToolbarBorder
            border.width: 1
        }

        onOpened: {
            autoHideControls.stop()
            root.refreshTtsData()
        }
        onClosed: {
            if (root.chromeVisible && !contextDrawer.drawerOpen) {
                autoHideControls.restart()
            }
        }

        contentItem: ColumnLayout {
            id: ttsPanelContent
            spacing: Math.max(10, Kirigami.Units.smallSpacing)

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    QQC2.Label {
                        text: i18n("Listen")
                        color: "#24211F"
                        font.pixelSize: Math.max(20, Math.round(Kirigami.Units.gridUnit * 1.18))
                        font.weight: Font.DemiBold
                    }

                    QQC2.Label {
                        text: i18n("Android system text-to-speech")
                        color: root.readerToolbarMutedColor
                        font.pixelSize: Math.max(11, Math.round(Kirigami.Units.gridUnit * 0.66))
                    }
                }

                QQC2.ToolButton {
                    text: "\u00d7"
                    display: QQC2.AbstractButton.TextOnly
                    onClicked: ttsPanel.close()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: ttsStatusLabel.implicitHeight + Kirigami.Units.gridUnit
                radius: Math.round(Kirigami.Units.gridUnit * 0.72)
                color: root.ttsState === "speaking" ? "#F8D7E5" : "#FFFFFF"
                border.color: root.ttsState === "speaking" ? Qt.rgba(0.85, 0.11, 0.38, 0.32) : root.readerToolbarBorder

                QQC2.Label {
                    id: ttsStatusLabel
                    anchors {
                        fill: parent
                        margins: Math.round(Kirigami.Units.gridUnit * 0.5)
                    }
                    text: root.friendlyTtsStatus()
                    color: root.ttsState === "speaking" ? "#8A1744" : "#24211F"
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Math.max(11, Math.round(Kirigami.Units.gridUnit * 0.67))
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                QQC2.Button {
                    id: playCurrentPageButton
                    text: root.ttsState === "speaking" ? i18n("Restart Page") : i18n("Play Current Page")
                    enabled: root.ttsState !== "initializing" && !root.ttsWaitingForText
                    Layout.fillWidth: true
                    contentItem: QQC2.Label {
                        text: playCurrentPageButton.text
                        color: "#FFFFFF"
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: playCurrentPageButton.down ? "#8A1744" : root.primaryAccentColor
                        radius: Math.round(Kirigami.Units.gridUnit * 0.62)
                        opacity: playCurrentPageButton.enabled ? 1 : 0.42
                    }
                    onClicked: root.playCurrentPage()
                }

                QQC2.Button {
                    id: stopTtsButton
                    text: i18n("Stop")
                    enabled: root.ttsState === "speaking" || root.ttsWaitingForText
                    Layout.preferredWidth: Math.max(Kirigami.Units.gridUnit * 4.5, implicitWidth)
                    contentItem: QQC2.Label {
                        text: stopTtsButton.text
                        color: "#24211F"
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: stopTtsButton.down ? "#ECE8E1" : "#FFFFFF"
                        radius: Math.round(Kirigami.Units.gridUnit * 0.62)
                        border.color: root.readerToolbarBorder
                        opacity: stopTtsButton.enabled ? 1 : 0.48
                    }
                    onClicked: root.stopTts()
                }
            }

            QQC2.Label {
                text: i18n("Speed")
                color: "#24211F"
                font.weight: Font.DemiBold
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.max(3, Kirigami.Units.smallSpacing / 2)

                Repeater {
                    model: [
                        { "label": "0.8x", "rate": 0.8 },
                        { "label": "1.0x", "rate": 1.0 },
                        { "label": "1.25x", "rate": 1.25 },
                        { "label": "1.5x", "rate": 1.5 },
                        { "label": "2.0x", "rate": 2.0 }
                    ]

                    delegate: QQC2.Button {
                        required property var modelData
                        text: modelData.label
                        checkable: true
                        checked: Math.abs(root.ttsRate - modelData.rate) < 0.01
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(34, Kirigami.Units.gridUnit * 1.9)
                        contentItem: QQC2.Label {
                            text: parent.text
                            color: parent.checked ? "#FFFFFF" : "#24211F"
                            font.pixelSize: Math.max(10, Math.round(Kirigami.Units.gridUnit * 0.62))
                            font.weight: parent.checked ? Font.DemiBold : Font.Normal
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: parent.checked ? root.primaryAccentColor : parent.down ? "#ECE8E1" : "#F0EEEA"
                            radius: height / 2
                            border.color: parent.checked ? root.primaryAccentColor : root.readerToolbarBorder
                        }
                        onClicked: {
                            root.ttsRate = modelData.rate
                            if (typeof uriHandler !== "undefined") {
                                uriHandler.ttsSetRate(modelData.rate)
                            }
                        }
                    }
                }
            }

            QQC2.Label {
                visible: root.ttsEngines.length > 1
                text: i18n("Speech engine")
                color: "#24211F"
                font.weight: Font.DemiBold
            }

            QQC2.ComboBox {
                id: ttsEnginePicker
                visible: root.ttsEngines.length > 1
                Layout.fillWidth: true
                model: root.ttsEngines
                textRole: "label"
                currentIndex: root.ttsEngineIndex()
                onActivated: {
                    if (currentIndex < 0 || currentIndex >= root.ttsEngines.length || typeof uriHandler === "undefined") {
                        return
                    }
                    const selectedEngine = root.ttsEngines[currentIndex]
                    root.ttsEnginePackage = selectedEngine["package"]
                    root.ttsVoices = []
                    root.ttsVoiceName = ""
                    uriHandler.ttsUseEngine(root.ttsEnginePackage)
                    root.refreshTtsData()
                }
            }

            QQC2.Label {
                visible: root.ttsVoices.length > 0
                text: i18n("Voice")
                color: "#24211F"
                font.weight: Font.DemiBold
            }

            QQC2.ComboBox {
                id: ttsVoicePicker
                visible: root.ttsVoices.length > 0
                Layout.fillWidth: true
                model: root.ttsVoices
                textRole: "label"
                currentIndex: root.ttsVoiceIndex()
                onActivated: {
                    if (currentIndex < 0 || currentIndex >= root.ttsVoices.length || typeof uriHandler === "undefined") {
                        return
                    }
                    root.ttsVoiceName = root.ttsVoices[currentIndex].name
                    uriHandler.ttsSetVoice(root.ttsVoiceName)
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                text: i18n("Parthicle uses voices already installed in Android. Text-based PDFs and documents can be read now; scanned pages require OCR support later.")
                color: root.readerToolbarMutedColor
                wrapMode: Text.WordWrap
                font.pixelSize: Math.max(10, Math.round(Kirigami.Units.gridUnit * 0.61))
            }
        }
    }

    Timer {
        id: ttsRefreshTimer
        interval: 400
        repeat: true
        running: ttsPanel.visible
        onTriggered: {
            const previousState = root.ttsState
            const previousEngine = root.ttsEnginePackage
            root.refreshTtsState()
            if ((previousState === "initializing" && root.ttsState !== "initializing")
                    || previousEngine !== root.ttsEnginePackage) {
                root.refreshTtsDiscovery()
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
                color: index === document.currentPage ? Qt.rgba(0.85, 0.11, 0.38, 0.12) : "#ffffff"
                border.width: index === document.currentPage ? 2 : 1
                border.color: index === document.currentPage ? root.primaryAccentColor : root.readerToolbarBorder
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
                    color: index === document.currentPage ? root.primaryAccentColor : Qt.rgba(0.98, 0.97, 0.94, 0.88)

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
        visible: root.chromeVisible
        height: Math.max(3, Math.round(Kirigami.Units.smallSpacing / 2))
        color: Qt.rgba(0.14, 0.15, 0.16, 0.32)
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            bottomMargin: fileBrowserRoot.bottomSystemInset
        }

        Rectangle {
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }
            width: parent.width * (document.pageCount > 0 ? ((document.currentPage + 1) / document.pageCount) : 0)
            color: root.primaryAccentColor
        }
    }
}
