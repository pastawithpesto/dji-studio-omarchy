# Zcode and DSH headless sessions

Use this procedure for assigned headless research and source tasks. The user
authorized these tools for this task. This authorization does not change the
coordinator policy for other tools or workers. Keep author, independent reviewer,
and verifier sessions separate. A persistent conversation does not grant source,
resource, review, or merge authority.

## Check the tools

Read `AGENTS.md`, current task instructions, and all open PR claims. Fetch main
at task start, resume, and each source checkpoint. Reserve exact source paths in
a draft PR. Wait for the current successful claims watchdog before edits.

Check the installed commands without a model call:

```sh
command -v zcode
zcode --help
zcode --version
command -v dsh
dsh --help
dsh --profile headless --help
dsh --version
```

On the maintainer host on 2026-10-12, Zcode reports `0.16.9`. The launcher at
`/home/violence/.local/bin/zcode` executes
`/home/violence/Work/zcode-cli-auth-fix/apps/zcode-cli/packages/cli/dist/zcode-official.cjs`.
This installed official-core bundle supports headless prompts and the TUI.
The separate source bundle `dist/zcode.cjs` issued a PAT, then its model
authentication probe returned HTTP `401` twice. It is not the installed entry
point. Keep Zcode source and authentication
repairs in the separate Zcode project.

DSH reports `0.2.0-rc.2`. Its installed headless help lists `--session-id`, `--json`,
and task `-` for stdin. The local overlay
`/home/violence/Work/dsh-feedback-20261012/dsh-config-overlay.yml` selects
`deepseek-official`, `deepseek-flash`, and `reasoningEffort: max`. `max` is the
local setting. Do not replace it with an unsupported `xhigh` value. Verify the
selected model on a new or resumed run. A helper record does not select a model.

## Start and resume

Use an owned, stable working directory. A research session can use a stable
research directory and refer to a freshly checked source worktree by absolute
path. Check source identity again before each source action.

These command examples require an assigned task and actual returned IDs.
Set `TASK`, `WORKTREE`, and `NATIVE_ID` from the assigned task and native session.
The examples do not supply or generate a session ID.

```sh
zcode --cwd "$WORKTREE" --mode plan --prompt "$TASK"
zcode --cwd "$WORKTREE" --mode plan --resume "$NATIVE_ID" --prompt "$TASK"
```

Use an explicit Zcode mode. The installed prompt default is `yolo`. Supported
modes are `plan`, `build`, `edit`, and `yolo`. Select a mode within the authorized
task. `--resume` selects an exact persisted `sess_...` ID. `--continue` selects
the latest session in a directory; it does not pin the assigned conversation.
Zcode `--json` prints a closing summary with `sessionId` and `response`.

Start DSH without `--session-id`. Then resume the actual returned ID:
Set `DSH_OVERLAY` to the verified absolute overlay path given above.

```sh
cd "$WORKTREE"
dsh --profile headless --patch "$DSH_OVERLAY" "$TASK"
dsh --profile headless --patch "$DSH_OVERLAY" --session-id "$NATIVE_ID" -- "$TASK"
```

For stdin, pass `-` as the task and supply the task on stdin. Launcher options,
including `--profile` and `--patch`, must precede headless application options.
DSH has no headless `--cwd` flag. Set the process working directory explicitly.
DSH `--json` emits NDJSON events, including session, thinking, text, tool, and
final events. DSH rejects an unknown ID. It also rejects a different working directory,
a subagent or forked session, an agent preset, or a live agent in that process.
Run each assigned conversation one turn at a time. Do not assume that this
check is a lock across separate processes.

The installed DSH source records these checks in
`@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-headless/lib/index.js`, functions
`assertAdoptable` and `resolveAgent`. Its new-session path uses
`session-${randomUUID()}`. The inspected Zcode source uses
`sess_${crypto.randomUUID()}` in `packages/contracts/src/interfaces/shared.ts`,
function `createSessionId`. These source checks support the helper's current
ID format rule. They do not prove that a particular ID exists.

Keep the original working directory for a recorded session. For a new checkout
directory, start a new native session. Give it a short handoff with the previous
source identity, task result, evidence references, and remaining work. Do not
change an old record's directory to bypass native checks.

## Record a session

`tools/headless_agents.py` needs only the Python standard library on Linux.
It stores a recorded native ID and prints resume arguments. It does not start
a model, create a native session, read a transcript, or verify native existence.
Register only an ID that the native tool returned. The helper accepts current
UUID forms. A different future native format needs a reviewed helper change.

Choose a private external store with an existing parent directory. This example
uses a new directory under the user's home. Keep this data outside Git:

```sh
SESSION_STORE="$HOME/dji-headless-session-records"
python tools/headless_agents.py --store "$SESSION_STORE" register zcode-research \
  --tool zcode --session-id "$NATIVE_ID" --cwd "$WORKTREE" --mode plan
python tools/headless_agents.py --store "$SESSION_STORE" resume-argv zcode-research \
  --task "$TASK"
python tools/headless_agents.py --store "$SESSION_STORE" status zcode-research
python tools/headless_agents.py --store "$SESSION_STORE" checkpoint zcode-research \
  --text "Source checked. Contract review remains open."
```

For DSH, use `--tool dsh` and the actual DSH ID. Omit `--mode`. Supply `--patch`
with the absolute overlay path if required. The profile is always `headless`.
The `resume-argv` output contains an argument array and `cwd`. A caller must
use that directory and pass the array directly to the process API. Do not
join the array into shell code or use `eval`. The helper does not run the array.
The task appears in this command output but is not stored in the record.
Use `--json-output` to add the native `--json` flag. Zcode prints a summary;
DSH prints events. Keep both outputs subject to the evidence rules below.

The helper creates the store with mode `0700` and records with mode `0600`.
It rejects public or foreign-owned records, hard links, and symlinks in the
store path. It serializes helper operations with a directory lock and replaces
records atomically. Only checkpoint text, evidence reference, and update time
can change through the checkpoint command. The helper does not protect native
session files or prevent another program under the same user from editing data.

After a successful separate native resume, use `--resume-evidence` on `register`
or `checkpoint` to record a short evidence reference. This field is a user
statement. It is not an automatic existence or continuation check. Save the
actual bounded proof in the task evidence packet.

## Keep evidence safe and check continuation

Native session stores can contain private reasoning, credentials, signatures,
and tool output. Keep them private. CLI stdout and stderr can also contain
private reasoning. `--json` is a transport format, not a safe transcript.
Do not pipe raw model events or diagnostics to `tee`, task logs, Git, comms,
or a PR. Do not print environment or authentication configuration.

Inspect events in memory when needed. Export only an explicit set of public
fields: tool version, selected provider/model and effort, native session ID,
working directory, turn result, exit status, and short evidence references.
Do not export reasoning fields, signatures, raw content parts, full tool events,
or diagnostics. Review a public task answer before saving it as evidence.
Keep helper checkpoints to short task facts. The helper cannot identify all
sensitive content in user-written text.

Use two separate native CLI processes for a bounded continuation check.
Record the returned ID from the first process. Resume that exact ID in the
second process from the same directory. Ask a harmless question that depends
on the first turn. Record the selected model, ID, response check, and exit
status for both turns. An argument array or a stored ID alone does not pass.
Keep a failure as an additive record. Do not hide it with a later successful run.

## Research and delivery gates

Follow [REA-WORKFLOW.md](REA-WORKFLOW.md). Update only an owned REA installation
to fresh upstream before new analysis. Record upstream commit, package version,
running MCP server version, Ghidra version, settings, and artifact hashes.
Check actual connector access. Reuse matching saved evidence. Preserve peer
sessions and pin the tool version that produced each evidence packet.

Reserve each Rust target separately. Use reviewed original-byte evidence for
the behavior contract. Keep design choices and unknown behavior explicit.
Run meaningful checks for the change. Request independent review of the exact
candidate, then milestone verification. Use a different model for review by
default. Same-model review requires coordinator confirmation that the model is
the heaviest available OpenAI or Anthropic model. Start a new review session for
that exception. Do not resume the author conversation for review or infer the
exception from a model name. Record author and reviewer identities, models,
session identities, candidate SHA, and any exception basis. Keep the author and
reviewer roles separate. Preserve historical Sol and Astra attribution.
Root rechecks source, claims, checks, and review results before an authorized
merge. Follow [PR-REVIEW.md](PR-REVIEW.md). Report the observed merge commit.
Headless continuation, helper tests, and static analysis do not establish
Windows, camera, GUI, project, or processing parity.

## Observed continuation

The [public proof packet](evidence/headless-workflow/README.md) records two
separate processes per tool on 2026-10-12. Both tools returned the same native
session ID on resume from their original directory. All four processes exited
with status `0`. Six Zcode recall checks passed. The DSH resumed turn produced
an additive correction. The packet exports only selected public fields.

Zcode native session metadata selected `GLM-5.3-Flash` with
`reasoningLevel: high`. DSH selected `deepseek-official`, `deepseek-flash`, and
`reasoningEffort: max` through the configured overlay and local selection code.
This DSH evidence does not attest the backend model. The proof does not establish
a lock across processes, REA access, Rust correctness, or application parity.
