#pragma once
#include <QAudioOutput>
#include <QMediaPlayer>
#include <QObject>
#include <QPointer>
#include <QProcess>
#include <QTimer>
#include <QUrl>
#include <QVideoSink>
#include <map>
#include <memory>

// Independent transport/presenter design under SUBSET-CONTRACT13dc8440 /
// review695. No vendor controller, original Main or processing-parity
// implementation.
struct BackendConfig {
  QString cli, cliHash, ffmpeg, ffmpegHash, ffprobe, ffprobeHash, path;
  int inspectionMs = 120000, verificationMs = 30000, termMs = 2000;
};
struct FileIdentity {
  quint64 device = 0, inode = 0, size = 0;
  qint64 seconds = 0, nanos = 0;
  bool operator==(const FileIdentity &) const = default;
};
struct ProcessIdentity {
  qint64 pid = 0, parent = 0, group = 0, session = 0;
  quint64 start = 0;
  char state = 0;
};
class FlowHost : public QObject {
  Q_OBJECT
  Q_PROPERTY(QUrl inputUrl READ inputUrl NOTIFY changed)
  Q_PROPERTY(QUrl outputUrl READ outputUrl NOTIFY changed)
  Q_PROPERTY(bool stitchedDeclared READ stitchedDeclared WRITE
                 setStitchedDeclared NOTIFY changed)
  Q_PROPERTY(bool inputReady READ inputReady NOTIFY changed)
  Q_PROPERTY(bool busy READ busy NOTIFY changed)
  Q_PROPERTY(bool outputCreated READ outputCreated NOTIFY changed)
  Q_PROPERTY(bool outputReady READ outputReady NOTIFY changed)
  Q_PROPERTY(bool previewReady READ previewReady NOTIFY changed)
  Q_PROPERTY(QString jobId READ jobId NOTIFY changed)
  Q_PROPERTY(QString phase READ phase NOTIFY changed)
  Q_PROPERTY(QString metadataOutcome READ metadataOutcome NOTIFY changed)
  Q_PROPERTY(QString previewState READ previewState NOTIFY changed)
  Q_PROPERTY(QString metadataText READ metadataText NOTIFY changed)
  Q_PROPERTY(QString diagnosticText READ diagnosticText NOTIFY changed)
  Q_PROPERTY(QString failureText READ failureText NOTIFY changed)
public:
  explicit FlowHost(BackendConfig config, QObject *parent = nullptr);
  QUrl inputUrl() const { return m_input; }
  QUrl outputUrl() const { return m_output; }
  bool stitchedDeclared() const { return m_declared; }
  bool inputReady() const { return m_inputReady; }
  bool busy() const { return m_busy; }
  bool outputCreated() const { return m_created; }
  bool outputReady() const { return m_ready; }
  bool previewReady() const { return m_previewReady; }
  QString jobId() const;
  QString phase() const { return m_phase; }
  QString metadataOutcome() const { return m_metadataOutcome; }
  QString previewState() const { return m_previewState; }
  QString metadataText() const { return m_metadataText; }
  QString diagnosticText() const { return m_diagnosticText; }
  QString failureText() const { return m_failure; }
  void setStitchedDeclared(bool value);
  Q_INVOKABLE bool selectInput(QUrl url);
  Q_INVOKABLE bool chooseOutput(QUrl url);
  Q_INVOKABLE bool inspectDirectMetadata();
  Q_INVOKABLE bool exportDefaultView();
  Q_INVOKABLE bool openOutputFolder();
  Q_INVOKABLE bool requestClose();
  Q_INVOKABLE void attachPresenter(QObject *player, QObject *sink,
                                   QObject *audio, QString token);
  Q_INVOKABLE void playPause();
  static bool localPath(const QUrl &, QString &, QString &);
  static bool regularIdentity(const QString &, FileIdentity &);
  static bool entryExists(const QString &);
  static QString hashFile(const QString &);
signals:
  void changed();
  void clearPresenter();
  void verifyOutput(QUrl source, QString token);
  void
  audit(QString event); // Real state/ownership events, also used by validation.
private:
  struct Job {
    QString token, input, output;
    FileIdentity inputIdentity, outputIdentity;
    bool render = false, directDone = false, failed = false, cleanup = false;
    bool leaderCaptured = false, termSent = false, killStage = false;
    qint64 pid = 0;
    ProcessIdentity leader;
    std::map<qint64, ProcessIdentity> members;
    QPointer<QProcess> process;
    QByteArray out, err;
    quint64 droppedOut = 0, droppedErr = 0;
    QPointer<QTimer> deadline, watch, escalation;
  };
  BackendConfig m_config;
  std::shared_ptr<Job> m_job;
  QUrl m_input, m_output;
  bool m_declared = false, m_inputReady = false, m_busy = false;
  bool m_created = false, m_ready = false, m_previewReady = false;
  QString m_phase = "idle", m_metadataOutcome = "not inspected";
  QString m_previewState = "empty", m_metadataText, m_diagnosticText, m_failure;
  QPointer<QMediaPlayer> m_player;
  QPointer<QVideoSink> m_sink;
  QPointer<QAudioOutput> m_audio;
  QTimer m_displayTimer;
  bool reject(QString message);
  bool validateOutput(QString &path);
  bool backendValid(QString &error);
  bool submit(bool render);
  bool current(const std::shared_ptr<Job> &job);
  void drain(const std::shared_ptr<Job> &job, bool errorChannel);
  void publishTails();
  void fail(const std::shared_ptr<Job> &job, QString error);
  void settle(const std::shared_ptr<Job> &job);
  bool members(const std::shared_ptr<Job> &job, QList<ProcessIdentity> &live);
  bool signalMembers(const std::shared_ptr<Job> &job,
                     const QList<ProcessIdentity> &, int signal);
  void cleanup(const std::shared_ptr<Job> &job);
  void terminal(const std::shared_ptr<Job> &job);
  void resetPreview();
  void previewFailed(const std::shared_ptr<Job> &, QString);
};
