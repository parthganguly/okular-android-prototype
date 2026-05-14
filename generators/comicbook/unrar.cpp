/*
    SPDX-FileCopyrightText: 2007 Tobias Koenig <tokoe@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "unrar.h"

#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QGlobalStatic>
#include <QLoggingCategory>
#include <QProcessEnvironment>
#include <QStandardPaths>
#include <QTemporaryDir>
#ifdef Q_OS_ANDROID
#include <QJniObject>
#endif

#include "debug_comicbook.h"

#include <QRegularExpression>
#include <memory>

struct UnrarHelper {
    UnrarHelper();
    ~UnrarHelper();

    UnrarHelper(const UnrarHelper &) = delete;
    UnrarHelper &operator=(const UnrarHelper &) = delete;

    UnrarFlavour *kind;
    QString unrarPath;
    QString lsarPath;
};

Q_GLOBAL_STATIC(UnrarHelper, helper)

static QString androidNativeLibraryDir();
static QProcessEnvironment processEnvironmentWithAndroidLibraries();

static UnrarFlavour *detectUnrar(const QString &unrarPath, const QString &versionCommand)
{
    UnrarFlavour *kind = nullptr;
    QProcess proc;
    proc.setProcessEnvironment(processEnvironmentWithAndroidLibraries());
    proc.start(unrarPath, QStringList() << versionCommand);
    bool ok = proc.waitForFinished(-1);
    Q_UNUSED(ok)
    static const QRegularExpression regex(QStringLiteral("[\r\n]"));
    const QString output = QString::fromLocal8Bit(proc.readAllStandardOutput());
    const QList<QStringView> lines = QStringView(output).split(regex, Qt::SkipEmptyParts);
    if (!lines.isEmpty()) {
        if (lines.first().startsWith(QLatin1String("UNRAR "))) {
            kind = new NonFreeUnrarFlavour();
        } else if (lines.first().startsWith(QLatin1String("RAR "))) {
            kind = new NonFreeUnrarFlavour();
        } else if (lines.first().startsWith(QLatin1String("unrar "))) {
            kind = new FreeUnrarFlavour();
        } else if (lines.first().startsWith(QLatin1String("v"))) {
            kind = new UnarFlavour();
        } else if (lines.first().startsWith(QLatin1String("bsdtar "))) {
            kind = new BsdtarFlavour();
        }
    }
    return kind;
}

static QString androidNativeLibraryDir()
{
#ifdef Q_OS_ANDROID
    const QJniObject dir = QJniObject::callStaticObjectMethod("org/kde/something/FileClass", "nativeLibraryDir", "()Ljava/lang/String;");
    return dir.toString();
#else
    return QString();
#endif
}

static QProcessEnvironment processEnvironmentWithAndroidLibraries()
{
    QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
    const QString nativeLibraryDir = androidNativeLibraryDir();
    if (!nativeLibraryDir.isEmpty()) {
        const QString existingLibraryPath = environment.value(QStringLiteral("LD_LIBRARY_PATH"));
        environment.insert(QStringLiteral("LD_LIBRARY_PATH"),
                           existingLibraryPath.isEmpty() ? nativeLibraryDir : nativeLibraryDir + QLatin1Char(':') + existingLibraryPath);
    }
    return environment;
}

static QStringList androidBundledExtractorCandidates()
{
    const QString nativeLibraryDir = androidNativeLibraryDir();
    if (nativeLibraryDir.isEmpty()) {
        return {};
    }

    return {
        nativeLibraryDir + QLatin1String("/libbsdtar_arm64-v8a.so"),
        nativeLibraryDir + QLatin1String("/libbsdtar.so"),
        nativeLibraryDir + QLatin1String("/bsdtar"),
    };
}

static QStringList executableCandidates()
{
    QStringList candidates;

    const auto appendFoundExecutable = [&candidates](const QString &name) {
        const QString path = QStandardPaths::findExecutable(name);
        if (!path.isEmpty()) {
            candidates.append(path);
        }
    };

    appendFoundExecutable(QStringLiteral("unrar-nonfree"));
    appendFoundExecutable(QStringLiteral("unrar"));
    appendFoundExecutable(QStringLiteral("rar"));
    appendFoundExecutable(QStringLiteral("unar"));
    appendFoundExecutable(QStringLiteral("bsdtar"));
    candidates.append(androidBundledExtractorCandidates());
    candidates.removeDuplicates();

    return candidates;
}

UnrarHelper::UnrarHelper()
    : kind(nullptr)
{
    QString path = QStandardPaths::findExecutable(QStringLiteral("lsar"));

    if (!path.isEmpty()) {
        lsarPath = path;
    }

    for (const QString &candidate : executableCandidates()) {
        if (!QFileInfo::exists(candidate)) {
            continue;
        }

        kind = detectUnrar(candidate, QStringLiteral("--version"));

        if (!kind) {
            kind = detectUnrar(candidate, QStringLiteral("-v"));
        }

        if (kind) {
            path = candidate;
            break;
        }
    }

    if (!kind) {
        // no luck, print that
        qWarning() << "Neither unrar nor unarchiver were found.";
    } else {
        unrarPath = path;
        qCDebug(OkularComicbookDebug) << "detected:" << path << "(" << kind->name() << ")";
    }
}

UnrarHelper::~UnrarHelper()
{
    delete kind;
}

Unrar::Unrar()
    : QObject(nullptr)
    , mProcess(nullptr)
    , mLoop(nullptr)
    , mTempDir(nullptr)
{
}

Unrar::~Unrar()
{
    delete mTempDir;
}

bool Unrar::open(const QString &fileName)
{
    if (!isSuitableVersionAvailable()) {
        return false;
    }

    delete mTempDir;
    mTempDir = new QTemporaryDir();

    mFileName = fileName;

    /**
     * Extract the archive to a temporary directory
     */
    mStdOutData.clear();
    mStdErrData.clear();

    const int ret = startSyncProcess(helper->kind->processOpenArchiveArgs(mFileName, mTempDir->path()));
    bool ok = ret == 0;

    return ok;
}

