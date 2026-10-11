#include "FlowHost.h"
#include <QCryptographicHash>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QUuid>
#include <QVideoFrame>
#include <cerrno>
#include <signal.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <unistd.h>

namespace {
constexpr qsizetype Cap = 65536, Chunk = 4096, Quantum = 262144;
QString display(const QByteArray &tail, quint64 dropped) {
  QString prefix = dropped
                       ? QString("[truncated: %1 bytes dropped]\n").arg(dropped)
                       : QString();
  QByteArray text = QString::fromUtf8(tail).toUtf8();
  const qsizetype available = Cap - prefix.toUtf8().size();
  if (text.size() > available) {
    text = text.right(available);
    prefix = "[truncated UTF-8 display]\n";
  }
  QString result = prefix + QString::fromUtf8(text);
  while (result.toUtf8().size() > Cap)
    result.remove(prefix.size(), 1);
  return result;
}
void retain(QByteArray &tail, quint64 &dropped, const QByteArray &bytes) {
  tail.append(bytes);
  if (tail.size() > Cap) {
    dropped += quint64(tail.size() - Cap);
    tail.remove(0, tail.size() - Cap);
  }
}
bool proc(qint64 pid, ProcessIdentity &p) {
  QFile f(QString("/proc/%1/stat").arg(pid));
  if (!f.open(QIODevice::ReadOnly))
    return false;
  QByteArray b = f.read(4096);
  int pos = b.lastIndexOf(')');
  if (pos < 0)
    return false;
  QList<QByteArray> fields = b.mid(pos + 2).simplified().split(' ');
  if (fields.size() < 20)
    return false;
  bool ok = false;
  p.pid = pid;
  p.state = fields[0][0];
  p.parent = fields[1].toLongLong();
  p.group = fields[2].toLongLong();
  p.session = fields[3].toLongLong();
  p.start = fields[19].toULongLong(&ok);
  return ok;
}
bool same(const ProcessIdentity &a, const ProcessIdentity &b) {
  return a.pid == b.pid && a.start == b.start && a.group == b.group &&
         a.session == b.session;
}
} // namespace

