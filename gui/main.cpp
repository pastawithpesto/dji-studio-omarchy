#include "FlowHost.h"
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQmlApplicationEngine>
#include <QQmlEngine>

int main(int argc, char **argv) {
  QGuiApplication app(argc, argv);
  app.setApplicationName("native-stitched-flow");
  if (FlowHost::hashFile(":/native/resource-manifest.json") !=
      "443a67dc71ef6a07df4619a52507b1491267eaab3b999ba5f6b19dca5e2f1b98")
    return 2;
  QFile provenance(":/native/resource-manifest.json");
  if (!provenance.open(QIODevice::ReadOnly))
    return 2;
  const QJsonObject resources =
      QJsonDocument::fromJson(provenance.readAll()).object();
  for (const QJsonValue &value : resources["records"].toArray()) {
    QJsonObject row = value.toObject();
    if (FlowHost::hashFile(":" + row["alias"].toString()) !=
        row["sha256"].toString()) {
      qCritical() << "Resource identity mismatch" << row["alias"];
      return 2;
    }
  }
  QFile manifest(QCoreApplication::applicationDirPath() + "/backend.json");
  if (!manifest.open(QIODevice::ReadOnly)) {
    qCritical() << "Build/package with gui/build.py first";
    return 2;
  }
  QJsonObject config = QJsonDocument::fromJson(manifest.readAll()).object();
  QDir bundle(QCoreApplication::applicationDirPath());
  BackendConfig backend{bundle.absoluteFilePath("dji-reframe"),
                        config["cli_sha256"].toString(),
                        config["ffmpeg"].toString(),
                        config["ffmpeg_sha256"].toString(),
                        config["ffprobe"].toString(),
                        config["ffprobe_sha256"].toString(),
                        bundle.absoluteFilePath("backend-bin")};
  FlowHost flow(backend);
  QObject::connect(&flow, &FlowHost::audit, &app,
                   [](const QString &event) { qInfo().noquote() << event; });
  qmlRegisterSingletonInstance("NativeStitchedFlow", 1, 0, "Flow", &flow);
  qmlRegisterType(QUrl("qrc:/native/recovered/LightTextButton.qml"),
                  "RecoveredFlowControls", 1, 0, "LightTextButton");
  qmlRegisterType(QUrl("qrc:/native/recovered/ImageButton.qml"),
                  "RecoveredFlowControls", 1, 0, "ImageButton");
  for (const char *name : {"Colors", "ColorsConfig", "RadiusConfig"})
    qmlRegisterSingletonType(
        QUrl(QString("qrc:/native/recovered/%1.qml").arg(name)),
        "RecoveredFlowPalette", 1, 0, name);
  QQmlApplicationEngine engine;
  QObject::connect(
      &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
      [] { QCoreApplication::exit(3); }, Qt::QueuedConnection);
  engine.load(QUrl("qrc:/native/NativeStitchedFlow.qml"));
  return app.exec();
}
