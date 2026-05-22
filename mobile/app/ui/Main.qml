/*
    SPDX-FileCopyrightText: 2012 Marco Martin <mart@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtCore
import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Dialogs as QQD
import org.kde.okular 2.0 as Okular
import org.kde.kirigami 2.17 as Kirigami
import org.kde.kirigamiaddons.formcard 1.0 as FormCard
import org.kde.okular.app

Kirigami.ApplicationWindow {
    id: fileBrowserRoot

    readonly property int columnWidth: Kirigami.Units.gridUnit * 13
    readonly property int fitWidthMode: 0
    readonly property int fitPageMode: 1
    readonly property int fillScreenMode: 2
    property int readerFitMode: fitWidthMode
    property bool readerContinuousMode: true
    readonly property real topSystemInset: typeof uriHandler !== "undefined" ? uriHandler.statusBarHeight() : 0
    readonly property real bottomSystemInset: typeof uriHandler !== "undefined" ? uriHandler.navigationBarHeight() : 0

    wideScreen: width > columnWidth * 5
    visible: true
    // Qt 6.9 auto-pads safe areas; the reader handles them per screen instead.
    topPadding: 0
    leftPadding: 0
    rightPadding: 0
    bottomPadding: 0
    color: documentItem.opened ? "#111316" : "#fbfaf7"
    controlsVisible: false

    pageStack.globalToolBar.style: Kirigami.ApplicationHeaderStyle.None
    pageStack.separatorVisible: false

    globalDrawer: Kirigami.GlobalDrawer {
        title: i18n("Parthicle Reader")
        titleIcon: "application-pdf"
        drawerOpen: false
        isMenu: true

        QQD.FileDialog {
            id: fileDialog
            nameFilters: Okular.Okular.nameFilters
            currentFolder: StandardPaths.standardLocations(StandardPaths.DocumentsLocation)[0]
            onAccepted: {
                documentItem.url = fileDialog.selectedFile
            }
        }

        actions: [
            Kirigami.Action {
                id: openDocumentAction
                text: i18n("Open…")
                icon.name: "document-open"
                onTriggered: {
                    fileDialog.open()
                }
            },
            Kirigami.Action {
                text: i18n("About")
                icon.name: "help-about-symbolic"
                onTriggered: fileBrowserRoot.pageStack.layers.push(Qt.createComponent("org.kde.kirigamiaddons.formcard", "AboutPage"));
                enabled: fileBrowserRoot.pageStack.layers.depth === 1
            }
        ]
    }
    contextDrawer: OkularDrawer {
        width: columnWidth
        contentItem.implicitWidth: columnWidth
        modal: !fileBrowserRoot.wideScreen
        onModalChanged: drawerOpen = !modal
        onEnabledChanged: drawerOpen = enabled && !modal
        onDrawerOpenChanged: fileBrowserRoot.updateReaderMode()
        enabled: documentItem.opened && pageStack.layers.depth < 2
        handleVisible: enabled && pageStack.layers.depth < 2
    }

    title: documentItem.windowTitleForDocument ? documentItem.windowTitleForDocument : i18n("Parthicle Reader")

    onControlsVisibleChanged: updateReaderMode()
    onClosing: (close) => {
        if (documentItem.opened) {
            close.accepted = false
            mainView.returnToLibrary()
        }
    }

    function readerDefaultFitMode(openedUrl) {
        return fitWidthMode
    }

    function updateReaderMode() {
        if (typeof uriHandler !== "undefined") {
            uriHandler.setReaderMode(documentItem.opened)
        }
    }

    Okular.DocumentItem {
        id: documentItem
        onUrlChanged: {
            currentPage = 0
            fileBrowserRoot.controlsVisible = false
            fileBrowserRoot.readerFitMode = fileBrowserRoot.readerDefaultFitMode(url)
            if (fileBrowserRoot.readerContinuousMode && fileBrowserRoot.readerFitMode === fileBrowserRoot.fillScreenMode) {
                fileBrowserRoot.readerFitMode = fileBrowserRoot.fitWidthMode
            }
            fileBrowserRoot.updateReaderMode()
        }
        onOpenedChanged: {
            fileBrowserRoot.updateReaderMode()
        }

        onNeedsPasswordChanged: {
            if (needsPassword) {
                passwordDialog.open();
            }
        }
    }

    pageStack.initialPage: MainView {
        id: mainView
        document: documentItem
        Kirigami.ColumnView.preventStealing: true
    }

    Shortcut {
        sequences: [StandardKey.Back]
        enabled: documentItem.opened
        context: Qt.ApplicationShortcut
        onActivated: mainView.returnToLibrary()
    }

    function openInitialUri() {
        const initialUri = typeof uriHandler !== "undefined" ? uriHandler.lastUrl : uri
        if (initialUri) {
            documentItem.url = initialUri
        }
    }

    Component.onCompleted: openInitialUri()

    Connections {
        target: typeof uriHandler !== "undefined" ? uriHandler : null
        function onOpenRequested(openedUri) {
            if (openedUri) {
                documentItem.url = openedUri
            }
        }
        function onCloseRequested() {
            if (documentItem.opened) {
                mainView.returnToLibrary()
            } else if (typeof uriHandler !== "undefined") {
                uriHandler.clearCurrentDocument()
            }
        }
    }

    QQC2.Dialog {
        id: passwordDialog
        focus: true
        anchors.centerIn: parent
        title: i18n("Password Needed")
        contentItem: Kirigami.PasswordField {
            id: pwdField
            onAccepted: passwordDialog.accept();
            focus: true
        }
        standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel

        onAccepted: documentItem.setPassword(pwdField.text);
        onRejected: documentItem.url = "";
    }
}
