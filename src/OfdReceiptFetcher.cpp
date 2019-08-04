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

#include "OfdReceiptFetcher.h"
#include "HarbourDebug.h"

#include <QJsonObject>
#include <QJsonDocument>

#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QUrl>

#define PROPERTIES(p) \
    p(code,Code), \
    p(receipt,Receipt), \
    p(state,State), \
    p(error,Error)

// ==========================================================================
// OfdReceiptFetcher::Private
// ==========================================================================

class OfdReceiptFetcher::Private : public QObject {
    Q_OBJECT

public:
    Private(OfdReceiptFetcher* aParent);
    ~Private();

    static const QUrl URL;
    static const QString ContentType;
    static const QString TotalSumTag;
    static const QString TotalSumJson;
    static const QString FnNumberTag;
    static const QString FnNumberJson;
    static const QString OperationTypeTag;
    static const QString OperationTypeJson;
    static const QString DocNumberTag;
    static const QString DocNumberJson;
    static const QString DocFiscalSignTag;
    static const QString DocFiscalSignJson;
    static const QString DocDateTimeTag;
    static const QString DocDateTimeJson;

    typedef QHash<QString,QString> ParsedCode;
    typedef void (OfdReceiptFetcher::*SignalEmitter)();
    typedef uint SignalMask;
    enum Signal {
#define DEFINE_SIGNAL(name,Name) Signal##Name##Changed
        PROPERTIES(DEFINE_SIGNAL),
        SignalCount
#undef DEFINE_SIGNAL
    };

    static ParsedCode parseCode(QString aCode);

    OfdReceiptFetcher* owner() const;
    void queueSignal(Signal aSignal);
    void emitQueuedSignals();
    void setCode(QString aCode);
    void setState(State aState);
    void setError(Error aState);
    void cancel();
    void startFetch();

private Q_SLOTS:
    void onRequestFinished();

public:
    SignalMask iQueuedSignals;
    Signal iFirstQueuedSignal;
    State iState;
    Error iError;
    QString iCode;
    QString iReceipt;
    ParsedCode iParsedCode;
    QNetworkAccessManager* iAccessManager;
    QNetworkReply* iReply;
};

const QUrl OfdReceiptFetcher::Private::URL("https://check.ofd.ru/Document/FetchReceiptFromFns");
const QString OfdReceiptFetcher::Private::ContentType("application/json");
const QString OfdReceiptFetcher::Private::TotalSumTag("s");
const QString OfdReceiptFetcher::Private::TotalSumJson("TotalSum");
const QString OfdReceiptFetcher::Private::FnNumberTag("fn");
const QString OfdReceiptFetcher::Private::FnNumberJson("FnNumber");
const QString OfdReceiptFetcher::Private::OperationTypeTag("n");
const QString OfdReceiptFetcher::Private::OperationTypeJson("ReceiptOperationType");
const QString OfdReceiptFetcher::Private::DocNumberTag("i");
const QString OfdReceiptFetcher::Private::DocNumberJson("DocNumber");
const QString OfdReceiptFetcher::Private::DocFiscalSignTag("fp");
const QString OfdReceiptFetcher::Private::DocFiscalSignJson("DocFiscalSign");
const QString OfdReceiptFetcher::Private::DocDateTimeTag("t");
const QString OfdReceiptFetcher::Private::DocDateTimeJson("DocDateTime");

OfdReceiptFetcher::Private::Private(OfdReceiptFetcher* aParent) :
    QObject(aParent),
    iQueuedSignals(0),
    iFirstQueuedSignal(SignalCount),
    iState(OfdReceiptFetcher::StateIdle),
    iError(OfdReceiptFetcher::NoError),
    iAccessManager(Q_NULLPTR),
    iReply(Q_NULLPTR)
{
}

OfdReceiptFetcher::Private::~Private()
{
    cancel();
}

OfdReceiptFetcher* OfdReceiptFetcher::Private::owner() const
{
    return qobject_cast<OfdReceiptFetcher*>(parent());
}