QStringList Unrar::list()
{
    mStdOutData.clear();
    mStdErrData.clear();

    if (!isSuitableVersionAvailable()) {
        return QStringList();
    }

    startSyncProcess(helper->kind->processListArgs(mFileName));

    static const QRegularExpression regex(QStringLiteral("[\r\n]"));
    QStringList listFiles = helper->kind->processListing(QString::fromLocal8Bit(mStdOutData).split(regex, Qt::SkipEmptyParts));

    QString subDir;

    if (listFiles.last().endsWith(QLatin1Char('/')) && helper->kind->name() == QLatin1String("unar")) {
        // Subfolder detected. The unarchiver is unable to extract all files into a single folder
        subDir = listFiles.last();
        listFiles.removeLast();
    }

    QStringList newList;
    for (const QString &f : std::as_const(listFiles)) {
        const QString extractedPath = mTempDir->path() + QLatin1Char('/') + f;
        if (QFile::exists(extractedPath)) {
            newList.append(f);
            continue;
        }

        // Extract all the files to mTempDir regardless of their path inside the archive
        // This will break if ever an arvhice with two files with the same name in different subfolders
        QFileInfo fi(f);
        if (QFile::exists(mTempDir->path() + QLatin1Char('/') + subDir + fi.fileName())) {
            newList.append(subDir + fi.fileName());
        }
    }
    return newList;
}

QByteArray Unrar::contentOf(const QString &fileName) const
{
    if (!isSuitableVersionAvailable()) {
        return QByteArray();
    }

    QFile file(mTempDir->path() + QLatin1Char('/') + fileName);
    if (!file.open(QIODevice::ReadOnly)) {
        return QByteArray();
    }

    return file.readAll();
}

QIODevice *Unrar::createDevice(const QString &fileName) const
{
    if (!isSuitableVersionAvailable()) {
        return nullptr;
    }

    std::unique_ptr<QFile> file(new QFile(mTempDir->path() + QLatin1Char('/') + fileName));
    if (!file->open(QIODevice::ReadOnly)) {
        return nullptr;
    }

    return file.release();
}

bool Unrar::isAvailable()
{
    return helper->kind;
}

bool Unrar::isSuitableVersionAvailable()
{
    if (!isAvailable()) {
        return false;
    }

    if (dynamic_cast<NonFreeUnrarFlavour *>(helper->kind) || dynamic_cast<UnarFlavour *>(helper->kind) || dynamic_cast<BsdtarFlavour *>(helper->kind)) {
        return true;
    } else {
        return false;
    }
}

void Unrar::readFromStdout()
{
    if (!mProcess) {
        return;
    }

    mStdOutData += mProcess->readAllStandardOutput();
}

void Unrar::readFromStderr()
{
    if (!mProcess) {
        return;
    }

    mStdErrData += mProcess->readAllStandardError();
    if (!mStdErrData.isEmpty()) {
        mProcess->kill();
        return;
    }
}

void Unrar::finished(int exitCode, QProcess::ExitStatus exitStatus)
{
    Q_UNUSED(exitCode)
    if (mLoop) {
        mLoop->exit(exitStatus == QProcess::CrashExit ? 1 : 0);
    }
}

int Unrar::startSyncProcess(const ProcessArgs &args)
{
    int ret = 0;

    mProcess = new QProcess(this);
    mProcess->setProcessEnvironment(processEnvironmentWithAndroidLibraries());

    connect(mProcess, &QProcess::readyReadStandardOutput, this, &Unrar::readFromStdout);
    connect(mProcess, &QProcess::readyReadStandardError, this, &Unrar::readFromStderr);
    connect(mProcess, static_cast<void (QProcess::*)(int, QProcess::ExitStatus)>(&QProcess::finished), this, &Unrar::finished);

    if (helper->kind->name() == QLatin1String("unar") && args.useLsar) {
        mProcess->start(helper->lsarPath, args.appArgs, QIODevice::ReadWrite | QIODevice::Unbuffered);
    } else {
        mProcess->start(helper->unrarPath, args.appArgs, QIODevice::ReadWrite | QIODevice::Unbuffered);
    }

    QEventLoop loop;
    mLoop = &loop;
    ret = loop.exec(QEventLoop::WaitForMoreEvents | QEventLoop::ExcludeUserInputEvents);
    mLoop = nullptr;

    delete mProcess;
    mProcess = nullptr;

    return ret;
}

void Unrar::writeToProcess(const QByteArray &data)
{
    if (!mProcess || data.isNull()) {
        return;
    }

    mProcess->write(data);
}
