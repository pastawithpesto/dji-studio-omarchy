# Keep the DLL research console local

The user did not authorize publishing the reverse-engineering command center
in this GitHub repository. Remove tools/dll_console and its public task plan
from the current repository tree. Keep an exact local copy outside the repository.
Preserve the existing local runtime, research artifacts, jobs and peer processes.

Own tools/dll_console/**, docs/tasks/dll-research-console.md, .gitignore,
and this task plan. Ignore tools/dll_console so a local copy is not added again.
Application source and research evidence are outside this change.

Completion checks: every preserved local file matches the current source hash;
the removal diff stays in its declared paths; no console file remains tracked;
the ignore rule works; independent exact-candidate review and separate milestone
verification pass. Coordinate the main merge with the active repository owner.

Deleting files in a later commit does not erase earlier Git history.
This task does not rewrite history or change repository visibility.
