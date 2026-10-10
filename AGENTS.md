# Agent Guide

Short, practical notes for AI coding agents (Codex, Claude Code, etc.) working in this repo.
For full details see [DevGuide.md](DevGuide.md) and [CONTRIBUTING.md](CONTRIBUTING.md).

## Layout
- `Ghidra/Framework/` - core libraries (DB, generic utils, docking UI, SoftwareModeling).
- `Ghidra/Features/` - analysis features and plugins (`Base` is the big one; `Decompiler` has C++).
- `Ghidra/Processors/` - Sleigh processor specs (`.slaspec`, `.sinc`, `.pspec`, `.cspec`).
- `Ghidra/Debug/`, `Ghidra/Extensions/`, `Ghidra/Configurations/`, `Ghidra/Test/` - as named.
- `GhidraBuild/`, `gradle/` - build logic. `GhidraDocs/` - docs.
- Each module: `src/main/java`, `src/test/java` (fast unit tests), `src/test.slow/java`
  (integration tests), plus `src/main/help` for help pages.

## Build (Gradle 9.1+, JDK 21+)
Gradle project names are the module directory names (e.g. `:Base`, `:Decompiler`, `:Generic`).
- First time: `gradle -I gradle/support/fetchDependencies.gradle` then `gradle prepdev`
- Compile one module: `gradle :Base:compileJava` (prefer this over full builds)
- Compile Sleigh after processor edits: `gradle sleighCompile`
- Full distribution (slow, avoid unless asked): `gradle buildGhidra`

## Tests
- One class: `gradle :Base:test --tests 'ghidra.program.model.SomeTest'`
- Integration tests live in `test.slow`: `gradle :Base:integrationTest --tests '...'`
- Headless Linux needs a display for AWT: `Xvfb :99 -nolisten tcp & export DISPLAY=:99`
- Tests extending integration base classes (e.g. `AbstractGhidraHeadlessIntegrationTest`)
  must go in `test.slow`, not `test`.
- Do not run the whole test suite; it takes hours. Run only the tests near your change.

## Code style
- Java uses tabs, 100-column lines (see `eclipse/GhidraEclipseFormatter.xml`).
- New source files need the Apache license header used by neighboring files (`IP: GHIDRA`).
- New non-source files must be listed in that module's `certification.manifest`.
- Keep changes minimal: no reformatting, renames, repackaging, or library bumps unless asked.

## Working efficiently
- The repo is huge. Search with `rg` scoped to a module directory rather than the whole tree.
- Skip `build/`, `bin/`, and `dependencies/` directories when searching.
- Build and test only the module you touched.
