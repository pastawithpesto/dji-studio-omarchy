# Rust application language rule

The user requires Rust as the application language. Preserve the original QML UI.
Do not add handwritten C or C++ application code or inline C or C++ payloads.
External Qt libraries and generated bindings remain separate build dependencies.
Do not present them as Rust code or as recovered DJI source.

## Plan

Add scoped agent instructions and contribution rules. Write a dependency-free Rust
check that rejects tracked C/C++ source files and Rust inline C++ macros. Check
other application source languages under src and gui. Run the check in a separate
CI job for each PR. Keep generated build files outside the tracked source tree.
Validate both allowed current source and deliberate prohibited source cases.
Request independent exact-candidate review and separate milestone verification.

## Scope

Own CONTRIBUTING.md, src/AGENTS.md, gui/AGENTS.md,
tools/check_application_language.rs, .github/workflows/application-language.yml,
and this task plan. PR44 owns root AGENTS.md. Its owner received the rule through
comms3731. Do not edit that claimed file in this PR.

## Source and limits

Initial main8b147cadd1b92ff52b30cde995429cb04f85eb17 contains merged PR8.
Owned branch work/rust-application-language-law-20261012. Plan-only source is clean.
The gate checks source files and known inline C++ macros. Review must also check
that application behavior stays in Rust and original QML remains unchanged.
This is a source policy. It does not remove Qt's external C++ implementation.
