/*
    SPDX-FileCopyrightText: 2015 Marco Martin <mart@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.okular 2.0
import "private"

/**
 * A touchscreen optimized view for a document
 * 
 * It supports changing pages by a swipe gesture, pinch zoom
 * and flicking to scroll around
 */
Item {
    id: root
    property DocumentItem document
    property PageItem page: root.continuousMode && continuousList.currentItem ? continuousList.currentItem.pageItem : mouseArea.currPageDelegate.pageItem
    property bool trimMargins: false
    property int fitMode: 0
    property bool continuousMode: false
    property real continuousZoom: 1
    readonly property int fitWidthMode: 0
    readonly property int fitPageMode: 1
    readonly property int fillScreenMode: 2
    readonly property real continuousMinZoom: 1
    readonly property real continuousMaxZoom: 4
    // A tiny guard keeps one-pixel document borders visible without wasting reader space.
    readonly property real pageHorizontalGutter: Math.max(1, Math.min(3, Math.round(width * 0.006)))
    readonly property real pageVerticalGutter: Math.max(0, Math.min(2, Math.round(width * 0.003)))
    signal clicked

    signal urlOpened

    function safeViewportWidth(containerWidth) {
        return Math.max(1, containerWidth - pageHorizontalGutter * 2)
    }

    function safeViewportHeight(containerHeight) {
        return Math.max(1, containerHeight - pageVerticalGutter * 2)
    }

    function pageCanvasWidth(pageWidth) {
        return Math.max(1, pageWidth + pageHorizontalGutter * 2)
    }

    function pageCanvasHeight(pageHeight) {
        return Math.max(1, pageHeight + pageVerticalGutter * 2)
    }

    clip: true
    onContinuousModeChanged: {
        resizeTimer.restart()
        if (continuousMode) {
            continuousPositionTimer.restart()
        } else {
            flick.resetToFit()
        }
    }

    Rectangle {
        anchors.fill: parent
        z: -100
        color: root.document && root.document.opened ? "#111316" : "transparent"
    }

    onFitModeChanged: {
        continuousZoom = continuousMinZoom
        resizeTimer.restart()
    }
    onTrimMarginsChanged: resizeTimer.restart()
    
    //NOTE: on some themes it tries to set the flickable to interactive
    //but we need it always non interactive as we need to manage
    //dragging by ourselves
    Component.onCompleted: flick.interactive = false
    Flickable {
        id: flick
        anchors.fill: parent
        visible: !root.continuousMode
        enabled: visible
        interactive: false
        onWidthChanged: resizeTimer.restart()
        onHeightChanged: resizeTimer.restart()

        function fittedPageSize() {
            const ratio = Math.max(0.01, mouseArea.currPageDelegate.pageRatio)
            const viewportWidth = root.safeViewportWidth(flick.width)
            const viewportHeight = root.safeViewportHeight(flick.height)
            let pageWidth = viewportWidth
            let pageHeight = pageWidth / ratio

            if (root.fitMode === root.fitPageMode) {
                const heightFromWidth = viewportWidth / ratio
                if (heightFromWidth <= viewportHeight) {
                    pageWidth = viewportWidth
                    pageHeight = heightFromWidth
                } else {
                    pageHeight = viewportHeight
                    pageWidth = pageHeight * ratio
                }
            } else if (root.fitMode === root.fillScreenMode) {
                const heightFromWidth = viewportWidth / ratio
                if (heightFromWidth >= viewportHeight) {
                    pageWidth = viewportWidth
                    pageHeight = heightFromWidth
                } else {
                    pageHeight = viewportHeight
                    pageWidth = pageHeight * ratio
                }
            }

            return Qt.size(Math.max(1, pageWidth), Math.max(1, pageHeight))
        }

        function resetToFit() {
            const size = fittedPageSize()
            mouseArea.pageWidth = size.width
            mouseArea.pageHeight = size.height
            flick.contentWidth = Math.max(flick.width, root.pageCanvasWidth(size.width))
            flick.contentHeight = Math.max(flick.height, root.pageCanvasHeight(size.height))
            flick.returnToBounds()
            preloadTimer.restart()
        }
        
        Component.onCompleted: {
            resetToFit()
        }
        Connections {
            target: root.document
            function onUrlChanged() {
                root.continuousZoom = root.continuousMinZoom
                resizeTimer.restart()
                if (root.continuousMode) {
                    continuousPositionTimer.restart()
                } else {
                    preloadTimer.restart()
                }
                root.urlOpened()
            }
            function onCurrentPageChanged() {
                if (!root.continuousMode) {
                    preloadTimer.restart()
                }
            }
        }
        Connections {
            target: mouseArea.currPageDelegate ? mouseArea.currPageDelegate.pageItem : null
            function onCropRatioChanged() {
                resizeTimer.restart()
            }
        }
        Timer {
            id: resizeTimer
            interval: 250
            onTriggered: {
                if (root.continuousMode) {
                    continuousList.forceLayout()
                    continuousList.preloadVisiblePages()
                } else {
                    flick.resetToFit()
                }
            }
        }
        Timer {
            id: preloadTimer
            interval: 60
            onTriggered: {
                mouseArea.preloadPages()
            }
        }

        PinchArea {
            width: flick.contentWidth
            height: flick.contentHeight

            property real initialWidth
            property real initialHeight

            onPinchStarted: {
                initialWidth = mouseArea.currPageDelegate.implicitWidth * mouseArea.currPageDelegate.scaleFactor
                initialHeight = mouseArea.currPageDelegate.implicitHeight * mouseArea.currPageDelegate.scaleFactor
            }

            onPinchUpdated: (pinch) => {
                // adjust content pos due to drag
                flick.contentX += pinch.previousCenter.x - pinch.center.x
                flick.contentY += pinch.previousCenter.y - pinch.center.y

                // resize content
                //use the scale property during pinch, for speed reasons
                if (initialHeight * pinch.scale > flick.height &&
                    initialHeight * pinch.scale < flick.height * 3) {
                    mouseArea.scale = pinch.scale;
                }
                resizeTimer.stop();
                flick.returnToBounds();
            }
            onPinchFinished: (pinch) => {
                const newWidth = Math.max(root.safeViewportWidth(flick.width) + 1, initialWidth * mouseArea.scale)
                const newHeight = Math.max(root.safeViewportHeight(flick.height), initialHeight * mouseArea.scale)
                mouseArea.pageWidth = newWidth
                mouseArea.pageHeight = newHeight
                flick.resizeContent(Math.max(flick.width, root.pageCanvasWidth(newWidth)), Math.max(flick.height, root.pageCanvasHeight(newHeight)), pinch.center);
                mouseArea.scale = 1;

                resizeTimer.stop()
                flick.returnToBounds();
                preloadTimer.restart()
            }
            MouseArea {
                id: mouseArea
                width: parent.width
                height: parent.height

                property real oldMouseX
                property real oldMouseY
                property real startMouseX
                property real startMouseY
                property real pageWidth: flick.width
                property real pageHeight: flick.width / Math.max(0.01, currPageDelegate.pageRatio)
                property bool incrementing: true
                property bool switchingPage: false
                property PageView currPageDelegate: page1
                property PageView prevPageDelegate: page2
                property PageView nextPageDelegate: page3

                function preloadDelegate(delegate, pageNumber) {
                    if (!root.document || !root.document.opened || !delegate || !delegate.pageItem) {
                        return
                    }
                    if (pageNumber < 0 || pageNumber >= root.document.pageCount) {
                        return
                    }
                    delegate.pageItem.requestPixmap()
                }

                function preloadPages() {
                    preloadDelegate(currPageDelegate, root.document.currentPage)
                    preloadDelegate(prevPageDelegate, root.document.currentPage - 1)
                    preloadDelegate(nextPageDelegate, root.document.currentPage + 1)
                }

                onPressed: (mouse) => {
                    preloadPages()
                    var pos = mapToItem(flick, mouse.x, mouse.y);
                    startMouseX = oldMouseX = pos.x;
                    startMouseY = oldMouseY = pos.y;
                }
                onPositionChanged: (mouse) => {
                    var pos = mapToItem(flick, mouse.x, mouse.y);

                    flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY - (pos.y - oldMouseY)));

                    if ((pos.x - oldMouseX > 0 && flick.atXBeginning) ||
                        (pos.x - oldMouseX < 0 && flick.atXEnd)) {
                        currPageDelegate.x += pos.x - oldMouseX;
                        mouseArea.incrementing = currPageDelegate.x <= 0;
                    } else {
                        flick.contentX = Math.max(0, Math.min(flick.contentWidth - flick.width, flick.contentX - (pos.x - oldMouseX)));
                    }

                    oldMouseX = pos.x;
                    oldMouseY = pos.y;
                }
                onReleased: {
                    if (root.document.currentPage > 0 &&
                        currPageDelegate.x > width/6) {
                        switchAnimation.running = true;
                    } else if (root.document.currentPage < document.pageCount-1 &&
                        currPageDelegate.x < -width/6) {
                        switchAnimation.running = true;
                    } else {
                        resetAnim.running = true;
                    }
                }
                onCanceled: {
                    resetAnim.running = true;
                }
                onDoubleClicked: {
                    flick.resetToFit()
                }
                onClicked: (mouse) => {
                    var pos = mapToItem(flick, mouse.x, mouse.y);
                    if (Math.abs(startMouseX - pos.x) < 20 &&
                        Math.abs(startMouseY - pos.y) < 20) {
                        root.clicked();
                    }
                }
                onWheel: (wheel) => {
                    if (wheel.modifiers & Qt.ControlModifier) {
                        //generate factors between 0.8 and 1.2
                        var factor = (((wheel.angleDelta.y / 120)+1) / 5 )+ 0.8;

                        var newWidth = mouseArea.pageWidth * factor;
                        var newHeight = mouseArea.pageHeight * factor;

                        if (newWidth < root.safeViewportWidth(flick.width) || newHeight < root.safeViewportHeight(flick.height) ||
                            newHeight > flick.height * 3) {
                            return;
                        }

                        mouseArea.pageWidth = newWidth;
                        mouseArea.pageHeight = newHeight;
                        flick.resizeContent(root.pageCanvasWidth(newWidth), root.pageCanvasHeight(newHeight), Qt.point(wheel.x, wheel.y));
                        flick.returnToBounds();
                        resizeTimer.stop();
                    } else {
                        flick.contentY = Math.min(flick.contentHeight-flick.height, Math.max(0, flick.contentY - wheel.angleDelta.y));
                    }
                }

                PageView {
                    id: page1
                    document: root.document
                    trimMargins: root.trimMargins
                    pageDisplayWidth: mouseArea.pageWidth
                    pageDisplayHeight: mouseArea.pageHeight
                    z: 2
                }
                PageView {
                    id: page2
                    document: root.document
                    trimMargins: root.trimMargins
                    pageDisplayWidth: mouseArea.pageWidth
                    pageDisplayHeight: mouseArea.pageHeight
                    z: 1
                }
                PageView {
                    id: page3
                    document: root.document
                    trimMargins: root.trimMargins
                    pageDisplayWidth: mouseArea.pageWidth
                    pageDisplayHeight: mouseArea.pageHeight
                    z: 0
                }

                    
                Binding {
                    target: mouseArea.currPageDelegate
                    property: "pageNumber"
                    value: root.document.currentPage
                    when: !mouseArea.switchingPage
                    restoreMode: Binding.RestoreNone
                }
                Binding {
                    target: mouseArea.currPageDelegate
                    property: "visible"
                    value: true
                    when: !mouseArea.switchingPage
                    restoreMode: Binding.RestoreNone
                }

                Binding {
                    target: mouseArea.prevPageDelegate
                    property: "pageNumber"
                    value: root.document.currentPage - 1
                    when: !mouseArea.switchingPage
                    restoreMode: Binding.RestoreNone
                }
                Binding {
                    target: mouseArea.prevPageDelegate
                    property: "visible"
                    value: !mouseArea.incrementing && root.document.currentPage > 0
                    when: !mouseArea.switchingPage
                    restoreMode: Binding.RestoreNone
                }

                Binding {
                    target: mouseArea.nextPageDelegate
                    property: "pageNumber"
                    value: root.document.currentPage + 1
                    when: !mouseArea.switchingPage
                    restoreMode: Binding.RestoreNone
                }
                Binding {
                    target: mouseArea.nextPageDelegate
                    property: "visible"
                    value: mouseArea.incrementing && root.document.currentPage < document.pageCount-1
                    when: !mouseArea.switchingPage
                    restoreMode: Binding.RestoreNone
                }
                
                SequentialAnimation {
                    id: switchAnimation
                    ParallelAnimation {
                        NumberAnimation {
                            target: flick
                            properties: "contentY"
                            to: 0
                            easing.type: Easing.InQuad
                            //hardcoded number, we would need units from kirigami
                            //which cannot depend from here
                            duration: 250
                        }
                        NumberAnimation {
                            target: mouseArea.currPageDelegate
                            properties: "x"
                            to: mouseArea.incrementing ? -mouseArea.currPageDelegate.width : mouseArea.currPageDelegate.width
                            easing.type: Easing.InQuad
                            //hardcoded number, we would need units from kirigami
                            //which cannot depend from here
                            duration: 250
                        }
                    }
                    ScriptAction {
                        script: {
                            mouseArea.currPageDelegate.z = 0;
                            mouseArea.prevPageDelegate.z = 1;
                            mouseArea.nextPageDelegate.z = 2;
                        }
                    }
                    ScriptAction {
                        script: {
                            mouseArea.currPageDelegate.x = 0
                            var oldCur = mouseArea.currPageDelegate;
                            var oldPrev = mouseArea.prevPageDelegate;
                            var oldNext = mouseArea.nextPageDelegate;

                            mouseArea.switchingPage = true;
                            if (mouseArea.incrementing) {
                                mouseArea.currPageDelegate = oldNext;
                                mouseArea.prevPageDelegate = oldCur;
                                mouseArea.nextPageDelegate = oldPrev;
                                root.document.currentPage++;
                            } else {
                                mouseArea.currPageDelegate = oldPrev;
                                mouseArea.nextPageDelegate = oldCur;
                                mouseArea.prevPageDelegate = oldNext;
                                root.document.currentPage--;
                            }
                            mouseArea.switchingPage = false;
                            mouseArea.currPageDelegate.z = 2;
                            mouseArea.prevPageDelegate.z = 1;
                            mouseArea.nextPageDelegate.z = 0;
                            flick.resetToFit();
                            preloadTimer.restart();
                        }
                    }
                }
                NumberAnimation {
                    id: resetAnim
                    target: mouseArea.currPageDelegate
                    properties: "x"
                    to: 0
                    easing.type: Easing.InQuad
                    duration: 250
                }
            }
        }
    }

    PinchArea {
        id: continuousPinchArea
        anchors.fill: parent
        visible: root.continuousMode
        enabled: visible
        z: 1

        property real startZoom: 1
        property int anchorPageIndex: -1
        property real anchorPageX: 0
        property real anchorPageY: 0
        property bool hasAnchor: false

        function clampUnit(value) {
            return Math.max(0, Math.min(1, value))
        }

        function captureAnchor(center) {
            hasAnchor = false
            if (!continuousList.visible || continuousList.count <= 0) {
                return
            }

            const contentPointX = continuousList.contentX + center.x
            const contentPointY = continuousList.contentY + center.y
            let index = continuousList.indexAt(contentPointX, contentPointY)
            if (index < 0) {
                index = continuousList.currentIndex
            }

            const item = continuousList.itemAtIndex(index)
            if (!item || !item.pageItem) {
                return
            }

            anchorPageIndex = index
            anchorPageX = clampUnit((contentPointX - item.x - item.pageItem.x) / Math.max(1, item.pageItem.width))
            anchorPageY = clampUnit((contentPointY - item.y - item.pageItem.y) / Math.max(1, item.pageItem.height))
            hasAnchor = true
        }

        function restoreAnchor(center) {
            if (!hasAnchor) {
                return false
            }

            const item = continuousList.itemAtIndex(anchorPageIndex)
            if (!item || !item.pageItem) {
                return false
            }

            const targetX = item.x + item.pageItem.x + item.pageItem.width * anchorPageX - center.x
            const targetY = item.y + item.pageItem.y + item.pageItem.height * anchorPageY - center.y
            continuousList.contentX = continuousList.clampContentX(targetX)
            continuousList.contentY = continuousList.clampContentY(targetY)
            return true
        }

        onPinchStarted: (pinch) => {
            startZoom = root.continuousZoom
            captureAnchor(pinch.center)
        }

        onPinchUpdated: (pinch) => {
            const oldZoom = root.continuousZoom
            const nextZoom = Math.max(root.continuousMinZoom, Math.min(root.continuousMaxZoom, startZoom * pinch.scale))
            if (Math.abs(nextZoom - oldZoom) < 0.001) {
                restoreAnchor(pinch.center)
                return
            }

            const fallbackFocusX = continuousList.contentX + pinch.previousCenter.x
            const fallbackFocusY = continuousList.contentY + pinch.previousCenter.y
            const scaleDelta = nextZoom / Math.max(0.01, oldZoom)

            root.continuousZoom = nextZoom
            continuousList.forceLayout()
            if (!restoreAnchor(pinch.center)) {
                continuousList.contentX = continuousList.clampContentX(fallbackFocusX * scaleDelta - pinch.center.x)
                continuousList.contentY = continuousList.clampContentY(fallbackFocusY * scaleDelta - pinch.center.y)
            }
            continuousList.preloadVisiblePages()
        }

        onPinchFinished: {
            hasAnchor = false
            continuousList.returnToBounds()
            continuousList.preloadVisiblePages()
        }

        ListView {
            id: continuousList
            anchors.fill: parent
            visible: parent.visible
            enabled: parent.enabled
            clip: true
            interactive: visible
            boundsBehavior: Flickable.StopAtBounds
            spacing: Math.max(8, Math.round(width * 0.018))
            cacheBuffer: height * 3
            reuseItems: true
            model: root.document && root.document.opened ? root.document.pageCount : 0
            currentIndex: 0
            contentWidth: Math.max(width, root.pageCanvasWidth(root.safeViewportWidth(width) * root.continuousZoom))
            property bool updatingCurrentPage: false

            function pageSizeForRatio(ratio) {
                const safeRatio = Math.max(0.01, ratio)
                const zoom = Math.max(root.continuousMinZoom, Math.min(root.continuousMaxZoom, root.continuousZoom))
                const viewportWidth = root.safeViewportWidth(continuousList.width)
                const viewportHeight = root.safeViewportHeight(continuousList.height)
                let pageWidth = viewportWidth
                let pageHeight = pageWidth / safeRatio

                if (root.fitMode === root.fitPageMode) {
                    const heightFromWidth = viewportWidth / safeRatio
                    if (heightFromWidth <= viewportHeight) {
                        pageWidth = viewportWidth
                        pageHeight = heightFromWidth
                    } else {
                        pageHeight = viewportHeight
                        pageWidth = pageHeight * safeRatio
                    }
                } else if (root.fitMode === root.fillScreenMode) {
                    const heightFromWidth = viewportWidth / safeRatio
                    if (heightFromWidth >= viewportHeight) {
                        pageWidth = viewportWidth
                        pageHeight = heightFromWidth
                    } else {
                        pageHeight = viewportHeight
                        pageWidth = pageHeight * safeRatio
                    }
                }

                return Qt.size(Math.max(1, pageWidth * zoom), Math.max(1, pageHeight * zoom))
            }

            function clampContentX(value) {
                return Math.max(0, Math.min(Math.max(0, contentWidth - width), value))
            }

            function clampContentY(value) {
                return Math.max(0, Math.min(Math.max(0, contentHeight - height), value))
            }

            function clampPageIndex(index) {
                if (!root.document || root.document.pageCount <= 0) {
                    return 0
                }
                return Math.max(0, Math.min(root.document.pageCount - 1, index))
            }

            function setDocumentCurrentPage(index) {
                if (!root.document || !root.document.opened) {
                    return
                }

                const nextIndex = clampPageIndex(index)
                currentIndex = nextIndex
                if (root.document.currentPage !== nextIndex) {
                    updatingCurrentPage = true
                    root.document.currentPage = nextIndex
                    updatingCurrentPage = false
                }
            }

            function updateCurrentPageFromPosition() {
                if (!visible || !root.document || !root.document.opened || count <= 0) {
                    return
                }

                let index = -1
                const probes = [0.25, 0.45, 0.65, 0.85]
                for (let i = 0; i < probes.length && index < 0; ++i) {
                    const probeY = Math.max(0, Math.min(contentHeight - 1, contentY + height * probes[i]))
                    index = indexAt(width / 2, probeY)
                }

                if (index >= 0) {
                    setDocumentCurrentPage(index)
                }
                preloadVisiblePages()
            }

            function positionAtCurrentPage() {
                if (!visible || !root.document || !root.document.opened || count <= 0) {
                    return
                }

                const index = clampPageIndex(root.document.currentPage)
                currentIndex = index
                positionViewAtIndex(index, ListView.Beginning)
                preloadVisiblePages()
            }

            function preloadPage(index) {
                if (index < 0 || index >= count) {
                    return
                }

                const item = itemAtIndex(index)
                if (item && item.pageItem) {
                    item.pageItem.requestPixmap()
                }
            }

            function preloadVisiblePages() {
                if (!visible || count <= 0) {
                    return
                }

                let first = indexAt(width / 2, Math.max(0, contentY + 1))
                let last = indexAt(width / 2, Math.max(0, Math.min(contentHeight - 1, contentY + height - 1)))
                if (first < 0) {
                    first = currentIndex
                }
                if (last < 0) {
                    last = first
                }

                const from = clampPageIndex(Math.min(first, last) - 1)
                const to = clampPageIndex(Math.max(first, last) + 1)
                for (let i = from; i <= to; ++i) {
                    preloadPage(i)
                }
            }

            onContentYChanged: continuousSyncTimer.restart()
            onMovementEnded: updateCurrentPageFromPosition()
            onVisibleChanged: {
                if (visible) {
                    continuousPositionTimer.restart()
                }
            }
            onCountChanged: continuousPositionTimer.restart()
            onWidthChanged: continuousPositionTimer.restart()
            onHeightChanged: continuousPositionTimer.restart()

            delegate: PageView {
                id: continuousPage
                property var fittedPageSize: continuousList.pageSizeForRatio(pageRatio)
                width: Math.max(continuousList.width, root.pageCanvasWidth(fittedPageSize.width))
                height: Math.max(1, root.pageCanvasHeight(fittedPageSize.height))
                document: root.document
                pageNumber: index
                trimMargins: root.trimMargins
                pageDisplayWidth: fittedPageSize.width
                pageDisplayHeight: fittedPageSize.height

                Component.onCompleted: delegatePreloadTimer.restart()
                onPageRatioChanged: delegatePreloadTimer.restart()
                onWidthChanged: delegatePreloadTimer.restart()
                onHeightChanged: delegatePreloadTimer.restart()

                TapHandler {
                    onTapped: root.clicked()
                }

                Timer {
                    id: delegatePreloadTimer
                    interval: 40
                    repeat: false
                    onTriggered: continuousPage.pageItem.requestPixmap()
                }
            }

            Timer {
                id: continuousSyncTimer
                interval: 90
                repeat: false
                onTriggered: continuousList.updateCurrentPageFromPosition()
            }
        }

        MouseArea {
            id: continuousPanArea
            anchors.fill: parent
            enabled: root.continuousMode && root.continuousZoom > root.continuousMinZoom + 0.01
            preventStealing: true
            acceptedButtons: Qt.LeftButton

            property real previousX: 0
            property real previousY: 0
            property real startX: 0
            property real startY: 0
            property bool moved: false

            onPressed: (mouse) => {
                previousX = startX = mouse.x
                previousY = startY = mouse.y
                moved = false
            }

            onPositionChanged: (mouse) => {
                const dx = mouse.x - previousX
                const dy = mouse.y - previousY

                continuousList.contentX = continuousList.clampContentX(continuousList.contentX - dx)
                continuousList.contentY = continuousList.clampContentY(continuousList.contentY - dy)

                if (Math.abs(mouse.x - startX) > 8 || Math.abs(mouse.y - startY) > 8) {
                    moved = true
                }

                previousX = mouse.x
                previousY = mouse.y
            }

            onReleased: {
                continuousList.updateCurrentPageFromPosition()
                continuousList.preloadVisiblePages()
                if (!moved) {
                    root.clicked()
                }
            }

            onCanceled: {
                continuousList.returnToBounds()
                continuousList.updateCurrentPageFromPosition()
            }
        }
    }

    Timer {
        id: continuousPositionTimer
        interval: 0
        repeat: false
        onTriggered: continuousList.positionAtCurrentPage()
    }

    Connections {
        target: root.document
        function onCurrentPageChanged() {
            if (root.continuousMode && !continuousList.updatingCurrentPage) {
                continuousPositionTimer.restart()
            }
        }
    }
}