void OfdReceiptFetcher::Private::queueSignal(Signal aSignal)
{
    if (aSignal >= 0 && aSignal < SignalCount) {
        const SignalMask signalBit = (SignalMask(1) << aSignal);
        if (iQueuedSignals) {
            iQueuedSignals |= signalBit;
            if (iFirstQueuedSignal > aSignal) {
                iFirstQueuedSignal = aSignal;
            }
        } else {
            iQueuedSignals = signalBit;
            iFirstQueuedSignal = aSignal;
        }
    }
}

void OfdReceiptFetcher::Private::emitQueuedSignals()
{
    static const SignalEmitter emitSignal[] = {
#define EMITTER(name,Name) &OfdReceiptFetcher::name##Changed
        PROPERTIES(EMITTER)
#undef EMITTER
    };

    if (iQueuedSignals) {
        OfdReceiptFetcher* fetcher = owner();
        // Reset first queued signal before emitting the signals.
        // Signal handlers may emit new signals.
        uint i = iFirstQueuedSignal;
        iFirstQueuedSignal = SignalCount;
        for (; i < SignalCount && iQueuedSignals; i++) {
            const SignalMask signalBit = (SignalMask(1) << i);
            if (iQueuedSignals & signalBit) {
                iQueuedSignals &= ~signalBit;
                Q_EMIT (fetcher->*(emitSignal[i]))();
            }
        }
    }
}

OfdReceiptFetcher::Private::ParsedCode OfdReceiptFetcher::Private::parseCode(QString aCode)
{
    ParsedCode table;
    int pos1, pos2;
    // The string has to look like "t=20180411T162100&s=355.00&fn=..."
    if ((pos1 = aCode.indexOf('=')) > 0 &&
        (pos2 = aCode.indexOf('&')) > 0 &&
         pos1 < pos2) {
        // A quick test has passed, let's try to actually parse it
        const QStringList fields(aCode.split('&'));
        const int n = fields.count();
        for (int i = 0; i < n; i++) {
            const QString field(fields.at(i));
            const QStringList pair(field.split('='));
            if (pair.count() == 2) {
                table.insert(pair.at(0).trimmed(), pair.at(1).trimmed());
            }
        }
    }
    return table;
}

void OfdReceiptFetcher::Private::setCode(QString aCode)
{
    if (iCode != aCode) {
        iCode = aCode;
        queueSignal(SignalCodeChanged);
        cancel();
        const ParsedCode parsed = parseCode(aCode);
        if (parsed.size() >= 6 &&
            parsed.contains(TotalSumTag) &&
            parsed.contains(FnNumberTag) &&
            parsed.contains(OperationTypeTag) &&
            parsed.contains(DocNumberTag) &&
            parsed.contains(DocFiscalSignTag)) {
            const QString t(parsed.value(DocDateTimeTag));
            const QString s(parsed.value(TotalSumTag));
            // Accept both "20190622T1855" and "20190622T185500"
            if ((t.length() == 15 || t.length() == 13) && t.at(8) == 'T' &&
                 s.length() >= 3 && s.at(s.length() - 3) == '.') {
                HDEBUG(iCode << "looks like a Russian receipt code");
                iParsedCode = parsed;
                setState(StateReady);
                return;
            }
        }
        HDEBUG(iCode << "is not a Russian receipt code");
        iParsedCode = ParsedCode();
        setState(StateIdle);
    }
}

void OfdReceiptFetcher::Private::setState(State aState)
{
    if (iState != aState) {
        iState = aState;
        queueSignal(SignalStateChanged);
        if (iState != StateFailure) {
            setError(NoError);
        }
    }
}

void OfdReceiptFetcher::Private::setError(Error aError)
{
    if (iError != aError) {
        iError = aError;
        queueSignal(SignalErrorChanged);
    }
}

void OfdReceiptFetcher::Private::cancel()
{
    if (iReply) {
        iReply->disconnect(this);
        iReply->abort();
        delete iReply;
        iReply = Q_NULLPTR;
    }
}

