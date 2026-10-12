# Application language

Implement application behavior in Rust. Keep the original UI in QML.
Preserve original names, text, layout, assets, interactions and workflows.
Do not add handwritten C or C++ source or inline C or C++ payloads.
Do not implement application behavior in another language or move it into an
external wrapper to bypass this rule. Research and coordination tools are separate
from application code.

Qt and binding libraries are external dependencies. Build-generated bindings
and resource code must stay outside tracked source. Rust API declarations are
permitted. Report these dependencies accurately; the stack still contains C++.

The application language CI job checks tracked C/C++ source, other common source
languages under src and gui, and known inline C++ macros in Rust files.
Three existing C research files have exact content pins in the checker. They are
frozen evidence, not application implementations. No directory is exempt.
Review must also check that behavior stays in Rust and original QML is unchanged.
Run the same check locally:

```sh
rustc --edition=2024 -D warnings tools/check_application_language.rs \
  -o /tmp/dji-application-language
/tmp/dji-application-language
```

# Work reservation

1. Read docs/STATUS.md and all open PRs, including drafts.
2. Select a task with no overlapping owner. Use a separate branch and worktree.
3. Commit only a short task plan to `docs/tasks/<unique-task>.md`.
4. Open a draft PR immediately. Use the PR template. Declare the GitHub owner,
   task, intended file scope, existing evidence, next step, and completion test.
5. Wait for a successful PR watchdog result. Resolve conflicts before you edit.
6. Keep implementation and progress in the same PR. Update its scope before
   you expand the task. Read new PRs and updates immediately.
7. Request independent review when the task is ready. Keep the PR in draft until
   required reviews and milestone verification are complete.

The PR is the work reservation. An issue or a local message alone does not reserve
work. Do not repeat work recorded as complete. Reuse the existing branch or evidence.
Keep one owner per scope. Record transfers in the PR before the new owner starts.

## Machine-readable claim

Keep exactly one claim line in the PR body. Replace the example values.

```text
<!-- work-claim {"owner":"YOUR_LOGIN","paths":["src/example.rs","docs/tasks/example.md"],"task":"Describe the task"} -->
```

Use exact repository paths or a directory with `/**`, such as `gui/original/**`.
Other wildcard forms are not supported. Preserve path case. Declare the task plan
file as well. The watchdog treats parent and child directory scopes as overlapping.
It also checks changed and renamed files against the declared scope.

## PR watchdog

The GitHub Actions workflow is configured for PR creation, edits, commits, reopening,
closure, and draft state changes. Automatic `pull_request_target` execution was
verified by [run38194148483](https://github.com/pastawithpesto/dji-studio-omarchy/actions/runs/38194148483).
Manual runs also pass. It reads all open PR claims. It reports invalid
claims, overlapping scopes, and changes outside the claimed scope. A manual run
is also available in Actions. Queue delays can occur. This is a conflict detector,
not a file lock or a substitute for reading the PR.

Use GitHub Watch notifications for PR activity. Read each new PR or update when
it arrives. During active work, check open PRs at least every two minutes and
before edits or pushes. If checks fail or cannot run, pause affected work.
A successful old result does not reserve a scope against a later conflicting PR.

## Evidence and review

State what changed, why it changed, the source evidence, test results, and limits.
Keep exact hashes and review decisions. Do not describe an unreviewed branch as
approved. See AGENTS.md for model roles and milestone gates.
