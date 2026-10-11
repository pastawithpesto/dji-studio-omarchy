#include "FlowHost.h"
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQmlApplicationEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

class FlowTests : public QObject {
  Q_OBJECT
  QTemporaryDir temp;
  BackendConfig real, mock;
  QString mockFile;
  QUrl folderRequest;
public slots:
  void recordFolder(QUrl url) { folderRequest = url; }

private:
  QString input(QString mode) {
    QString path = temp.path() + "/input ü space " + mode + ".mkv";
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly))
      qFatal("fixture creation failed");
    f.write(mode.toUtf8());
    return path;
  }
private slots:
  void initTestCase() {
    QVERIFY(temp.isValid());
    QDir bundle(qEnvironmentVariable("TEST_BUNDLE"));
    QFile f(bundle.filePath("backend.json"));
    QVERIFY(f.open(QIODevice::ReadOnly));
    auto config = QJsonDocument::fromJson(f.readAll()).object();
    real = {bundle.filePath("dji-reframe"), config["cli_sha256"].toString(),
            config["ffmpeg"].toString(),    config["ffmpeg_sha256"].toString(),
            config["ffprobe"].toString(),   config["ffprobe_sha256"].toString(),
            bundle.filePath("backend-bin")};
    mockFile = temp.path() + "/mock-cli";
    QVERIFY(QFile::copy(qEnvironmentVariable("TEST_MOCK"), mockFile));
    QVERIFY(QFile::setPermissions(
        mockFile, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner));
    mock = real;
    mock.cli = mockFile;
    mock.cliHash = FlowHost::hashFile(mockFile);
  }
  void strictPathsAndDirectoryEntries() {
    FlowHost host(mock);
    QString path, error;
    QVERIFY(
        !FlowHost::localPath(QUrl("https://example.invalid/a"), path, error));
    QVERIFY(!FlowHost::localPath(QUrl("file://remote/a"), path, error));
    QVERIFY(!FlowHost::localPath(QUrl("file:///a?b"), path, error));
    QVERIFY(!FlowHost::localPath(QUrl("file:///a#b"), path, error));
    QVERIFY(!FlowHost::localPath(QUrl::fromEncoded("file:///tmp/%FF"), path,
                                 error));
    QVERIFY(!FlowHost::localPath(
        QUrl::fromLocalFile(QString("/tmp/a") + QChar(0)), path, error));
    QVERIFY(!FlowHost::localPath(QUrl::fromLocalFile("/" + QString(33000, 'x')),
                                 path, error));
    QVERIFY(host.selectInput(QUrl::fromLocalFile(input("ordinary"))));
    QString dangling = temp.path() + "/dangling.mp4";
    QVERIFY(QFile::link(temp.path() + "/missing", dangling));
    QVERIFY(FlowHost::entryExists(dangling));
    QVERIFY(!host.chooseOutput(QUrl::fromLocalFile(dangling)));
    QVERIFY(
        !host.chooseOutput(QUrl::fromLocalFile(temp.path() + "/wrong.avi")));
    QVERIFY(host.chooseOutput(
        QUrl::fromLocalFile(temp.path() + "/new ü space.mp4")));
    QVERIFY(!host.exportDefaultView());
    QVERIFY(!host.outputReady());
  }
  void embeddedResourceIdentities() {
    QCOMPARE(FlowHost::hashFile(":/native/resource-manifest.json"),
             QString("443a67dc71ef6a07df4619a52507b1491267eaab3b999ba5f6b19dca5"
                     "e2f1b98"));
    QFile manifest(":/native/resource-manifest.json");
    QVERIFY(manifest.open(QIODevice::ReadOnly));
    const auto records = QJsonDocument::fromJson(manifest.readAll())
                             .object()["records"]
                             .toArray();
    QCOMPARE(records.size(), 1463);
    for (const auto &value : records) {
      const auto row = value.toObject();
      QCOMPARE(FlowHost::hashFile(":" + row["alias"].toString()),
               row["sha256"].toString());
    }
  }
  void outputAndExecutableRevalidation() {
    FlowHost host(mock);
    const QString source = input("ordinary");
    QVERIFY(host.selectInput(QUrl::fromLocalFile(source)));
    const QString output = temp.path() + "/claimed.mp4";
    QVERIFY(host.chooseOutput(QUrl::fromLocalFile(output)));
    host.setStitchedDeclared(true);
    QFile file(output);
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.write("other owner");
    file.close();
    QVERIFY(!host.exportDefaultView());
    QVERIFY(!host.busy());
    QVERIFY(host.failureText().contains("exists"));
    QFile tool(mockFile);
    QVERIFY(tool.open(QIODevice::Append));
    tool.write("\n# changed after pin\n");
    tool.close();
    QVERIFY(!host.inspectDirectMetadata());
    QVERIFY(!host.busy());
    QVERIFY(host.failureText().contains("Pinned executable"));
    // Restore only this test's own injected executable, not any installed tool.
    QVERIFY(tool.open(QIODevice::ReadWrite));
    QVERIFY(tool.resize(tool.size() -
                        QByteArray("\n# changed after pin\n").size()));
    tool.close();
  }
  void boundedDiagnosticDrainage() {
    FlowHost host(mock);
    QSignalSpy audit(&host, &FlowHost::audit);
    QVERIFY(host.selectInput(QUrl::fromLocalFile(input("flood"))));
    QVERIFY(host.inspectDirectMetadata());
    QVERIFY(!host.inspectDirectMetadata());
    QVERIFY(!host.requestClose());
    QTRY_VERIFY_WITH_TIMEOUT(!host.busy(), 10000);
    QCOMPARE(host.phase(), QString("succeeded"));
    QVERIFY(host.metadataText().toUtf8().size() <= 65536);
    QVERIFY(host.diagnosticText().toUtf8().size() <= 65536);
    QVERIFY(host.metadataText().contains("OUTTAIL"));
    QVERIFY(host.diagnosticText().contains("ERRTAIL"));
    QVERIFY(host.metadataText().contains("truncated"));
    QVERIFY(host.diagnosticText().contains(QChar::ReplacementCharacter));
    QVERIFY(host.requestClose());
    QVERIFY(audit.count() > 0);
  }
  void actualFailureOutcomes_data() {
    QTest::addColumn<QString>("mode");
    QTest::newRow("normal-nonzero") << QString("nonzero");
    QTest::newRow("actual-sigkill") << QString("crash");
    QTest::newRow("actual-ENOSPC-device") << QString("disk-full");
  }
  void actualFailureOutcomes() {
    QFETCH(QString, mode);
    FlowHost host(mock);
    QVERIFY(host.selectInput(QUrl::fromLocalFile(input(mode))));
    QVERIFY(host.inspectDirectMetadata());
    QTRY_VERIFY_WITH_TIMEOUT(!host.busy(), 10000);
    QCOMPARE(host.phase(), QString("failed"));
    QVERIFY(!host.outputReady());
    QVERIFY(!host.failureText().isEmpty());
    if (mode == "disk-full")
      QVERIFY(host.diagnosticText().contains("No space left"));
    if (mode == "crash")
      QVERIFY(host.failureText().contains("Crash") ||
              host.failureText().contains("crash"));
  }
  void failedStartAndMissingBackend() {
    BackendConfig missing = mock;
    missing.cli = temp.path() + "/absent";
    FlowHost host(missing);
    QVERIFY(host.selectInput(QUrl::fromLocalFile(input("ordinary"))));
    QVERIFY(!host.inspectDirectMetadata());
    QString invalid = temp.path() + "/invalid-executable";
    QFile f(invalid);
    QVERIFY(f.open(QIODevice::WriteOnly));
    f.write("not an executable");
    f.close();
    QVERIFY(QFile::setPermissions(invalid, QFile::ReadOwner | QFile::ExeOwner));
    BackendConfig bad = mock;
    bad.cli = invalid;
    bad.cliHash = FlowHost::hashFile(invalid);
    FlowHost invalidHost(bad);
    QVERIFY(invalidHost.selectInput(QUrl::fromLocalFile(input("ordinary"))));
    QVERIFY(invalidHost.inspectDirectMetadata());
    QTRY_VERIFY_WITH_TIMEOUT(!invalidHost.busy(), 10000);
    QCOMPARE(invalidHost.phase(), QString("failed"));
    QVERIFY(invalidHost.failureText().contains("Process error"));
  }
  void ownedCleanupDeadlineAndCrash_data() {
    QTest::addColumn<QString>("mode");
    QTest::newRow("deadline") << QString("timeout");
    QTest::newRow("crashed-parent") << QString("crash-child");
  }
  void ownedCleanupDeadlineAndCrash() {
    QFETCH(QString, mode);
    BackendConfig config = mock;
    config.inspectionMs = mode == "timeout" ? 500 : 4000;
    FlowHost host(config);
    QSignalSpy audit(&host, &FlowHost::audit);
    QVERIFY(host.selectInput(QUrl::fromLocalFile(input(mode))));
    QElapsedTimer cleanupClock;
    cleanupClock.start();
    QVERIFY(host.inspectDirectMetadata());
    QVERIFY(!host.requestClose());
    QTRY_VERIFY_WITH_TIMEOUT(!host.busy(), 15000);
    QCOMPARE(host.phase(), QString("failed"));
    bool term = false, kill = false, member = false;
    for (const auto &event : audit) {
      QString text = event[0].toString();
      qInfo().noquote() << "Owned cleanup evidence:" << text;
      term |= text.contains("signal=15");
      kill |= text.contains("signal=9");
      member |= text.contains("owned member");
    }
    QVERIFY(member);
    QVERIFY(term);
    QVERIFY(kill);
    QVERIFY(cleanupClock.elapsed() >= config.termMs);
    QVERIFY(host.requestClose());
    QVERIFY(host.metadataText().contains("child="));
    QString child =
        host.metadataText().section("child=", 1).section('\n', 0, 0).trimmed();
    QFile stat("/proc/" + child + "/stat");
    if (stat.open(QIODevice::ReadOnly)) {
      auto b = stat.readAll();
      QVERIFY(b.mid(b.lastIndexOf(')') + 2, 1) == "Z");
    }
  }
  void corruptOutputAndVerificationDeadline() {
    BackendConfig config = mock;
    config.verificationMs = 250;
    FlowHost host(config);
    QVERIFY(host.selectInput(QUrl::fromLocalFile(input("ordinary"))));
    QVERIFY(
        host.chooseOutput(QUrl::fromLocalFile(temp.path() + "/corrupt.mp4")));
    host.setStitchedDeclared(true);
    QVERIFY(host.exportDefaultView());
    QTRY_COMPARE_WITH_TIMEOUT(host.phase(), QString("checking"), 10000);
    QVERIFY(host.outputCreated());
    QVERIFY(!host.outputReady());
    QVERIFY(!host.requestClose());
    QTRY_VERIFY_WITH_TIMEOUT(!host.busy(), 10000);
    QCOMPARE(host.phase(), QString("failed"));
    QVERIFY(host.outputCreated());
    QVERIFY(host.selectInput(QUrl::fromLocalFile(input("ordinary"))));
    QMediaPlayer old;
    QVideoSink oldSink;
    QAudioOutput oldAudio;
    host.attachPresenter(&old, &oldSink, &oldAudio, "old-generation");
    QVERIFY(!host.outputReady());
    QCOMPARE(host.phase(), QString("idle"));
  }
  void actualCorruptMediaError() {
    FlowHost host(mock);
    QMediaPlayer player;
    QVideoSink sink;
    QAudioOutput audio;
    QSignalSpy errors(&player, &QMediaPlayer::errorOccurred);
    connect(&host, &FlowHost::verifyOutput, &host, [&](QUrl, QString token) {
      host.attachPresenter(&player, &sink, &audio, token);
    });
    QVERIFY(host.selectInput(QUrl::fromLocalFile(input("ordinary"))));
    QVERIFY(host.chooseOutput(
        QUrl::fromLocalFile(temp.path() + "/invalid-media.mp4")));
    host.setStitchedDeclared(true);
    QVERIFY(host.exportDefaultView());
    QTRY_VERIFY_WITH_TIMEOUT(!host.busy(), 10000);
    QVERIFY(errors.count() > 0);
    QCOMPARE(host.phase(), QString("failed"));
    QVERIFY(host.outputCreated());
    QVERIFY(!host.outputReady());
    QVERIFY(host.failureText().contains("Actual multimedia"));
    const QString stale = host.jobId();
    QVERIFY(host.selectInput(QUrl::fromLocalFile(input("ordinary"))));
    // A genuinely queued stale callback from the previous source generation.
    QTimer::singleShot(
        0, &host, [&] { host.attachPresenter(&player, &sink, &audio, stale); });
    QTest::qWait(50);
    QCOMPARE(host.phase(), QString("idle"));
    QVERIFY(!host.outputReady());
  }
  void actualWrongFrameDimensions() {
    FlowHost host(mock);
    QMediaPlayer player;
    QVideoSink sink;
    QAudioOutput audio;
    connect(&host, &FlowHost::verifyOutput, &host, [&](QUrl, QString token) {
      host.attachPresenter(&player, &sink, &audio, token);
    });
    QVERIFY(host.selectInput(QUrl::fromLocalFile(input("wrong-dimension"))));
    QVERIFY(host.chooseOutput(
        QUrl::fromLocalFile(temp.path() + "/small-frame.mp4")));
    host.setStitchedDeclared(true);
    QVERIFY(host.exportDefaultView());
    QTRY_VERIFY_WITH_TIMEOUT(!host.busy(), 10000);
    QVERIFY(host.outputCreated());
    QVERIFY(!host.outputReady());
    QVERIFY(host.failureText().contains("dimensions"));
  }
  void ordinaryInputIdentityChange() {
    FlowHost host(mock);
    QVERIFY(host.selectInput(QUrl::fromLocalFile(input("identity-change"))));
    QVERIFY(host.inspectDirectMetadata());
    QTRY_VERIFY_WITH_TIMEOUT(!host.busy(), 10000);
    QCOMPARE(host.phase(), QString("failed"));
    QVERIFY(host.failureText().contains("Input identity changed"));
    QVERIFY(!host.outputReady());
  }
  void realMetadataFixtures() {
    FlowHost host(real);
    QVERIFY(host.selectInput(
        QUrl::fromLocalFile(qEnvironmentVariable("TEST_MEDIA"))));
    QVERIFY(host.inspectDirectMetadata());
    QTRY_VERIFY_WITH_TIMEOUT(!host.busy(), 20000);
    QCOMPARE(host.phase(), QString("succeeded"));
    QVERIFY(!host.stitchedDeclared());
    QVERIFY(!host.outputReady());
    QVERIFY(!host.metadataText().isEmpty());
    QString project = qEnvironmentVariable("TEST_PROJECT");
    QVERIFY(host.selectInput(QUrl::fromLocalFile(
        project + "/tests/fixtures/demux/one-djmd-oqb101.mp4")));
    QVERIFY(host.inspectDirectMetadata());
    QTRY_VERIFY_WITH_TIMEOUT(!host.busy(), 20000);
    QCOMPARE(host.phase(), QString("succeeded"));
    QVERIFY(host.metadataText().contains("oqb101"));
    QVERIFY(host.selectInput(QUrl::fromLocalFile(
        project + "/tests/fixtures/demux/unknown-encoder-djmd.mp4")));
    QVERIFY(host.inspectDirectMetadata());
    QTRY_VERIFY_WITH_TIMEOUT(!host.busy(), 20000);
    QVERIFY(!host.outputReady());
    QVERIFY(host.metadataText().contains("unsupported") ||
            host.diagnosticText().contains("unsupported") ||
            host.phase() == "failed");
  }
  void realRenderFrameAndPlayback() {
    FlowHost host(real);
    QMediaPlayer player;
    QVideoSink sink;
    QAudioOutput audio;
    connect(&host, &FlowHost::verifyOutput, &host, [&](QUrl, QString token) {
      host.attachPresenter(&player, &sink, &audio, token);
    });
    QVERIFY(host.selectInput(
        QUrl::fromLocalFile(qEnvironmentVariable("TEST_MEDIA"))));
    QVERIFY(host.chooseOutput(
        QUrl::fromLocalFile(qEnvironmentVariable("TEST_OUTPUT"))));
    host.setStitchedDeclared(true);
    QVERIFY(host.exportDefaultView());
    QVERIFY(!host.requestClose());
    QTRY_VERIFY_WITH_TIMEOUT(!host.busy(), 60000);
    QVERIFY2(host.outputReady(), qPrintable(host.failureText()));
    QVERIFY(host.outputCreated());
    QVERIFY(host.previewReady());
    QCOMPARE(player.videoSink(), &sink);
    QCOMPARE(player.playbackState(), QMediaPlayer::PausedState);
    host.playPause();
    QTRY_COMPARE(player.playbackState(), QMediaPlayer::PlayingState);
    QVERIFY(!audio.isMuted());
    host.playPause();
    QTRY_COMPARE(player.playbackState(), QMediaPlayer::PausedState);
    QDesktopServices::setUrlHandler("file", this, "recordFolder");
    QVERIFY(host.openOutputFolder());
    QDesktopServices::unsetUrlHandler("file");
    QCOMPARE(
        folderRequest,
        QUrl::fromLocalFile(
            QFileInfo(qEnvironmentVariable("TEST_OUTPUT")).absolutePath()));
    if (qEnvironmentVariableIsSet("TEST_REAL_FOLDER_LAUNCH"))
      QVERIFY(
          host.openOutputFolder()); // Observer separately checks appearance.
    QVERIFY(host.requestClose());
    QVERIFY(!host.previewReady());
  }
  void qmlVisibleOriginalControls() {
    FlowHost host(real);
    qmlRegisterSingletonInstance("NativeStitchedFlow", 1, 0, "Flow", &host);
    qmlRegisterType(QUrl("qrc:/native/recovered/LightTextButton.qml"),
                    "RecoveredFlowControls", 1, 0, "LightTextButton");
    qmlRegisterType(QUrl("qrc:/native/recovered/ImageButton.qml"),
                    "RecoveredFlowControls", 1, 0, "ImageButton");
    for (const char *name : {"Colors", "ColorsConfig", "RadiusConfig"})
      qmlRegisterSingletonType(
          QUrl(QString("qrc:/native/recovered/%1.qml").arg(name)),
          "RecoveredFlowPalette", 1, 0, name);
    QQmlApplicationEngine engine;
    engine.load(QUrl("qrc:/native/NativeStitchedFlow.qml"));
    QVERIFY(!engine.rootObjects().isEmpty());
    auto window = qobject_cast<QQuickWindow *>(engine.rootObjects()[0]);
    QVERIFY(window);
    // A tiling compositor may override minimum sizes. Affect only this window.
    if (QGuiApplication::platformName() == "wayland") {
      window->showFullScreen();
      QTRY_VERIFY(window->width() >= 780 && window->height() >= 640);
    }
    QTRY_VERIFY(window->isVisible());
    auto metadata = window->findChild<QQuickItem *>("metadataButton");
    auto select = window->findChild<QQuickItem *>("selectInputButton");
    auto play = window->findChild<QQuickItem *>("playButton");
    QVERIFY(metadata && select && play);
    QVERIFY(!metadata->isEnabled());
    QVERIFY(!play->isEnabled());
    QVERIFY(select->isEnabled());
    QVERIFY(host.selectInput(
        QUrl::fromLocalFile(qEnvironmentVariable("TEST_MEDIA"))));
    QTRY_VERIFY(metadata->isEnabled());
    QVERIFY(host.failureText().isEmpty());
    QPoint point =
        metadata
            ->mapToScene(QPointF(metadata->width() / 2, metadata->height() / 2))
            .toPoint();
    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, point);
    QTRY_VERIFY(host.busy());
    QTRY_VERIFY(!metadata->isEnabled());
    QVERIFY(!window->close());
    QTRY_VERIFY_WITH_TIMEOUT(!host.busy(), 20000);
    QTRY_VERIFY(metadata->isEnabled());
    select->forceActiveFocus();
    QTRY_VERIFY(select->hasActiveFocus());
    QImage image = window->grabWindow();
    QVERIFY(!image.isNull());
    QVERIFY(image.save(qEnvironmentVariable("TEST_SCREENSHOT")));
    // Exercise the actual wrapper's fresh MediaPlayer/VideoOutput generation.
    QVERIFY(host.chooseOutput(
        QUrl::fromLocalFile(qEnvironmentVariable("TEST_OUTPUT") + ".qml.mp4")));
    host.setStitchedDeclared(true);
    auto render = window->findChild<QQuickItem *>("renderButton");
    QVERIFY(render && render->isEnabled());
    point =
        render->mapToScene(QPointF(render->width() / 2, render->height() / 2))
            .toPoint();
    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, point);
    QTRY_VERIFY_WITH_TIMEOUT(host.outputReady(), 60000);
    QTRY_VERIFY(play->isEnabled());
    point = play->mapToScene(QPointF(play->width() / 2, play->height() / 2))
                .toPoint();
    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, point);
    QTRY_COMPARE(host.previewState(), QString("playing"));
    QCOMPARE(play->property("text").toString(), QString("Pause"));
    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, point);
    QTRY_COMPARE(host.previewState(), QString("paused"));
    QTest::qWait(250); // Allow the presented frame to reach the scene graph.
    const QImage rendered = window->grabWindow();
    QVERIFY(
        rendered.save(qEnvironmentVariable("TEST_SCREENSHOT") + ".render.png"));
    if (QGuiApplication::platformName() == "wayland") {
      auto container = window->findChild<QQuickItem *>("videoContainer");
      QVERIFY(container);
      const QPoint center = container
                                ->mapToScene(QPointF(container->width() / 2,
                                                     container->height() / 2))
                                .toPoint() *
                            window->devicePixelRatio();
      const QColor pixel = rendered.pixelColor(center);
      // Independent coordinate-gradient fixture center, not a screenshot
      // oracle.
      QVERIFY2(qAbs(pixel.red() - 128) <= 10 &&
                   qAbs(pixel.green() - 128) <= 10 &&
                   qAbs(pixel.blue() - 128) <= 10,
               qPrintable(QString("Visible preview center RGB %1,%2,%3")
                              .arg(pixel.red())
                              .arg(pixel.green())
                              .arg(pixel.blue())));
    }
    QVERIFY(window->close());
  }
};
QTEST_MAIN(FlowTests)
#include "FlowTests.moc"
