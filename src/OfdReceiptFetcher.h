/*
The MIT License (MIT)

Copyright (c) 2019 Slava Monich

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

#ifndef OFD_RECEIPT_FETCHER_H
#define OFD_RECEIPT_FETCHER_H

#include <QtQml>

class OfdReceiptFetcher : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString code READ code WRITE setCode NOTIFY codeChanged)
    Q_PROPERTY(QString receipt READ receipt NOTIFY receiptChanged)
    Q_PROPERTY(State state READ state NOTIFY stateChanged)
    Q_PROPERTY(Error error READ error NOTIFY errorChanged)
    Q_PROPERTY(QString host READ host CONSTANT)
    Q_ENUMS(State)
    Q_ENUMS(Error)

public:
    enum State {
        StateIdle,
        StateReady,
        StateChecking,
        StateFailure,
        StateSuccess
    };

    enum Error {
        NoError,
        ErrorNotFound,
        ErrorNetwork
    };

    OfdReceiptFetcher(QObject* aParent = Q_NULLPTR);

    Q_INVOKABLE void fetch();
    Q_INVOKABLE void cancel();

    State state() const;
    Error error() const;
    QString host() const;
    QString receipt() const;
    QString code() const;
    void setCode(QString aCode);

Q_SIGNALS:
    void codeChanged();
    void receiptChanged();
    void stateChanged();
    void errorChanged();

private:
    class Private;
    Private* iPrivate;
};

QML_DECLARE_TYPE(OfdReceiptFetcher)

#endif // OFD_RECEIPT_FETCHER_H
