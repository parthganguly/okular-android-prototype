/*
    SPDX-FileCopyrightText: 2018 Aleix Pol <aleixpol@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "android.h"

#include <QCoreApplication>
#include <QJniEnvironment>
#include <QJniObject>
#include <QMetaObject>
#include <QStringList>

URIHandler URIHandler::handler;

void URIHandler::handleViewIntent()
{
    QJniObject::callStaticMethod<void>("org/kde/something/FileClass", "handleViewIntent", "()V");
}

void URIHandler::setReaderMode(bool enabled)
{
    QJniObject::callStaticMethod<void>("org/kde/something/FileClass", "setReaderMode", "(Z)V", static_cast<jboolean>(enabled));
}

int URIHandler::statusBarHeight() const
{
    return QJniObject::callStaticMethod<jint>("org/kde/something/FileClass", "statusBarHeight", "()I");
}

int URIHandler::navigationBarHeight() const
{
    return QJniObject::callStaticMethod<jint>("org/kde/something/FileClass", "navigationBarHeight", "()I");
}

void URIHandler::requestAllFilesAccess()
{
    QJniObject::callStaticMethod<void>("org/kde/something/FileClass", "requestAllFilesAccess", "()V");
}

void URIHandler::openLibraryFolder()
{
    QJniObject::callStaticMethod<void>("org/kde/something/FileClass", "openLibraryFolder", "()V");
}

void URIHandler::refreshLibrary()
{
    QJniObject::callStaticMethod<void>("org/kde/something/FileClass", "refreshLibrary", "()V");
}

void URIHandler::openLibraryFolderUri(const QString &uri)
{
    const QJniObject juri = QJniObject::fromString(uri);
    QJniObject::callStaticMethod<void>("org/kde/something/FileClass", "openLibraryFolderUri", "(Ljava/lang/String;)V", juri.object<jstring>());
}

void URIHandler::navigateLibraryUp()
{
    QJniObject::callStaticMethod<void>("org/kde/something/FileClass", "navigateLibraryUp", "()V");
}

void URIHandler::openLibraryDocument(const QString &uri, const QString &mimeType)
{
    const QJniObject juri = QJniObject::fromString(uri);
    const QJniObject jmimeType = QJniObject::fromString(mimeType);
    QJniObject::callStaticMethod<void>("org/kde/something/FileClass", "openLibraryDocument", "(Ljava/lang/String;Ljava/lang/String;)V", juri.object<jstring>(), jmimeType.object<jstring>());
}

void URIHandler::shareCurrentDocument()
{
    QJniObject::callStaticMethod<void>("org/kde/something/FileClass", "shareCurrentDocument", "()V");
}

bool URIHandler::deleteCurrentDocument()
{
    return QJniObject::callStaticMethod<jboolean>("org/kde/something/FileClass", "deleteCurrentDocument", "()Z");
}

void URIHandler::clearCurrentDocument()
{
    QJniObject::callStaticMethod<void>("org/kde/something/FileClass", "clearCurrentDocument", "()V");
}

QString URIHandler::ttsEnginesJson() const
{
    const QJniObject result = QJniObject::callStaticObjectMethod("org/kde/something/FileClass", "ttsEnginesJson", "()Ljava/lang/String;");
    return result.isValid() ? result.toString() : QStringLiteral("[]");
}

QString URIHandler::ttsVoicesJson(const QString &enginePackage) const
{
    const QJniObject jenginePackage = QJniObject::fromString(enginePackage);
    const QJniObject result = QJniObject::callStaticObjectMethod(
        "org/kde/something/FileClass", "ttsVoicesJson", "(Ljava/lang/String;)Ljava/lang/String;", jenginePackage.object<jstring>());
    return result.isValid() ? result.toString() : QStringLiteral("[]");
}

bool URIHandler::ttsUseEngine(const QString &enginePackage)
{
    const QJniObject jenginePackage = QJniObject::fromString(enginePackage);
    return QJniObject::callStaticMethod<jboolean>(
        "org/kde/something/FileClass", "ttsUseEngine", "(Ljava/lang/String;)Z", jenginePackage.object<jstring>());
}

bool URIHandler::ttsSpeak(const QString &text)
{
    const QJniObject jtext = QJniObject::fromString(text);
    return QJniObject::callStaticMethod<jboolean>("org/kde/something/FileClass", "ttsSpeak", "(Ljava/lang/String;)Z", jtext.object<jstring>());
}

void URIHandler::ttsStop()
{
    QJniObject::callStaticMethod<void>("org/kde/something/FileClass", "ttsStop", "()V");
}

void URIHandler::ttsSetRate(float rate)
{
    QJniObject::callStaticMethod<void>("org/kde/something/FileClass", "ttsSetRate", "(F)V", static_cast<jfloat>(rate));
}

void URIHandler::ttsSetPitch(float pitch)
{
    QJniObject::callStaticMethod<void>("org/kde/something/FileClass", "ttsSetPitch", "(F)V", static_cast<jfloat>(pitch));
}

bool URIHandler::ttsSetVoice(const QString &voiceName)
{
    const QJniObject jvoiceName = QJniObject::fromString(voiceName);
    return QJniObject::callStaticMethod<jboolean>(
        "org/kde/something/FileClass", "ttsSetVoice", "(Ljava/lang/String;)Z", jvoiceName.object<jstring>());
}

QString URIHandler::ttsStateJson() const
{
    const QJniObject result = QJniObject::callStaticObjectMethod("org/kde/something/FileClass", "ttsStateJson", "()Ljava/lang/String;");
    return result.isValid() ? result.toString() : QStringLiteral("{\"state\":\"unavailable\"}");
}

void Java_org_kde_something_FileClass_openUri(JNIEnv *env, jobject /*obj*/, jstring uri)
{
    jboolean isCopy = false;
    const char *utf = env->GetStringUTFChars(uri, &isCopy);
    const QString uriString = QString::fromUtf8(utf);
    QMetaObject::invokeMethod(&URIHandler::handler, [uriString]() {
        URIHandler::handler.openUri(uriString);
    }, Qt::QueuedConnection);
    env->ReleaseStringUTFChars(uri, utf);
}

void Java_org_kde_something_FileClass_updateLibrary(JNIEnv *env, jobject /*obj*/, jstring json)
{
    jboolean isCopy = false;
    const char *utf = env->GetStringUTFChars(json, &isCopy);
    const QString jsonString = QString::fromUtf8(utf);
    QMetaObject::invokeMethod(&URIHandler::handler, [jsonString]() {
        URIHandler::handler.updateLibraryJson(jsonString);
    }, Qt::QueuedConnection);
    env->ReleaseStringUTFChars(json, utf);
}

void Java_org_kde_something_FileClass_closeDocument(JNIEnv *env, jobject /*obj*/)
{
    Q_UNUSED(env);
    QMetaObject::invokeMethod(&URIHandler::handler, []() {
        Q_EMIT URIHandler::handler.closeRequested();
    }, Qt::QueuedConnection);
}
