/*
    SPDX-FileCopyrightText: 2010 Aleix Pol <aleixpol@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include <QApplication>

#include <KLocalizedContext>
#include <KLocalizedString>
#include <QCommandLineParser>
#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlEngine>
#include <QStandardPaths>
#include <QTimer>

#include "aboutdata.h"

#ifdef __ANDROID__
#include "android.h"

Q_DECL_EXPORT
#endif
int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("okularkirigami"));

    KLocalizedString::setApplicationDomain("org.kde.active.documentviewer");

    KAboutData aboutData = okularAboutData();
    aboutData.setDisplayName(i18n("Parthicle Reader"));
    aboutData.setShortDescription(i18n("The MX Player for reading files. Based on Okular/KDE."));
    aboutData.setOtherText(i18n("Parthicle Reader is an independent fork/prototype based on Okular, the open-source document viewer developed by the KDE community. It is not affiliated with, sponsored by, or endorsed by KDE e.V."));
    KAboutData::setApplicationData(aboutData);

    QApplication::setWindowIcon(QIcon::fromTheme(QStringLiteral("application-pdf")));

    QCommandLineParser parser;
    // parser.setApplicationDescription(i18n("Parthicle Reader"));
    aboutData.setupCommandLine(&parser);
    parser.process(app);
    aboutData.processCommandLine(&parser);
    QQmlApplicationEngine engine;

#ifdef __ANDROID__
    URIHandler::handleViewIntent();
    const QString uri = URIHandler::handler.lastUrl();
#else
    const QString uri = parser.positionalArguments().count() == 1 ? QUrl::fromUserInput(parser.positionalArguments().constFirst(), {}, QUrl::AssumeLocalFile).toString() : QString();
#endif
    // TODO move away from context property when possible
    engine.rootContext()->setContextObject(new KLocalizedContext(&engine));
#ifdef __ANDROID__
    engine.rootContext()->setContextProperty(QStringLiteral("uriHandler"), &URIHandler::handler);
#endif
    engine.rootContext()->setContextProperty(QStringLiteral("uri"), uri);

    engine.loadFromModule(QLatin1StringView("org.kde.okular.app"), QLatin1StringView("Main"));
    return app.exec();
}
