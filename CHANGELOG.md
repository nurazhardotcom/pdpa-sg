# Changelog

All notable changes to **pdpa-sg** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.1] - 2026-11-08

### Verified
- End-to-end integration with the nurazhar.com site build, now Common Lisp:
  the ASDF system loads through the local source registry, all 207 posts scan
  with exit 0, and no critical or high finding is raised.
- Report shape and exit codes unchanged when driven from the site's PDPA gate.

No scanner code changed in this release; the patch version records the
compatibility verification against the rewritten build pipeline.

## [0.5.0] - 2026-11-08

### Changed
- The repository now uses SBCL and ASDF only. All scanner code is Common Lisp.
- Rewrote `README.md`, `ARCHITECTURE.md`, `AGENTS.md`, and `CHECKLIST.md` for
  the SBCL scanner and the manual compliance pack.
- CI now runs SBCL tests, scanner JSON and SARIF checks, and a legacy-file lint.
- Corrected the PDPA penalty text to the section 48J cap.
- Corrected the NRIC text to distinguish authentication from identification.
- Marked non-statutory retention and notification periods as internal targets.
- Made the checklist fully manual. The scanner does not tick boxes.

### Removed
- Removed the old task surface, portable API, editor integrations, and build
  files.
- Removed the redaction command and the checklist auto-tick code.
- Removed the npm extension tree.

### Fixed
- Removed stale commands and references from policy templates.

## [0.4.0] - 2026-11-08

### Added
- Common Lisp scanner engine in `lisp/` with ASDF systems `pdpa-sg` and `pdpa-sg/tests`.
- Zero-dependency SBCL build at `bin/pdpa-sg` with JSON and SARIF 2.1.0 output.
- Adaptive CLOS strainer with velocity telemetry and tiered rule meshes.
- 98-check SBCL test harness and CI job.

### Changed
- Renamed the project and all current repository references to `pdpa-sg`.
- Renamed the scanner build, ASDF systems, package, and binary to `pdpa-sg`.
- Updated repository URLs, badges, clone commands, dependency coordinates, VS Code extension ID, editor paths, banners, and SARIF tool name.
- `bb scan` now points users to `bb shipit` for a nonzero gate.

### Removed
- The old project name from the current repository tree. Git history keeps earlier commits.

### Preserved
- Babashka/Clojure task surface: `about`, `init`, `scan`, `redact`, `checklist`, `audit`, `export-rules`, `shipit`, `dpo`, and tests.
- Rule behavior, 20-rule pack, CLI formats, `pdpa:ignore` semantics, and exit codes 0/1/2.

## [0.3.0] - 2026-09-06

### Fixed
- `pdpa.scan` finding `:path` is now a plain string (was the raw rg-JSON
  `{"text": ...}` map); legacy map shapes are still tolerated by exporters.
- Pre-commit hook called a non-existent `pdpa.nric/checksum-valid?`;
  now calls `pdpa.nric/valid?` (previously every structural NRIC match
  fail-closed the commit).
- `pdpa.version/toolkit-version` synced to `0.2.0` (matched `VERSION`,
  README, and CHANGELOG all along); README's `bb version` reference
  corrected to `bb about`.
- `bb audit --json` / `--format` / `--out` were silently ignored because
  `babashka.cli/parse-opts` returns a flat options map; now honoured.
- Scanner never skipped vendored trees: `rg --json` was invoked with
  `--no-ignore` and no excludes, so one `npm install` made it slurp
  `node_modules` into memory until the kernel OOM-killed the run.
  `scan` now always excludes `.git/`, `node_modules/`, `target/`,
  `out/`, `.cpcache/` (new `skip-globs`, regression-tested).

### Added
- SARIF 2.1.0 export (`pdpa.sarif`, `bb scan --format sarif`,
  `bb audit --format sarif --out audit.sarif`) for auditors and GitHub
  code scanning (CI uploads via `upload-sarif`).
- Executive Markdown/HTML auditor reports (`pdpa.report`,
  `bb audit --format html|md`), with documented PDF conversion for
  ISO 27001 filings.
- Tool-independent rule pack (`pdpa.rules`, 20 PII + secret rules):
  JWT, AWS secret/session keys, CyberArk Conjur, Slack, OpenAI,
  Anthropic, GCP, Azure, extended GitHub tokens. Exportable via
  `bb export-rules --format gitleaks|json`.
- Real-time editor feedback: VS Code task + problemMatcher
  (`editors/vscode/`), Neovim `:PdpaScan` quickfix (`editors/nvim/`),
  and a full VS Code extension scaffold (`editors/pdpa-vscode/`).
- GitHub Actions CI (`.github/workflows/ci.yml`: test job + SARIF scan
  job) replacing `.gitlab-ci.yml`; README/CHANGELOG links moved from
  private GitLab to GitHub.
- `bb scan --format quickfix` (`path:line: [SEV] label`) for editors.

## [0.2.0] - 2026-07-16

### Added
- `VERSION` file as single source of truth for semver
- `CHANGELOG.md` documenting release history
- Production-release badge in `README.md` linking to GitLab Releases page
- Production-release stamp line crediting Nur Azhar

## [0.1.0] - 2026-06-21

### Added
- Initial public release of pdpa-sg
- Singapore PDPA 11-obligation checklist, scanner, redactor, audit CLI
- 6 policy templates in `resources/policies/`
- 4 cognitect test-runner test namespaces under `test/pdpa/`
- GitLab CI

[Unreleased]: https://github.com/nurazhardotcom/pdpa-sg/compare/v0.5.0...main
[0.5.0]: https://github.com/nurazhardotcom/pdpa-sg/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/nurazhardotcom/pdpa-sg/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/nurazhardotcom/pdpa-sg/releases/tag/v0.3.0
[0.2.0]: https://github.com/nurazhardotcom/pdpa-sg/releases/tag/v0.2.0
[0.1.0]: https://github.com/nurazhardotcom/pdpa-sg/releases/tag/v0.1.0
