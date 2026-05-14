/*
    SPDX-FileCopyrightText: 2015 Marco Martin <mart@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.okular 2.0
import org.kde.kirigami 2.17 as Kirigami

Item {
    width: parent.width
    height: parent.height
    readonly property PageItem pageItem: page
    property alias document: page.document
    property alias pageNumber: page.pageNumber
    property alias trimMargins: page.trimMargins
    property real pageDisplayWidth: parent ? parent.width : 0
    property real pageDisplayHeight: pageDisplayWidth / pageRatio
    implicitWidth: page.implicitWidth
    implicitHeight: page.implicitHeight
    readonly property real pageRatio: page.cropRatio > 0 ? page.cropRatio : 1
    readonly property real scaleFactor: page.width / page.implicitWidth

    PageItem {
        id: page
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(0, (parent.height - height) / 2)
        width: Math.max(1, parent.pageDisplayWidth)
        height: Math.max(1, parent.pageDisplayHeight)
        document: null
    }

    Rectangle {
        id: backgroundRectangle
        visible: page.document.opened
        anchors {
            top: page.top
            bottom: page.bottom
            left: page.left
            right: page.right
        }
        z: -1
        color: "white"

        Rectangle {
            width: Kirigami.Units.gridUnit
            anchors {
                right: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: "transparent"
                }
                GradientStop {
                    position: 0.7
                    color: Qt.rgba(0, 0, 0, 0.08)
                }
                GradientStop {
                    position: 1.0
                    color: Qt.rgba(0, 0, 0, 0.2)
                }
            }
        }

        Rectangle {
            width: Kirigami.Units.gridUnit
            anchors {
                left: parent.right
                top: parent.top
                bottom: parent.bottom
            }
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: Qt.rgba(0, 0, 0, 0.2)
                }
                GradientStop {
                    position: 0.3
                    color: Qt.rgba(0, 0, 0, 0.08)
                }
                GradientStop {
                    position: 1.0
                    color: "transparent"
                }
            }
        }
    }
}
