# Local DLL research console

Run this command from the native repository:

```sh
python3 tools/dll_console/server.py --project /home/violence/Projects/dji-studio-omarchy
```

Open <http://127.0.0.1:8765>. The server binds only to the loopback address.
Select a DLL. Select one work area, or hold Shift to select more. Inspect the
missing work and evidence. Choose a model and Research or Review. Add directions.
Read the generated task. Select Queue task to start a bounded assignment when
a CLI slot is free. Pause and Resume apply only to console jobs.

The work map shows tracked evidence scopes. The binary map shows PE sections.
The export list reads the original PE export table. These views do not measure
whole-DLL completion. Research, implementation, and reference checks have separate
states. Recorded approvals remain limited to their declared scope. Original DLL
and review hashes are checked. Changed evidence pins block approval display.

The catalog covers four DLLs in detail. Other extracted DLLs have PE structure
and generic open research areas. The catalog is a curated record. A worker result
does not update its approval states automatically. Independent review is required.

The console uses existing local Codex and OpenCode logins. It runs fixed Luna,
Sol, Astra, or Kimi models. No provider fallback is used. CLI availability does
not prove that the provider has quota. The shared launch lock and three-worker
limit preserve existing CLI work. Other workers appear as read-only entries.
ThumbnailProvider research waits while the existing Kimi scope is active.

Each console job writes into its own output folder. The initial assignment reads
saved evidence. It does not authorize source changes, new REA imports, vendor
execution, installation, publication, or extra model workers. A Codex worker uses
workspace-write mode. OpenCode follows a fixed bounded agent instruction; this
instruction is not an operating-system sandbox. Use this console with trusted
local model tools. Agent tools can read the evidence paths included in the task.

The default runtime folder is `reconstruction/dll-console-runtime`. Control
records, task outputs, and raw CLI logs are separate. Public artifact routes use
an exact allowlist. They do not expose raw CLI logs or reasoning events. Job
controls verify the process ID, start time, process group, and output directory.
An interrupted job needs explicit Resume. Stopping the server does not stop
workers. Restarting the server retains the queue and detects running processes.
If their completion cannot be verified, their state becomes interrupted.

Usage totals come from reported project session metadata. Cached input is a
subset, not another addition to the total. Tokens are not a billing estimate.
Account quota is read through the local Codex app server. If that query fails,
quota is unknown. OpenCode provider quota is not available here. Collaboration
agents without local CLI process records are not represented as controllable jobs.

For inspection without model execution, add `--no-launch`. Queue controls still
save local tasks in this mode. They do not start a CLI worker.

Run the checks:

```sh
python3 -m unittest discover -s tools/dll_console -p 'test*.py' -v
node --check tools/dll_console/static/app.js
```

The tests use synthetic PE files, local fixtures, and HTTP requests. They do not
invoke a model or prove original DJI behavior.

The implementation follows the official
[Codex non-interactive documentation](https://developers.openai.com/codex/noninteractive)
and [app server documentation](https://developers.openai.com/codex/app-server).
The design record follows Google's
[Stitch design extraction skill](https://github.com/google-labs-code/stitch-skills/blob/main/plugins/stitch-design/skills/extract-design-md/SKILL.md).
See [.stitch/DESIGN.md](.stitch/DESIGN.md) for the implemented design system.
