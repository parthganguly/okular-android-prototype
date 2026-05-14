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
    readonly property color libraryBackgroundColor: "#fbfaf7"
    readonly property color surfaceColor: "#ffffff"
    readonly property color softSurfaceColor: "#f0eeea"
    readonly property color pressedSurfaceColor: "#ece8e1"
    readonly property color quietBorderColor: Qt.rgba(0.12, 0.10, 0.08, 0.11)
    readonly property color mutedTextColor: Qt.rgba(0.10, 0.09, 0.08, 0.62)
    readonly property color okularAccentColor: "#e91e63"
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

    function categoryAccent(category) {
        if (category === "books") {
            return "#a8662a"
        }
        if (category === "pictures") {
            return "#3d7a55"
        }
        if (category === "documents") {
            return "#516171"
        }
        return "#2c78a4"
    }

    function categoryShortLabel(category) {
        if (category === "books") {
            return i18nc("document library short type", "Book")
        }
        if (category === "pictures") {
            return i18nc("document library short type", "Image")
        }
        return i18nc("document library short type", "Doc")
    }

    function categoryColor(category, folderRow) {
        if (folderRow) {
            return "#dbeaf2"
        }
        if (category === "books") {
            return "#f7e1c7"
        }
        if (category === "pictures") {
            return "#deefe5"
        }
        return "#ebe8e2"
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

    Rectangle {
        anchors.fill: parent
        visible: welcomeView.androidLibraryAvailable
        color: welcomeView.libraryBackgroundColor
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

        Rectangle {
            id: libraryHeader
            visible: welcomeView.androidLibraryAvailable
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(86, Kirigami.Units.gridUnit * 4.4)
            Layout.leftMargin: Kirigami.Units.gridUnit
            Layout.rightMargin: Kirigami.Units.gridUnit
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            radius: Math.round(Kirigami.Units.gridUnit * 1.25)
            color: welcomeView.surfaceColor
            border.color: welcomeView.quietBorderColor

            ColumnLayout {
                anchors {
                    fill: parent
                    margins: Math.round(Kirigami.Units.gridUnit * 0.82)
                }
                spacing: Math.round(Kirigami.Units.smallSpacing * 0.75)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Controls.Label {
                            text: welcomeView.libraryState.canGoUp ? welcomeView.libraryState.title : welcomeView.categoryLabel(welcomeView.activeCategory)
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                            font.pixelSize: Math.round(Kirigami.Units.gridUnit * 1.45)
                            font.weight: Font.DemiBold
                            color: "#1c1b1a"
                        }

                        Controls.Label {
                            text: welcomeView.libraryState.canGoUp
                                    ? i18nc("document library", "Browsing this folder")
                                    : i18nc("document library", "Your readable files, grouped by folder")
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            color: welcomeView.mutedTextColor
                            font.pixelSize: Math.max(12, Math.round(Kirigami.Units.gridUnit * 0.68))
                        }
                    }

                    Controls.ToolButton {
                        visible: welcomeView.libraryState.needsAllFilesAccess
                        text: i18nc("document library", "Allow")
                        icon.name: "folder-open"
                        onClicked: uriHandler.requestAllFilesAccess()
                    }

                    Controls.ToolButton {
                        visible: welcomeView.libraryState.needsAllFilesAccess
                        text: i18nc("document library", "Folder")
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

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    visible: welcomeView.libraryState.needsAllFilesAccess
                    color: welcomeView.quietBorderColor
                }

                Controls.Label {
                    visible: welcomeView.libraryState.needsAllFilesAccess
                    text: welcomeView.libraryState.message
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    color: welcomeView.mutedTextColor
                    font.pixelSize: Math.max(12, Math.round(Kirigami.Units.gridUnit * 0.64))
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }
        }

        RowLayout {
            visible: welcomeView.androidLibraryAvailable && !welcomeView.libraryState.needsAllFilesAccess
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.gridUnit
            Layout.rightMargin: Kirigami.Units.gridUnit
            Layout.bottomMargin: Math.round(Kirigami.Units.smallSpacing * 1.5)
            spacing: Math.round(Kirigami.Units.smallSpacing * 0.75)

            Repeater {
                model: welcomeView.categoryTabs

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(40, Kirigami.Units.gridUnit * 2.05)
                    radius: height / 2
                    color: welcomeView.activeCategory === modelData.id ? welcomeView.okularAccentColor : welcomeView.softSurfaceColor
                    border.width: 1
                    border.color: welcomeView.activeCategory === modelData.id ? Qt.rgba(0, 0, 0, 0) : welcomeView.quietBorderColor

                    Controls.Label {
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.smallSpacing
                        text: modelData.label
                        color: welcomeView.activeCategory === modelData.id ? "#ffffff" : "#302d2a"
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        font.bold: welcomeView.activeCategory === modelData.id
                        font.pixelSize: Math.max(12, Math.round(Kirigami.Units.gridUnit * 0.7))
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: welcomeView.activeCategory = modelData.id
                    }
                }
            }
        }

        Controls.Label {
            visible: welcomeView.androidLibraryAvailable && !welcomeView.libraryState.needsAllFilesAccess && welcomeView.libraryMessage
            text: welcomeView.libraryMessage
            wrapMode: Text.WordWrap
            color: welcomeView.mutedTextColor
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
            spacing: Math.round(Kirigami.Units.smallSpacing * 0.35)
            topMargin: Kirigami.Units.smallSpacing
            bottomMargin: Math.max(Kirigami.Units.gridUnit, welcomeView.bottomInset + Kirigami.Units.gridUnit)
            model: welcomeView.filteredLibraryEntries

            delegate: Item {
                property bool folderRow: modelData.kind === "folder"

                width: libraryList.width
                height: Math.max(78, Kirigami.Units.gridUnit * 3.75)

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        bottom: parent.bottom
                        leftMargin: Kirigami.Units.gridUnit
                        rightMargin: Kirigami.Units.gridUnit
                        topMargin: Math.round(Kirigami.Units.smallSpacing * 0.45)
                        bottomMargin: Math.round(Kirigami.Units.smallSpacing * 0.45)
                    }
                    radius: Math.round(Kirigami.Units.gridUnit * 0.85)
                    color: rowTap.pressed ? welcomeView.pressedSurfaceColor : welcomeView.surfaceColor
                    border.color: welcomeView.quietBorderColor

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: Math.round(Kirigami.Units.gridUnit * 0.85)
                            rightMargin: Math.round(Kirigami.Units.gridUnit * 0.75)
                            topMargin: Kirigami.Units.smallSpacing
                            bottomMargin: Kirigami.Units.smallSpacing
                        }
                        spacing: Math.round(Kirigami.Units.gridUnit * 0.7)

                        Rectangle {
                            Layout.preferredWidth: Math.round(Kirigami.Units.gridUnit * 2.35)
                            Layout.preferredHeight: Math.round(Kirigami.Units.gridUnit * 2.35)
                            radius: Math.round(width * 0.34)
                            color: welcomeView.categoryColor(modelData.category, folderRow)
                            border.color: Qt.rgba(0.12, 0.10, 0.08, 0.06)

                            Rectangle {
                                visible: folderRow
                                x: Math.round(parent.width * 0.24)
                                y: Math.round(parent.height * 0.30)
                                width: Math.round(parent.width * 0.32)
                                height: Math.round(parent.height * 0.13)
                                radius: 2
                                color: welcomeView.categoryAccent(modelData.category)
                                opacity: 0.72
                            }

                            Rectangle {
                                visible: folderRow
                                anchors.centerIn: parent
                                width: Math.round(parent.width * 0.56)
                                height: Math.round(parent.height * 0.36)
                                radius: 4
                                color: welcomeView.categoryAccent(modelData.category)
                                opacity: 0.82
                            }

                            Rectangle {
                                visible: !folderRow
                                anchors.centerIn: parent
                                width: Math.round(parent.width * 0.42)
                                height: Math.round(parent.height * 0.56)
                                radius: 4
                                color: Qt.rgba(1, 1, 1, 0.72)
                                border.color: welcomeView.categoryAccent(modelData.category)
                            }

                            Rectangle {
                                visible: !folderRow
                                x: Math.round(parent.width * 0.53)
                                y: Math.round(parent.height * 0.24)
                                width: Math.round(parent.width * 0.10)
                                height: Math.round(parent.height * 0.10)
                                color: welcomeView.categoryAccent(modelData.category)
                                opacity: 0.45
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(Kirigami.Units.smallSpacing * 0.2)

                            Controls.Label {
                                text: modelData.name
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                                font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.92)
                                font.weight: Font.Medium
                                color: "#24211f"
                            }

                            Controls.Label {
                                text: welcomeView.entrySubtitle(modelData)
                                elide: Text.ElideRight
                                color: welcomeView.mutedTextColor
                                font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.66)
                                Layout.fillWidth: true
                            }
                        }

                        Rectangle {
                            visible: !folderRow
                            Layout.preferredWidth: Math.max(46, Kirigami.Units.gridUnit * 2.3)
                            Layout.preferredHeight: Math.max(24, Kirigami.Units.gridUnit * 1.15)
                            radius: height / 2
                            color: welcomeView.categoryColor(modelData.category, false)

                            Controls.Label {
                                anchors.centerIn: parent
                                text: welcomeView.categoryShortLabel(modelData.category)
                                color: welcomeView.categoryAccent(modelData.category)
                                font.pixelSize: Math.max(10, Math.round(Kirigami.Units.gridUnit * 0.54))
                                font.bold: true
                            }
                        }
                    }
                }

                MouseArea {
                    id: rowTap
                    anchors {
                        fill: parent
                        leftMargin: Kirigami.Units.gridUnit
                        rightMargin: Kirigami.Units.gridUnit
                    }
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
