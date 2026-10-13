# Display agent credits

The user asks why agents do not appear as GitHub contributors.
The user accepts a visible README credit section.

Add the verified model roles from AUTHORS.md at the bottom of README.md.
Add a short guide for correct commit co-author records.
Verify Codex and Claude account identities through the GitHub API.
Keep unresolved Kimi and Qwen account identities explicit.
Credit only agents that actually contributed to each commit.

This task adds an attribution section to the historical README.
Preserve all existing README bytes before that section.
Do not change its historical build text or application source.
Do not rewrite reviewed commits.

Files: README.md, docs/AGENT-CREDITS.md, and this task plan.

Completion checks: original README prefix unchanged, accurate roles and links,
correct Codex co-author trailer, independent Sol High review,
separate Astra High verification, and protected merge after required checks.
