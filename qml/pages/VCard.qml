/*
The MIT License (MIT)

Copyright (c) 2018 Slava Monich

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
import org.nemomobile.notifications 1.0
import org.nemomobile.dbus 2.0
//import org.nemomobile.contacts 1.0
import harbour.barcode 1.0

Item {
    id: vcard
    visible: false

    property alias count: model.count
    property alias content: file.content

    function importContact() {
        contactsDbusIface.call("importContactFile", ["" + file.url])
        notification.publish()
    }

    function contact() {
        return model.getPerson(0)
    }

    Rectangle {
        anchors.fill: parent
        color: "#2e2e2e"
    }

    PeopleVCardModel {
        id: model
        source: file.fileName
    }

    DBusInterface {
        id: contactsDbusIface
        service: "com.jolla.contacts.ui"
        path: "/com/jolla/contacts/ui"
        iface: "com.jolla.contacts.ui"
    }

    Notification {
        id: notification
        //: Pop-up notification
        //% "Saved contact"
        previewBody: qsTrId("contact-notification-saved")
        expireTimeout: 2000
    }

    TemporaryFile {
        id: file
        fileTemplate: "barcodeXXXXXX.vcf"
    }
}
