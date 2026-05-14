/*
 SPDX-FileCopyrightText: 2025 Sebastian Kügler <sebas@kde.org>

 SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtCore
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import Qt.labs.folderlistmodel

import org.kde.okular as Okular
import org.kde.kirigami as Kirigami

Item {
    id: welcomeView

    visible: !document.opened

    anchors.fill: parent
    readonly property bool androidLibraryAvailable: typeof uriHandler !== "undefined" && uriHandler.libraryJson !== undefined
    readonly property real bottomInset: androidLibraryAvailable && typeof fileBrowserRoot !== "undefined" ? fileBrowserRoot.bottomSystemInset : 0
    property var libraryState: ({
        "hasFolder": false,
        "title": i18nc("document library", "Local"),
        "message": i18nc("document library", "Allow all files access to scan your Okular documents like MX Player, or choose one folder manually."),
        "canGoUp": false,
        "needsAllFilesAccess": true,
        "entries": []
    })
    readonly property var libraryEntries: libraryState.entries ? libraryState.entries : []
    property string activeCategory: "local"
    readonly property var categoryTabs: [
        { "id": "local", "label": i18nc("document library section", "Local") },
        { "id": "documents", "label": i18nc("document library section", "Documents") },
        { "id": "books", "label": i18nc("document library section", "Books") },
        { "id": "pictures", "label": i18nc("document library section", "Pictures") }
    ]
    readonly property var filteredLibraryEntries: {
        const entries = []
        for (let i = 0; i < welcomeView.libraryEntries.length; ++i) {
            const entry = welcomeView.libraryEntries[i]
            if (welcomeView.entryMatchesCategory(entry)) {
                entries.push(entry)
            }
        }
        return entries
    }
    readonly property string libraryMessage: {
        if (welcomeView.libraryState.message) {
            return welcomeView.libraryState.message
        }
        if (welcomeView.androidLibraryAvailable && welcomeView.libraryState.hasFolder && welcomeView.filteredLibraryEntries.length === 0) {
            return welcomeView.libraryState.canGoUp
                    ? i18nc("document library empty category in folder", "No %1 in this folder.", welcomeView.categoryLabel(welcomeView.activeCategory).toLowerCase())
                    : i18nc("document library empty category", "No %1 found in local storage.", welcomeView.categoryLabel(welcomeView.activeCategory).toLowerCase())
        }
        return ""
    }

    function saveRecentDocument(doc) {
        welcome.urlOpened(doc);
    }

    function categoryLabel(category) {
        for (let i = 0; i < categoryTabs.length; ++i) {
            if (categoryTabs[i].id === category) {
                return categoryTabs[i].label
            }
        }
        return categoryTabs[0].label
    }

    function categoryCount(entry, category) {
        if (!entry) {
            return 0
        }
        if (category === "local") {
            return entry.count !== undefined ? entry.count : 1
        }
        if (entry.counts && entry.counts[category] !== undefined) {
            return entry.counts[category]
        }
        return entry.category === category ? 1 : 0
    }

    function categoryCountText(category, count) {
        if (category === "books") {
            return count === 1 ? i18nc("document library count", "1 book") : i18nc("document library count", "%1 books", count)
        }
        if (category === "pictures") {
            return count === 1 ? i18nc("document library count", "1 picture") : i18nc("document library count", "%1 pictures", count)
        }
        return count === 1 ? i18nc("document library count", "1 document") : i18nc("document library count", "%1 documents", count)
    }

    function entryMatchesCategory(entry) {
        if (activeCategory === "local") {
            return true
        }
        if (entry.kind === "folder") {
            return categoryCount(entry, activeCategory) > 0
        }
        return entry.category === activeCategory
    }

    function entrySubtitle(entry) {
        if (entry.kind === "folder" && activeCategory !== "local") {
            return categoryCountText(activeCategory, categoryCount(entry, activeCategory))
        }
        return entry.subtitle ? entry.subtitle : (entry.kind === "folder" ? i18nc("document library", "Folder") : (entry.mimeType || i18nc("document library", "Document")))
    }

    function categoryColor(category, folderRow) {
        if (folderRow) {
            return "#3daee9"
        }
        if (category === "books") {
            return "#f67400"
        }
        if (category === "pictures") {
            return "#27ae60"
        }
        return Qt.rgba(0.45, 0.45, 0.45, 0.18)
    }

    function updateLibraryState() {
        if (!androidLibraryAvailable || !uriHandler.libraryJson) {
            return;
        }

        try {
            libraryState = JSON.parse(uriHandler.libraryJson);
        } catch (error) {
            console.warn("Cannot parse Okular library JSON", error);
        }
    }

    Okular.WelcomeItem {
        id: welcome
    }

    Component.onCompleted: {
        if (androidLibraryAvailable) {
            uriHandler.refreshLibrary();
            updateLibraryState();
        }
    }

    Connections {
        target: welcomeView.androidLibraryAvailable ? uriHandler : null
        function onLibraryJsonChanged() {
            welcomeView.updateLibraryState();
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            topMargin: welcomeView.androidLibraryAvailable ? Kirigami.Units.smallSpacing : Kirigami.Units.gridUnit
            leftMargin: welcomeView.androidLibraryAvailable ? 0 : Kirigami.Units.gridUnit
            rightMargin: welcomeView.androidLibraryAvailable ? 0 : Kirigami.Units.gridUnit
            bottomMargin: welcomeView.androidLibraryAvailable ? Math.max(0, welcomeView.bottomInset) : Kirigami.Units.gridUnit
        }

        spacing: welcomeView.androidLibraryAvailable ? 0 : Kirigami.Units.gridUnit

        Kirigami.PlaceholderMessage {
            visible: !welcomeView.androidLibraryAvailable
            text: i18n("No document open")
            helpfulAction: openDocumentAction
            Layout.fillWidth: true
        }

        Component {
            id: fileDelegate
            MouseArea {
                Layout.fillWidth: true
                width: Math.max(recentList.width, documentsList.width)
                height: Kirigami.Units.gridUnit * 1.6
                RowLayout {
                    anchors.fill: parent
                    spacing: Math.round(Kirigami.Units.gridUnit * 0.4)

                    Kirigami.Icon {
                        source: (typeof iconName !== "undefined") ? iconName : "application-pdf"
                    }

                    Controls.Label {
                        text: (typeof display !== "undefined") ? display : fileName
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }
                }
                onClicked: {
                    if (typeof url !== "undefined") {
                        // Recent Document
                        documentItem.url = url;
                    } else {
                        // File is in Documents folder
                        documentItem.url = fileUrl;
                    }
                }
            }
        }

        RowLayout {
            id: libraryHeader
            visible: welcomeView.androidLibraryAvailable
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(52, Kirigami.Units.gridUnit * 2.6)
            Layout.leftMargin: Kirigami.Units.gridUnit
            Layout.rightMargin: Kirigami.Units.gridUnit
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                text: welcomeView.libraryState.canGoUp ? welcomeView.libraryState.title : welcomeView.categoryLabel(welcomeView.activeCategory)
                elide: Text.ElideMiddle
                level: 1
                Layout.fillWidth: true
            }

            Controls.ToolButton {
                visible: welcomeView.libraryState.needsAllFilesAccess
                text: i18nc("document library", "Allow Access")
                icon.name: "folder-open"
                onClicked: uriHandler.requestAllFilesAccess()
            }

            Controls.ToolButton {
                visible: welcomeView.libraryState.needsAllFilesAccess
                text: i18nc("document library", "Choose Folder")
                icon.name: "folder-open"
                onClicked: uriHandler.openLibraryFolder()
            }

            Controls.ToolButton {
                text: i18nc("document library", "Up")
                icon.name: "go-up"
                visible: welcomeView.libraryState.canGoUp
                enabled: welcomeView.libraryState.canGoUp
                onClicked: uriHandler.navigateLibraryUp()
            }

            Controls.ToolButton {
                text: i18nc("document library", "Refresh")
                icon.name: "view-refresh"
                onClicked: uriHandler.refreshLibrary()
            }
        }

        RowLayout {
            visible: welcomeView.androidLibraryAvailable && !welcomeView.libraryState.needsAllFilesAccess
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.gridUnit
            Layout.rightMargin: Kirigami.Units.gridUnit
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: welcomeView.categoryTabs

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(34, Kirigami.Units.gridUnit * 1.8)
                    radius: height / 2
                    color: welcomeView.activeCategory === modelData.id ? Kirigami.Theme.highlightColor : Qt.rgba(0, 0, 0, 0.08)
                    border.width: welcomeView.activeCategory === modelData.id ? 0 : 1
                    border.color: Qt.rgba(0, 0, 0, 0.14)

                    Controls.Label {
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.smallSpacing
                        text: modelData.label
                        color: welcomeView.activeCategory === modelData.id ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        font.bold: welcomeView.activeCategory === modelData.id
                        font.pixelSize: Math.max(11, Math.round(Kirigami.Units.gridUnit * 0.68))
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: welcomeView.activeCategory = modelData.id
                    }
                }
            }
        }

        Controls.Label {
            visible: welcomeView.androidLibraryAvailable && welcomeView.libraryMessage
            text: welcomeView.libraryMessage
            wrapMode: Text.WordWrap
            opacity: 0.75
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.gridUnit
            Layout.rightMargin: Kirigami.Units.gridUnit
            Layout.bottomMargin: Kirigami.Units.smallSpacing
        }

        ListView {
            id: libraryList
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: welcomeView.androidLibraryAvailable && welcomeView.libraryState.hasFolder
            clip: true
            model: welcomeView.filteredLibraryEntries

            delegate: Rectangle {
                property bool folderRow: modelData.kind === "folder"

                width: libraryList.width
                height: Math.max(64, Kirigami.Units.gridUnit * 3.05)
                color: rowTap.pressed ? Qt.rgba(0, 0, 0, 0.08) : Kirigami.Theme.backgroundColor

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: Kirigami.Units.gridUnit
                        rightMargin: Kirigami.Units.gridUnit
                    }
                    spacing: Math.round(Kirigami.Units.gridUnit * 0.65)

                    Item {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 1.9
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.9

                        Rectangle {
                            visible: folderRow
                            x: Math.round(parent.width * 0.16)
                            y: Math.round(parent.height * 0.25)
                            width: Math.round(parent.width * 0.40)
                            height: Math.round(parent.height * 0.20)
                            radius: 2
                            color: welcomeView.categoryColor(modelData.category, true)
                        }

                        Rectangle {
                            visible: folderRow
                            x: Math.round(parent.width * 0.10)
                            y: Math.round(parent.height * 0.38)
                            width: Math.round(parent.width * 0.78)
                            height: Math.round(parent.height * 0.44)
                            radius: 4
                            color: welcomeView.categoryColor(modelData.category, true)
                        }

                        Rectangle {
                            visible: !folderRow
                            anchors.centerIn: parent
                            width: Math.round(parent.width * 0.62)
                            height: Math.round(parent.height * 0.78)
                            radius: 3
                            color: welcomeView.categoryColor(modelData.category, false)
                            border.color: Qt.rgba(0.25, 0.25, 0.25, 0.42)
                        }

                        Rectangle {
                            visible: !folderRow
                            x: Math.round(parent.width * 0.58)
                            y: Math.round(parent.height * 0.13)
                            width: Math.round(parent.width * 0.16)
                            height: Math.round(parent.height * 0.16)
                            color: Kirigami.Theme.backgroundColor
                            border.color: Qt.rgba(0.25, 0.25, 0.25, 0.42)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Controls.Label {
                            text: modelData.name
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                            font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.92)
                        }

                        Controls.Label {
                            text: welcomeView.entrySubtitle(modelData)
                            elide: Text.ElideRight
                            opacity: 0.62
                            font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.68)
                            Layout.fillWidth: true
                        }
                    }
                }

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        leftMargin: Kirigami.Units.gridUnit * 3.8
                    }
                    height: 1
                    color: Kirigami.Theme.textColor
                    opacity: 0.12
                }

                MouseArea {
                    id: rowTap
                    anchors.fill: parent
                    onClicked: {
                        if (modelData.kind === "folder") {
                            uriHandler.openLibraryFolderUri(modelData.uri);
                        } else {
                            uriHandler.openLibraryDocument(modelData.uri, modelData.mimeType);
                        }
                    }
                }
            }
        }

        Kirigami.Heading {
            text: i18nc("in welcome screen", "Recent Documents")
            visible: !welcomeView.androidLibraryAvailable && recentList.count
            Layout.fillWidth: true
        }

        Controls.ScrollView{
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !welcomeView.androidLibraryAvailable && recentList.count

            background: Rectangle {
                color: Kirigami.Theme.backgroundColor
                border.color: Kirigami.Theme.textColor
                radius: Kirigami.Units.cornerRadius
                opacity: 0.2
            }

            ListView {
                id: recentList
                clip: true
                spacing: Math.round(Kirigami.Units.gridUnit * 0.2)

                model: welcome.recentItemsModel
                delegate: fileDelegate
            }
        }

        Kirigami.Heading {
            text: i18nc("in welcome screen", "My Documents")
            visible: !welcomeView.androidLibraryAvailable && documentsList.count
        }

        Controls.ScrollView{
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !welcomeView.androidLibraryAvailable && documentsList.count

            background: Rectangle {
                color: Kirigami.Theme.backgroundColor
                border.color: Kirigami.Theme.textColor
                radius: Kirigami.Units.cornerRadius
                opacity: 0.2
            }

            ListView {
                id: documentsList
                clip: true
                spacing: Math.round(Kirigami.Units.gridUnit * 0.2)

                FolderListModel {
                    id: folderModel
                    // Note: can be changed by editing ~/.config/user-dirs.dirs and changing
                    // the value of XDG_DOCUMENTS_DIR
                    folder: StandardPaths.writableLocation(StandardPaths.DocumentsLocation)
                    nameFilters: Okular.Okular.nameFilters
                }

                model: folderModel
                delegate: fileDelegate
            }
        }
    }
}
