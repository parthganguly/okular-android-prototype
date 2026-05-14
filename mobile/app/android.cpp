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

void Java_org_kde_something_FileClass_openUri(JNIEnv *env, jobject /*obj*/, jstring uri)
{
    jboolean isCopy = false;
    const char *utf = env->GetStringUTFChars(uri, &isCopy);
    const QString uriString = QString::fromUtf8(utf);
    URIHandler::handler.openUri(uriString);
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
