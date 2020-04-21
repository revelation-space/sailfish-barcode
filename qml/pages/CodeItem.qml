/*
The MIT License (MIT)

Copyright (c) 2014 Steffen Förster
Copyright (c) 2018-2020 Slava Monich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.barcode 1.0

import "../js/Utils.js" as Utils

Item {
    id: codeItem

    property string text
    property string recordId
    property bool hasImage
    property string format
    property string timestamp
    property bool isPortrait
    property bool canDelete: true
    property real offsetY
    property variant stringList: text.split("\r\n")
    property bool isParsed: (stringList.length > 1)

    signal deleteEntry()

    Rectangle {
        anchors.fill: parent
        color: "#2e2e2e"
    }

    SilicaFlickable {
        y: offsetY
        width: parent.width
        height: parent.height - offsetY
        contentHeight: column.height

        PullDownMenu {
            visible: codeItem.canDelete
            MenuItem {
                //: Context menu item
                //% "Delete"
                text: qsTrId("history-menu-delete")
                onClicked: codeItem.deleteEntry()
            }
        }

        Column {
            id: column

            x: Theme.horizontalPageMargin
            width: parent.width - 2 * x
            height: childrenRect.height

            PageHeader {
                id: pageHeader

                title: "QR код"
                description: HistoryModel.formatTimestamp(codeItem.timestamp)
            }

            Label {
                width: parent.width
                visible: isParsed
                leftPadding: Theme.paddingLarge
                text: "Имя"
                bottomPadding: Theme.paddingSmall
            }

            Rectangle {
                width: parent.width
                height: Theme.itemSizeSmall
                radius: Theme.paddingMedium
                color: isParsed ? "#e0e0e0" : "#ff6666"

                Label {
                    id: nameLabel
                    width: parent.width
                    wrapMode: Label.Wrap
                    text: stringList[0]
                    color: "#2e2e2e"
                    horizontalAlignment: isParsed ? Text.AlignLeft : Text.AlignHCenter
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: isParsed ? Theme.paddingLarge : 0
                }
            }


            Label {
                width: parent.width
                visible: isParsed
                leftPadding: Theme.paddingLarge
                text: "Дата рождения:"
                bottomPadding: Theme.paddingSmall
                topPadding: Theme.paddingMedium
                horizontalAlignment: Text.AlignLeft
            }

            Rectangle {
                width: parent.width
                visible: isParsed
                height: Theme.itemSizeSmall
                radius: Theme.paddingMedium
                color: "#e0e0e0"
                Label {
                    width: parent.width
                    visible: isParsed
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    leftPadding: Theme.paddingLarge
                    text: isParsed ? stringList[1] : ""
                    color: "#2e2e2e"
                }
            }

            Label {
                width: parent.width
                visible: isParsed
                leftPadding: Theme.paddingLarge
                text: "Заявка:"
                bottomPadding: Theme.paddingSmall
                topPadding: Theme.paddingMedium
                horizontalAlignment: Text.AlignLeft
            }

            Rectangle {
                width: parent.width
                visible: isParsed
                height: Theme.itemSizeSmall
                radius: Theme.paddingMedium
                color: "#e0e0e0"
                Label {
                    width: parent.width
                    visible: isParsed
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    leftPadding: Theme.paddingLarge
                    text: isParsed ? stringList[2].substring(7) : ""
                    color: "#2e2e2e"
                }
            }

            Label {
                width: parent.width
                visible: isParsed
                leftPadding: Theme.paddingLarge
                topPadding: Theme.paddingMedium
                text: "Паспорт:"
                bottomPadding: Theme.paddingSmall
            }

            Rectangle {
                width: parent.width
                visible: isParsed
                height: Theme.itemSizeSmall
                radius: Theme.paddingMedium
                color: "#e0e0e0"
                Label {
                    width: parent.width
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    text: isParsed ? stringList[3].substring(9) : ""
                    leftPadding: Theme.paddingLarge
                    color: "#2e2e2e"
                }
            }

            Rectangle {
                width: parent.width
                height: Theme.paddingLarge
                color: "#2e2e2e"
                visible: isParsed
            }

            Rectangle {
                width: parent.width
                visible: isParsed
                height: Theme.itemSizeSmall
                radius: Theme.paddingMedium
                color: stringList[4] === "Да" ? "#66ff66" : "#ff6666"
                Label {
                    id: encoding
                    width: parent.width
                    color: "#2e2e2e"
                    horizontalAlignment: Text.AlignHCenter
                    text: stringList[4] === "Да" ? "Шифрование верно" : "Код не зашифрован"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                width: parent.width
                height: Theme.paddingLarge
                color: "#2e2e2e"
            }

            Image {
                id: image

                readonly property bool isPortrait: sourceSize.height > sourceSize.width
                readonly property bool rotate: image.isPortrait !== codeItem.isPortrait

                anchors.horizontalCenter: parent.horizontalCenter
                source: (hasImage && recordId.length && AppSettings.saveImages) ?
                    ("image://scanner/saved/" + (codeItem.isPortrait ? "portrait/" : "landscape/") + recordId) : ""
                visible: status === Image.Ready
                asynchronous: true
                cache: false
            }

            Item {
                visible: image.visible
                height: Theme.paddingLarge
                width: 1
            }
        }

        VerticalScrollDecorator { }
    }
}
