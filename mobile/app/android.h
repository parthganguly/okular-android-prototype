/*
    SPDX-FileCopyrightText: 2018 Aleix Pol <aleixpol@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#ifndef ANDROID_H
#define ANDROID_H

#include <QObject>
#include <QString>
#include <jni.h>

class URIHandler : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString lastUrl READ lastUrl NOTIFY lastUrlChanged)
    Q_PROPERTY(QString libraryJson READ libraryJson NOTIFY libraryJsonChanged)

public:
    explicit URIHandler(QObject *parent = nullptr)
        : QObject(parent)
    {
    }

    void openUri(const QString &uri)
    {
        if (m_lastUrl != uri) {
            m_lastUrl = uri;
            Q_EMIT lastUrlChanged();
        }
        Q_EMIT openRequested(uri);
    }

    QString lastUrl() const
    {
        return m_lastUrl;
    }

    QString libraryJson() const
    {
        return m_libraryJson;
    }

    Q_INVOKABLE void setReaderMode(bool enabled);
    Q_INVOKABLE int statusBarHeight() const;
    Q_INVOKABLE int navigationBarHeight() const;
    Q_INVOKABLE void requestAllFilesAccess();
    Q_INVOKABLE void openLibraryFolder();
    Q_INVOKABLE void refreshLibrary();
    Q_INVOKABLE void openLibraryFolderUri(const QString &uri);
    Q_INVOKABLE void navigateLibraryUp();
    Q_INVOKABLE void openLibraryDocument(const QString &uri, const QString &mimeType);

    void updateLibraryJson(const QString &json)
    {
        if (m_libraryJson == json) {
            return;
        }

        m_libraryJson = json;
        Q_EMIT libraryJsonChanged();
    }

    static void handleViewIntent();

    static URIHandler handler;

Q_SIGNALS:
    void lastUrlChanged();
    void libraryJsonChanged();
    void openRequested(const QString &uri);

private:
    QString m_lastUrl;
    QString m_libraryJson;
};

extern "C" {
JNIEXPORT void JNICALL Java_org_kde_something_FileClass_openUri(JNIEnv *env, jobject /*obj*/, jstring uri);
JNIEXPORT void JNICALL Java_org_kde_something_FileClass_updateLibrary(JNIEnv *env, jobject /*obj*/, jstring json);
}

#endif