FlowHost::FlowHost(BackendConfig config, QObject *parent)
    : QObject(parent), m_config(std::move(config)) {
  m_displayTimer.setInterval(100);
  connect(&m_displayTimer, &QTimer::timeout, this, &FlowHost::publishTails);
  m_displayTimer.start();
}
QString FlowHost::jobId() const { return m_job ? m_job->token : QString(); }
QString FlowHost::hashFile(const QString &path) {
  QFile f(path);
  if (!f.open(QIODevice::ReadOnly))
    return {};
  QCryptographicHash hash(QCryptographicHash::Sha256);
  if (!hash.addData(&f))
    return {};
  return QString::fromLatin1(hash.result().toHex());
}
bool FlowHost::localPath(const QUrl &url, QString &path, QString &error) {
  if (!url.isValid() || url.scheme() != "file" || !url.host().isEmpty() ||
      url.hasQuery() || url.hasFragment()) {
    error = "Use an absolute local file URL without host, query or fragment";
    return false;
  }
  path = url.toLocalFile();
  const QByteArray bytes = QFile::encodeName(path);
  if (path.contains(QChar(0)) || !QDir::isAbsolutePath(path) ||
      bytes.size() > 32768 || QString::fromUtf8(bytes) != path ||
      QFile::decodeName(bytes) != path ||
      url.path(QUrl::FullyEncoded) !=
          QUrl::fromLocalFile(path).path(QUrl::FullyEncoded)) {
    error =
        "Local path is not lossless, absolute or within the 32768-byte bound";
    return false;
  }
  return true;
}
bool FlowHost::regularIdentity(const QString &path, FileIdentity &identity) {
  struct stat s{};
  QByteArray p = QFile::encodeName(path);
  if (::stat(p.constData(), &s) || !S_ISREG(s.st_mode) ||
      ::access(p.constData(), R_OK))
    return false;
  identity = {quint64(s.st_dev), quint64(s.st_ino), quint64(s.st_size),
              s.st_mtim.tv_sec, s.st_mtim.tv_nsec};
  return true;
}
bool FlowHost::entryExists(const QString &path) {
  struct stat s{};
  return ::lstat(QFile::encodeName(path).constData(), &s) == 0 ||
         errno != ENOENT;
}
bool FlowHost::reject(QString message) {
  m_failure = std::move(message);
  emit changed();
  return false;
}
void FlowHost::resetPreview() {
  QPointer<QMediaPlayer> previous = m_player;
  m_player = nullptr;
  m_sink = nullptr;
  m_audio = nullptr;
  if (previous) {
    previous->stop();
    previous->setSource(QUrl());
  }
  m_ready = false;
  m_previewReady = false;
  m_previewState = "empty";
  emit clearPresenter();
}
bool FlowHost::selectInput(QUrl url) {
  if (m_busy)
    return reject("Operation still running or cleaning up; selection refused");
  QString path, error;
  FileIdentity identity;
  if (!localPath(url, path, error))
    return reject(error);
  if (!regularIdentity(path, identity))
    return reject("Input must be an existing readable regular file");
  resetPreview();
  m_job.reset();
  m_input = QUrl::fromLocalFile(path);
  m_output = QUrl();
  m_declared = false;
  m_inputReady = true;
  m_created = false;
  m_phase = "idle";
  m_metadataOutcome = "not inspected";
  m_metadataText.clear();
  m_diagnosticText.clear();
  m_failure.clear();
  emit changed();
  return true;
}
bool FlowHost::validateOutput(QString &path) {
  QString error;
  if (!localPath(m_output, path, error))
    return reject(error);
  if (!path.endsWith(".mp4", Qt::CaseInsensitive))
    return reject("This flow requires a new .mp4 output");
  if (entryExists(path))
    return reject("Output directory entry already exists (including symlinks)");
  QFileInfo parent(QFileInfo(path).absolutePath());
  if (!parent.isDir() ||
      ::access(QFile::encodeName(parent.absoluteFilePath()).constData(), W_OK))
    return reject("Output parent must exist and be writable");
  if (path == m_input.toLocalFile())
    return reject("Input and output must be distinct");
  return true;
}
bool FlowHost::chooseOutput(QUrl url) {
  if (m_busy)
    return reject(
        "Operation still running or cleaning up; output selection refused");
  const QUrl old = m_output;
  m_output = url;
  QString path;
  if (!validateOutput(path)) {
    m_output = old;
    return false;
  }
  resetPreview();
  m_created = false;
  m_output = QUrl::fromLocalFile(path);
  m_failure.clear();
  emit changed();
  return true;
}
void FlowHost::setStitchedDeclared(bool value) {
  if (m_busy) {
    reject("Declaration cannot change during an owned operation");
    return;
  }
  m_declared = value;
  emit changed();
}
bool FlowHost::backendValid(QString &error) {
  for (const auto &pair : {qMakePair(m_config.cli, m_config.cliHash),
                           qMakePair(m_config.ffmpeg, m_config.ffmpegHash),
                           qMakePair(m_config.ffprobe, m_config.ffprobeHash)}) {
    if (!QDir::isAbsolutePath(pair.first) || pair.second.size() != 64 ||
        hashFile(pair.first) != pair.second ||
        ::access(QFile::encodeName(pair.first).constData(), X_OK)) {
      error =
          "Pinned executable missing, changed or not executable: " + pair.first;
      return false;
    }
  }
  for (const QString &name : {QString("ffmpeg"), QString("ffprobe")}) {
    QString expected = name == "ffmpeg" ? m_config.ffmpeg : m_config.ffprobe;
    if (QFileInfo(m_config.path + "/" + name).canonicalFilePath() !=
        QFileInfo(expected).canonicalFilePath()) {
      error = "Controlled PATH does not resolve the pinned backend: " + name;
      return false;
    }
  }
  // The unchanged CLI's direct inspector uses this absolute path, not PATH.
  if (QFileInfo(m_config.ffprobe).canonicalFilePath() !=
      QFileInfo("/usr/bin/ffprobe").canonicalFilePath()) {
    error = "Unchanged CLI requires the pinned /usr/bin/ffprobe";
    return false;
  }
  return true;
}
bool FlowHost::inspectDirectMetadata() { return submit(false); }
bool FlowHost::exportDefaultView() {
  if (!m_busy)
    resetPreview();
  return submit(true);
}
bool FlowHost::submit(bool render) {
  if (m_busy)
    return reject(
        "One immutable job is already active; repeat submission refused");
  QString input, output, error;
  FileIdentity identity;
  if (!localPath(m_input, input, error) || !regularIdentity(input, identity))
    return reject("Input path is no longer a readable regular file: " + error);
  if (render && (!m_declared || !validateOutput(output)))
    return m_declared
               ? false
               : reject("Explicit already-stitched declaration required");
  if (!backendValid(error))
    return reject(error);
  resetPreview();
  auto job = std::make_shared<Job>();
  job->token = QUuid::createUuid().toString(QUuid::WithoutBraces);
  job->input = input;
  job->output = output;
  job->inputIdentity = identity;
  job->render = render;
  m_job = job;
  m_busy = true;
  m_phase = render ? "rendering" : "inspecting";
  m_failure.clear();
  m_metadataText.clear();
  m_diagnosticText.clear();
  m_created = false;
  m_metadataOutcome =
      render ? "No direct metadata inspection in this render job" : "running";
  QProcess *process = new QProcess(this);
  job->process = process;
  process->setUnixProcessParameters(
      QProcess::UnixProcessFlag::CreateNewSession |
      QProcess::UnixProcessFlag::CloseFileDescriptors);
  QProcessEnvironment env;
  env.insert("PATH", m_config.path);
  env.insert("LANG", "C");
  env.insert("LC_ALL", "C");
  process->setProcessEnvironment(env);
  process->setProcessChannelMode(QProcess::SeparateChannels);
  process->setStandardInputFile(QProcess::nullDevice());
  job->watch = new QTimer(this);
  job->watch->setInterval(20);
  connect(job->watch, &QTimer::timeout, this, [this, job] {
    if (!current(job))
      return;
    QList<ProcessIdentity> live;
    if (!members(job, live)) {
      if (job->cleanup)
        m_failure =
            "Cleanup ownership unresolved; no unverified process signalled";
    }
    if (job->cleanup || job->directDone)
      settle(job);
  });
  connect(process, &QProcess::started, this, [this, job, process] {
    if (!current(job))
      return;
    job->pid = process->processId();
    ProcessIdentity identity;
    if (proc(job->pid, identity) && identity.group == job->pid &&
        identity.session == job->pid) {
      job->leader = identity;
      job->leaderCaptured = true;
      job->members[identity.pid] = identity;
      emit audit(
          QString("owned leader token=%1 pid=%2 start=%3 group=%4 session=%5")
              .arg(job->token)
              .arg(identity.pid)
              .arg(identity.start)
              .arg(identity.group)
              .arg(identity.session));
    }
    job->watch->start();
    emit changed();
  });
  connect(process, &QProcess::readyReadStandardOutput, this,
          [this, job] { drain(job, false); });
  connect(process, &QProcess::readyReadStandardError, this,
          [this, job] { drain(job, true); });
  connect(process, &QProcess::errorOccurred, this,
          [this, job, process](QProcess::ProcessError error) {
            if (!current(job))
              return;
            if (error == QProcess::FailedToStart)
              job->directDone = true;
            fail(job, QString("Process error %1: %2")
                          .arg(int(error))
                          .arg(process->errorString()));
          });
  connect(
      process, &QProcess::finished, this,
      [this, job](int code, QProcess::ExitStatus status) {
        if (!current(job))
          return;
        drain(job, false);
        drain(job, true);
        job->directDone = true;
        emit audit(QString("direct child completed token=%1 exit=%2 status=%3")
                       .arg(job->token)
                       .arg(code)
                       .arg(int(status)));
        if (status != QProcess::NormalExit || code != 0)
          fail(job,
               QString("%1, exit %2")
                   .arg(status == QProcess::CrashExit ? "CrashExit"
                                                      : "NormalExit failure")
                   .arg(code));
        else
          settle(job);
      });
  if (!render) {
    job->deadline = new QTimer(this);
    job->deadline->setTimerType(Qt::PreciseTimer);
    job->deadline->setSingleShot(true);
    connect(job->deadline, &QTimer::timeout, this, [this, job] {
      if (current(job))
        fail(job, "Inspection deadline exceeded");
    });
    job->deadline->start(m_config.inspectionMs);
  }
  process->start(m_config.cli,
                 render ? QStringList{input, output}
                        : QStringList{"--metadata", input},
                 QIODevice::ReadOnly);
  emit audit("submitted immutable job " + job->token);
  emit changed();
  return true;
}
bool FlowHost::current(const std::shared_ptr<Job> &job) {
  if (job == m_job)
    return true;
  emit audit("ignored stale job " + job->token);
  return false;
}
void FlowHost::drain(const std::shared_ptr<Job> &job, bool errorChannel) {
  if (!current(job) || !job->process)
    return;
  job->process->setReadChannel(errorChannel ? QProcess::StandardError
                                            : QProcess::StandardOutput);
  qsizetype total = 0;
  while (job->process->bytesAvailable() > 0 && total < Quantum) {
    QByteArray b = job->process->read(Chunk);
    if (b.isEmpty())
      break;
    total += b.size();
    if (errorChannel)
      retain(job->err, job->droppedErr, b);
    else
      retain(job->out, job->droppedOut, b);
  }
  if (job->process->bytesAvailable() > 0)
    QTimer::singleShot(0, this,
                       [this, job, errorChannel] { drain(job, errorChannel); });
}
void FlowHost::publishTails() {
  if (!m_job)
    return;
  QString out = display(m_job->out, m_job->droppedOut),
          err = display(m_job->err, m_job->droppedErr);
  if (out != m_metadataText || err != m_diagnosticText) {
    m_metadataText = out;
    m_diagnosticText = err;
    emit changed();
  }
}
bool FlowHost::members(const std::shared_ptr<Job> &job,
                       QList<ProcessIdentity> &live) {
  if (!job->pid)
    return true;
  QList<ProcessIdentity> group;
  const QStringList entries =
      QDir("/proc").entryList(QDir::Dirs | QDir::NoDotAndDotDot);
  for (const QString &entry : entries) {
    bool numeric = false;
    qint64 pid = entry.toLongLong(&numeric);
    if (!numeric)
      continue;
    ProcessIdentity p;
    if (!proc(pid, p)) {
      if (QFileInfo::exists(QString("/proc/%1").arg(pid)))
        return false;
      continue; // Disappearance is distinct from an unreadable surviving entry.
    }
    const auto known = job->members.find(p.pid);
    if (known != job->members.end() && !same(p, known->second))
      return false;
    const auto parent = job->members.find(p.parent);
    ProcessIdentity actualParent;
    const bool ownedChild =
        parent != job->members.end() && proc(p.parent, actualParent) &&
        same(actualParent, parent->second) && p.start >= job->leader.start;
    if (p.group == job->pid || p.session == job->pid || ownedChild) {
      if (p.group != job->pid || p.session != job->pid)
        return false;
      group.append(p);
    }
  }
  if (group.isEmpty())
    return true;
  if (!job->leaderCaptured)
    return false;
  bool progress = true;
  while (progress) {
    progress = false;
    for (const auto &p : group) {
      auto known = job->members.find(p.pid);
      if (known != job->members.end()) {
        if (!same(p, known->second))
          return false;
        continue;
      }
      auto parent = job->members.find(p.parent);
      ProcessIdentity actualParent;
      if (p.start >= job->leader.start && parent != job->members.end() &&
          proc(p.parent, actualParent) && same(actualParent, parent->second)) {
        job->members[p.pid] = p;
        progress = true;
        emit audit(QString("owned member token=%1 pid=%2 start=%3 parent=%4")
                       .arg(job->token)
                       .arg(p.pid)
                       .arg(p.start)
                       .arg(p.parent));
      }
    }
  }
  for (const auto &p : group) {
    if (!job->members.contains(p.pid))
      return false;
    if (p.state != 'Z' && p.state != 'X')
      live.append(p);
  }
  return true;
}
bool FlowHost::signalMembers(const std::shared_ptr<Job> &job,
                             const QList<ProcessIdentity> &live, int signal) {
  // pidfds bind the checked member identity across PID reuse. Never
  // kill(-group).
  for (const auto &p : live) {
    int fd = int(::syscall(SYS_pidfd_open, p.pid, 0));
    if (fd < 0) {
      if (errno == ESRCH)
        continue;
      return false;
    }
    ProcessIdentity actual;
    if (!proc(p.pid, actual) || !same(p, actual)) {
      ::close(fd);
      return false;
    }
    int result = int(::syscall(SYS_pidfd_send_signal, fd, signal, nullptr, 0));
    int error = errno;
    ::close(fd);
    if (result && error != ESRCH)
      return false;
    emit audit(QString("owned signal token=%1 pid=%2 start=%3 signal=%4")
                   .arg(job->token)
                   .arg(p.pid)
                   .arg(p.start)
                   .arg(signal));
  }
  return true;
}
void FlowHost::fail(const std::shared_ptr<Job> &job, QString error) {
  if (!current(job))
    return;
  job->failed = true;
  m_failure = std::move(error);
  m_ready = false;
  m_previewReady = false;
  emit audit("actual failure " + job->token + ": " + m_failure);
  cleanup(job);
  emit changed();
}
void FlowHost::cleanup(const std::shared_ptr<Job> &job) {
  job->cleanup = true;
  m_phase = "cleanupPending";
  m_busy = true;
  if (job->deadline)
    job->deadline->stop();
  if (job->watch && !job->watch->isActive())
    job->watch->start();
  QList<ProcessIdentity> live;
  if (!members(job, live)) {
    m_failure += " — ownership unresolved; no unverified signalling";
    return;
  }
  if (!live.isEmpty() && !job->termSent) {
    if (!signalMembers(job, live, SIGTERM)) {
      m_failure += " — TERM ownership/permission unresolved";
      return;
    }
    job->termSent = true;
    job->escalation = new QTimer(this);
    job->escalation->setTimerType(Qt::PreciseTimer);
    job->escalation->setSingleShot(true);
    connect(job->escalation, &QTimer::timeout, this, [this, job] {
      if (current(job)) {
        job->killStage = true;
        settle(job);
      }
    });
    job->escalation->start(m_config.termMs);
  }
  settle(job);
}
void FlowHost::settle(const std::shared_ptr<Job> &job) {
  if (!current(job))
    return;
  QList<ProcessIdentity> live;
  if (!members(job, live)) {
    m_phase = "cleanupPending";
    m_busy = true;
    m_failure = "Process ownership unresolved; close and readiness refused";
    emit changed();
    return;
  }
  if (job->cleanup) {
    if (job->killStage && !live.isEmpty() &&
        !signalMembers(job, live, SIGKILL)) {
      m_failure = "KILL ownership/permission unresolved; cleanup pending";
      emit changed();
      return;
    }
    if (live.isEmpty() && job->directDone)
      terminal(job);
    return;
  }
  if (!job->directDone)
    return;
  if (!live.isEmpty()) {
    fail(job, "Direct child exited with surviving owned descendants");
    return;
  }
  if (job->deadline)
    job->deadline->stop();
  if (job->watch)
    job->watch->stop();
  FileIdentity input;
  if (!regularIdentity(job->input, input) || !(input == job->inputIdentity)) {
    fail(job, "Input identity changed during operation");
    return;
  }
  publishTails();
  if (!job->render) {
    m_metadataOutcome = "NormalExit 0 — raw direct-track diagnostic only";
    terminal(job);
    return;
  }
  struct stat output{};
  QByteArray p = QFile::encodeName(job->output);
  if (::lstat(p.constData(), &output) || !S_ISREG(output.st_mode) ||
      output.st_size <= 0 ||
      !regularIdentity(job->output, job->outputIdentity)) {
    fail(job, "Normal exit did not produce a new ordinary nonempty output");
    return;
  }
  m_created = true;
  m_phase = "checking";
  m_previewState = "pending";
  job->deadline = new QTimer(this);
  job->deadline->setTimerType(Qt::PreciseTimer);
  job->deadline->setSingleShot(true);
  connect(job->deadline, &QTimer::timeout, this, [this, job] {
    if (current(job))
      previewFailed(job, "Output first-frame verification deadline exceeded");
  });
  job->deadline->start(m_config.verificationMs);
  emit changed();
  emit verifyOutput(QUrl::fromLocalFile(job->output), job->token);
}
void FlowHost::terminal(const std::shared_ptr<Job> &job) {
  if (!current(job))
    return;
  if (job->process) {
    bool unread = false;
    for (auto channel : {QProcess::StandardOutput, QProcess::StandardError}) {
      job->process->setReadChannel(channel);
      unread |= job->process->bytesAvailable() > 0;
    }
    if (unread) {
      QTimer::singleShot(0, this, [this, job] {
        drain(job, false);
        drain(job, true);
        terminal(job);
      });
      return;
    }
  }
  for (QPointer<QTimer> *timer :
       {&job->deadline, &job->watch, &job->escalation}) {
    if (*timer) {
      (*timer)->stop();
      (*timer)->deleteLater();
      *timer = nullptr;
    }
  }
  publishTails();
  m_busy = false;
  m_phase = job->failed ? "failed" : "succeeded";
  if (!job->failed)
    m_failure
        .clear(); // A refused close/repeat request is not an ongoing error.
  if (!job->render && job->failed)
    m_metadataOutcome = "failed — " + m_failure;
  if (job->process) {
    job->process->deleteLater();
    job->process = nullptr;
  }
  emit audit("terminal and no live owned members " + job->token);
  emit changed();
}
void FlowHost::attachPresenter(QObject *player, QObject *sink, QObject *audio,
                               QString token) {
  const auto job = m_job;
  if (!job || job->token != token || m_phase != "checking") {
    emit audit("ignored stale presenter " + token);
    return;
  }
  m_player = qobject_cast<QMediaPlayer *>(player);
  m_sink = qobject_cast<QVideoSink *>(sink);
  m_audio = qobject_cast<QAudioOutput *>(audio);
  if (!m_player || !m_sink || !m_audio) {
    previewFailed(job, "Presenter types unavailable");
    return;
  }
  const QPointer<QMediaPlayer> owner = m_player;
  const QPointer<QVideoSink> ownedSink = m_sink;
  connect(
      m_sink, &QVideoSink::videoFrameChanged, this,
      [this, job, token, owner, ownedSink](const QVideoFrame &frame) {
        if (!current(job) || job->token != token || m_player != owner ||
            m_sink != ownedSink || m_phase != "checking")
          return;
        if (!frame.isValid())
          return;
        if (frame.size() != QSize(1920, 1080) ||
            owner->source() != QUrl::fromLocalFile(job->output)) {
          previewFailed(
              job, "Decoded frame does not match output/source dimensions");
          return;
        }
        FileIdentity identity;
        if (!regularIdentity(job->output, identity) ||
            !(identity == job->outputIdentity)) {
          previewFailed(job, "Output identity changed during checking");
          return;
        }
        m_ready = true;
        m_previewReady = true;
        m_previewState = "paused";
        owner->pause();
        emit audit("matching actual valid1920x1080 first frame " + token);
        terminal(job);
      },
      Qt::QueuedConnection);
  connect(m_player, &QMediaPlayer::errorOccurred, this,
          [this, job, owner](QMediaPlayer::Error code, const QString &message) {
            if (current(job) && m_player == owner)
              previewFailed(job, QString("Actual multimedia error %1: %2")
                                     .arg(int(code))
                                     .arg(message));
          });
  connect(m_player, &QMediaPlayer::mediaStatusChanged, this,
          [this, job, owner](QMediaPlayer::MediaStatus status) {
            if (!current(job) || m_player != owner)
              return;
            if (status == QMediaPlayer::InvalidMedia) {
              previewFailed(job, "Actual multimedia InvalidMedia");
              return;
            }
            if (status == QMediaPlayer::EndOfMedia)
              m_previewState = "ended";
            else if (status == QMediaPlayer::NoMedia)
              m_previewState = "empty";
            else if (!m_ready)
              m_previewState = "pending";
            emit changed();
          });
  connect(m_player, &QMediaPlayer::playbackStateChanged, this,
          [this, job, owner](QMediaPlayer::PlaybackState state) {
            if (!current(job) || m_player != owner || !m_ready)
              return;
            m_previewState = state == QMediaPlayer::PlayingState  ? "playing"
                             : state == QMediaPlayer::PausedState ? "paused"
                                                                  : "stopped";
            emit changed();
          });
  m_audio->setMuted(true);
  m_player->setVideoSink(m_sink);
  m_player->setAudioOutput(m_audio);
  m_player->setSource(QUrl::fromLocalFile(job->output));
  m_player->play();
}
void FlowHost::previewFailed(const std::shared_ptr<Job> &job, QString error) {
  if (!current(job))
    return;
  if (m_player)
    m_player->stop();
  m_previewState = "error";
  m_ready = false;
  m_previewReady = false;
  job->failed = true;
  m_failure = std::move(error);
  terminal(job);
}
void FlowHost::playPause() {
  if (!m_ready || !m_previewReady || !m_player || !m_audio) {
    reject("No verified output presenter");
    return;
  }
  if (m_player->playbackState() == QMediaPlayer::PlayingState)
    m_player->pause();
  else {
    m_audio->setMuted(false);
    m_player->play();
  }
}
bool FlowHost::openOutputFolder() {
  QString path =
      m_job && m_job->render ? m_job->output : m_output.toLocalFile();
  FileIdentity identity;
  if (!m_created || !regularIdentity(path, identity))
    return reject("No actual output file to reveal");
  bool submitted = QDesktopServices::openUrl(
      QUrl::fromLocalFile(QFileInfo(path).absolutePath()));
  if (!submitted)
    return reject("Output folder launch submission failed");
  emit audit("output folder launch submitted; appearance not guaranteed");
  return true;
}
bool FlowHost::requestClose() {
  if (m_busy)
    return reject(
        "Operation still running/checking/cleaning up; close refused");
  resetPreview();
  return true;
}
