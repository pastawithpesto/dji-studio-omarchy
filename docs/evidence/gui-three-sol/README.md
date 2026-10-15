# Three local DJI GUI modules

This local branch connects FpsDetect, UserGuideTypeModel and BusinessLog to the
Rust host. It keeps the exact original QML and resource bundle.
The source reference is DJI Studio 1.0.0.30839. Its executable SHA-256 is
`e8732b263ea6486680a3007349b9c06a37cfb64c8797610743fd3b3831b0faf4`.

Three separate GPT-6.1 Sol High agents own the modules. Root owns host integration.
Each module has an independent source reviewer. The project bus records local
scope, source identities, resource grants, failures and review decisions.
The user requests local work. No source was pushed or published to GitHub.

## Supported parts

- [FpsDetect](../gui-fpsdetect/CONTRACT.md) provides the frame counter, timer and
  original signal behavior. Reference and native checks pass for hooks,
  arithmetic, reset, nested callbacks and deletion during an active callback.
  Candidate `f1bd48d118784d6ee3ff5b9106fa28f3847a74cc` passed independent
  Sol-3 review 4273. It retains one generated dead-code warning.
- [UserGuideTypeModel](../gui-userguide-type-model/README.md) provides the two
  original creatable types and their 16 unscoped enum values. Candidate
  `a9f1b4e994d3080d70d69064aba94a78ef806668` passed independent Sol-3
  review 4265, ordered native checks and application Clippy.
- [BusinessLog](../gui-business-log/README.md) provides the two original scoped
  enums with 30 signed values. It rejects creation with `enums only`.
  Candidate `1f0d0a22f68e30702b75aac95881c070d51fb0ab` passed independent
  Sol-2 review 4198 and its native tests. BusinessLogger remains separate.

The host registers the modules after QGuiApplication construction and before
engine construction. Its test imports all three modules in one engine. It also
keeps the original Config singleton values, missing-resource and event-loop
checks. Combined host native execution passes on code candidate
`d00cb302463da5aa3e4c601fceed13dcfcd94075`. A fresh build took 13m42s with
one Cargo job. Independent source review 4263 and native evidence review 4271
approve this bounded host integration. Its expected missing-resource test
reports the selected failure.

The [selected checks](checks.json) pin the native logs, module candidates,
review decisions, resource identities and failed tool setup records.

Original `Main.qml` still returns failure with six missing top-level imports:
CloudAlbumManager, UserGuideMaskManager, BusinessLogger, ViewModeAnalyzeController,
ProjectStateController and SettingPanelViewModel. The three modules in this task
resolve. The import failure prevents measurement of later nested types and
context services. The DJI window is not ready.

## Compiler and resource checks

The pinned local CXX-Qt0.10 generator adds an opt-in unscoped enum declaration,
qualified enum alias IDs, signal namespace qualification and shared callback
storage. Default enum output remains unchanged against the independent stock
fixture. The combined generator passes nine focused checks.
The first combined run used an unconfigured rustup rustfmt shim. The retry used
system rustfmt and passed without a source change. Both logs remain in the
private evidence packet.

The original trees remain unchanged:

| Path | Git object |
| --- | --- |
| gui/original | `cadcae161e59fd5bedcd653657c8341fa5c4a064` |
| gui/resources/original | `9aeef9852afa083b0f401424c5991addee0cb734` |
| gui/original/original.qrc | `7e5ecc78ae8a2a72fe24189b290d248e7122f97e` |

The original QRC has 1,826 unique aliases, including 410 QML files.
Full binaries, compiler output, core records and failed probes stay outside source
in `reconstruction/root-gui-three-sol-20261013` in the research project.

## Limits

Static original bytes support the module contracts. Local native checks use
Qt6.11.2 on Linux. Original Qt6.5.3 metadata and current Qt registration artifacts
remain separate. The guide and FPS types retain an added `QML.Element` class-info row.
Private Qt registration and metadata APIs are explicit adapter dependencies.
Shared Rust callback storage, frame locking and registration error handling are
independent Rust policies.

Complete Main startup, Windows behavior, graphics, camera processing, project
compatibility and complete QObject ABI parity remain incomplete. Original
resources and passing module tests do not establish full GUI parity.
