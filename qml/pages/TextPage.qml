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

Page {
    id: textPage

    allowedOrientations: window.allowedOrientations

    property string text
    property string recordId
    property bool hasImage
    property bool canDelete
    property alias format: pageHeader.title
    property alias timestamp: pageHeader.description
    readonly property string normalizedText: Utils.convertLineBreaks(text)
    readonly property bool isUrl: Utils.isUrl(textPage.text) && !isVCard && !isVEvent
    readonly property bool isLink: Utils.isLink(textPage.text) && !isVCard && !isVEvent
    readonly property bool isVCard: Utils.isVcard(normalizedText) && !isVEvent
    readonly property bool isVEvent: Utils.isVevent(normalizedText)
    readonly property bool haveContact: vcard ? (vcard.count > 0) : false
    readonly property bool haveEvent: !!calendarEvent.fileName
    property var vcard

    signal deleteEntry()

    onNormalizedTextChanged: {
        textArea.text = normalizedText
        if (vcard) {
            vcard.content = normalizedText
        }
    }

    onIsVCardChanged: {
        if (isVCard && !vcard) {
            var component = Qt.createComponent("VCard.qml");
            if (component.status === Component.Ready) {
                vcard = component.createObject(textPage, { content: text })
            }
        }
    }

    onStatusChanged: {
        if (status === PageStatus.Deactivating) {
            // Hide the keyboard on flick
            textArea.focus = false
        }
    }

    TemporaryFile {
        id: calendarEvent

        content: isVEvent ? Utils.calendarText(normalizedText) : ""
        fileTemplate: isVEvent ? "barcodeXXXXXX.vcs" : ""
    }

    ReceiptFetcher {
        id: receiptFetcher

        code: textPage.text
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            visible: textPage.canDelete
            MenuItem {
                //: Context menu item
                //% "Delete"
                text: qsTrId("history-menu-delete")
                onClicked: textPage.deleteEntry()
            }
        }

        Column {
            id: column

            x: Theme.horizontalPageMargin
            width: parent.width - 2 * x
            height: childrenRect.height

            PageHeader { id: pageHeader }

            TextArea {
                id: textArea
                width: parent.width
                selectionMode: TextEdit.SelectWords
                labelVisible: true
                readOnly: false
                wrapMode: TextEdit.Wrap
                property int lastCursorPosition
                property int currentCursorPosition
                property bool settingTextFromTextChangedHandler
                onCursorPositionChanged: {
                    lastCursorPosition = currentCursorPosition
                    currentCursorPosition = cursorPosition
                }
                onTextChanged: {
                    if (settingTextFromTextChangedHandler) {
                        // TextArea isn't just accepting the text, sometimes
                        // it internally mutates it which can send us into
                        // an infinite setText/textChanged/setText recursion.
                        // We don't want that to happen.
                        console.warn("refusing to recurse!")
                    } else if (text !== textPage.normalizedText) {
                        settingTextFromTextChangedHandler = true
                        text = textPage.normalizedText
                        settingTextFromTextChangedHandler = false
                        // The text doesn't actually get updated until the
                        // cursor position changes
                        cursorPosition = lastCursorPosition
                    }
                }
            }

            Button {
                id: button

                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    if (isLink) {
                        //: Button text
                        //% "Open link"
                        return qsTrId("text-open_link")
                    } else if (isUrl) {
                        //: Button text
                        //% "Open URL"
                        return qsTrId("text-open_url")
                    } else if (haveContact) {
                        //: Button text
                        //% "Contact card"
                        return qsTrId("text-contact_card")
                    } else if (haveEvent) {
                        //: Button text
                        //% "Add to calendar"
                        return qsTrId("text-add_to_calendar")
                    } else if (receiptFetcher.state === ReceiptFetcher.StateChecking) {
                        return holdOffTimer.running ?
                            //: Button text
                            //% "Fetching..."
                            qsTrId("text-fetching_receipt") :
                            //: Button label (cancel network operation)
                            //% "Cancel"
                            qsTrId("text-cancel_fetching")
                    } else if (receiptFetcher.state !== ReceiptFetcher.StateIdle) {
                        //: Button text
                        //% "Fetch receipt"
                        return qsTrId("text-fetch_receipt")
                    } else {
                        return ""
                    }
                }
                visible: text.length > 0
                enabled: !holdOffTimer.running
                onClicked: {
                    if (isUrl) {
                        console.log("opening", textPage.text)
                        Qt.openUrlExternally(textPage.text)
                        holdOffTimer.restart()
                    } else if (haveEvent) {
                        console.log("importing", calendarEvent.url)
                        Qt.openUrlExternally(calendarEvent.url)
                        holdOffTimer.restart()
                    } else if (haveContact) {
                        // Workaround for Sailfish.Contacts not being allowed in harbour apps
                        var page = Qt.createQmlObject("import QtQuick 2.0;import Sailfish.Silica 1.0;import Sailfish.Contacts 1.0; \
    Page { id: page; signal saveContact(); property alias contact: card.contact; property alias saveText: saveMenu.text; \
    ContactCard { id: card; PullDownMenu { MenuItem { id: saveMenu; onClicked: page.saveContact(); }}}}",
                            textPage, "ContactPage")
                        pageStack.push(page, {
                            allowedOrientations: textPage.allowedOrientations,
                            contact: textPage.vcard.contact(),
                            //: Pulley menu item (saves contact)
                            //% "Save"
                            saveText: qsTrId("contact-menu-save")
                        }).saveContact.connect(function() {
                           pageStack.pop()
                           textPage.vcard.importContact()
                        })
                    } else if (receiptFetcher.state === ReceiptFetcher.StateChecking) {
                        receiptFetcher.cancel()
                    } else {
                        // Fetch Receipt
                        holdOffTimer.restart()
                        receiptFetcher.fetch()
                    }
                }
                Timer {
                    id: holdOffTimer

                    interval: 2000
                }
            }

            Item {
                readonly property bool isChecking: receiptFetcher.state === ReceiptFetcher.StateChecking
                readonly property bool isError: receiptFetcher.state === ReceiptFetcher.StateFailure

                visible: height > 0
                height: (isChecking || isError) ? Theme.itemSizeSmall : button.visible ? Theme.paddingLarge : 0
                width: parent.width

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.paddingMedium
                    visible: opacity > 0
                    opacity: parent.isChecking ? 1 : 0

                    BusyIndicator {
                        running: parent.opacity != 0
                        size: BusyIndicatorSize.ExtraSmall
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: Theme.fontSizeSmall
                        truncationMode: TruncationMode.Fade
                        color: Theme.highlightColor
                        //: Progress label
                        //% "Contacting %1..."
                        text: qsTrId("text-fetch_contacting").arg(receiptFetcher.host)
                    }
                    Behavior on opacity { FadeAnimation {} }
                }

                Label {
                    anchors.centerIn: parent
                    font.pixelSize: Theme.fontSizeSmall
                    truncationMode: TruncationMode.Fade
                    verticalAlignment: Text.AlignVCenter
                    color: Theme.highlightColor
                    visible: opacity > 0
                    opacity: parent.isError ? 1 : 0
                    text: {
                        switch (receiptFetcher.error) {
                        case ReceiptFetcher.ErrorNotFound:
                            //: Status label
                            //% "Receipt not found"
                            return qsTrId("text-receipt_not_found")
                        case ReceiptFetcher.ErrorNetwork:
                            //: Status label
                            //% "Network error"
                            return qsTrId("text-network_error")
                        }
                        return ""
                    }
                    Behavior on opacity { FadeAnimation {} }
                }

                Behavior on height { SmoothedAnimation { duration: 100 } }
            }

            Item {
                width: parent.width
                height: receiptView.item ? (receiptView.item.height + Theme.paddingLarge) : 0
                visible: receiptView.active

                Loader {
                    id: receiptView

                    width: parent.width
                    source: receiptFetcher.state === ReceiptFetcher.StateSuccess ? "../components/HtmlView.qml" : ""
                    onStatusChanged: {
                        if (status == Loader.Ready) {
                            item.htmlBody = receiptFetcher.receipt
                        }
                    }
                }
            }

            Image {
                id: image

                readonly property bool isPortrait: sourceSize.height > sourceSize.width
                readonly property bool rotate: image.isPortrait != textPage.isPortrait

                anchors.horizontalCenter: parent.horizontalCenter
                source: (hasImage && recordId.length && AppSettings.saveImages) ?
                    ("image://scanner/saved/" + (textPage.isPortrait ? "portrait/" : "landscape/") + recordId) : ""
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