void OfdReceiptFetcher::Private::startFetch()
{
    cancel();
    if (!iParsedCode.isEmpty()) {
        if (!iAccessManager) {
            QQmlContext* context = QQmlEngine::contextForObject(owner());
            if (context) {
                QQmlEngine* engine = context->engine();
                if (engine) {
                    iAccessManager = engine->networkAccessManager();
                }
            }
            if (!iAccessManager) {
                HWARN("Creating default QNetworkAccessManager");
                iAccessManager = new QNetworkAccessManager(this);
            }
        }

        // "100.00" -> "10000"
        QString s(iParsedCode.value(TotalSumTag));
        s.remove(s.length() - 3, 1);

        // "20190622T1855"   -> "2019-06-22T18:55:00.000Z"
        // "20190625T175300" -> "2019-06-25T17:53:00.000Z"
        QString t(iParsedCode.value(DocDateTimeTag));
        t.insert(4, '-');
        t.insert(7, '-');
        t.insert(13, ':');
        if (t.length() == 16) {
            // No seconds
            t.append(":00.000Z");
        } else {
            // Seconds are included
            t.insert(16, ':');
            t.append(".000Z");
        }

        QJsonObject json;
        json.insert(TotalSumJson, s);
        json.insert(FnNumberJson, iParsedCode.value(FnNumberTag));
        json.insert(OperationTypeJson, iParsedCode.value(OperationTypeTag));
        json.insert(DocNumberJson, iParsedCode.value(DocNumberTag));
        json.insert(DocFiscalSignJson, iParsedCode.value(DocFiscalSignTag));
        json.insert(DocDateTimeJson, t);

        const QByteArray data(QJsonDocument(json).toJson(QJsonDocument::Compact));
        HDEBUG(iCode << "=>" << QString(data));

        QNetworkRequest request(URL);
        request.setHeader(QNetworkRequest::ContentTypeHeader, ContentType);
        request.setHeader(QNetworkRequest::UserAgentHeader, "Mozilla/5.0");
        iReply = iAccessManager->post(request, data);
        connect(iReply, SIGNAL(finished()), this, SLOT(onRequestFinished()));
        setState(StateChecking);
    }
}

void OfdReceiptFetcher::Private::onRequestFinished()
{
    QNetworkReply* reply = qobject_cast<QNetworkReply*>(sender());
    reply->deleteLater();
    if (iReply == reply) {
        iReply = Q_NULLPTR;
        if (reply->error() == QNetworkReply::NoError) {
            iReceipt = QString(reply->readAll());
            HDEBUG(iReceipt);
            setState(StateSuccess);
            setError(NoError);
        } else {
            HDEBUG(reply->url().host() << reply->error());
            setState(StateFailure);
            setError((reply->error() == QNetworkReply::ContentNotFoundError) ?
                ErrorNotFound : ErrorNetwork);
        }
        emitQueuedSignals();
    }
}

// ==========================================================================
// OfdReceiptFetcher
// ==========================================================================
OfdReceiptFetcher::OfdReceiptFetcher(QObject* aParent) :
    QObject(aParent),
    iPrivate(new Private(this))
{
}

OfdReceiptFetcher::State OfdReceiptFetcher::state() const
{
    return iPrivate->iState;
}

OfdReceiptFetcher::Error OfdReceiptFetcher::error() const
{
    return iPrivate->iError;
}

QString OfdReceiptFetcher::host() const
{
    return Private::URL.host();
}

QString OfdReceiptFetcher::receipt() const
{
    return iPrivate->iReceipt;
}

QString OfdReceiptFetcher::code() const
{
    return iPrivate->iCode;
}

void OfdReceiptFetcher::setCode(QString aCode)
{
    iPrivate->setCode(aCode);
    iPrivate->emitQueuedSignals();
}

void OfdReceiptFetcher::fetch()
{
    iPrivate->startFetch();
    iPrivate->emitQueuedSignals();
}

void OfdReceiptFetcher::cancel()
{
    iPrivate->cancel();
    iPrivate->setState(iPrivate->iParsedCode.isEmpty() ? StateIdle : StateReady);
    iPrivate->emitQueuedSignals();
}

#include "OfdReceiptFetcher.moc"
