# AGENTS.md - operator notes for AI agents

Owner: Nur Azhar <dev@nurazhar.com> · https://nurazhar.com <!-- pdpa:ignore -->
Identity rule: all commits as `Nur Azhar <dev@nurazhar.com>`. <!-- pdpa:ignore -->
Get identity from evidence (`git log`, `gh api user`). Do not invent an email.

## Runtime

Use SBCL 2.4 or newer. Use ASDF only. Do not add external Lisp libraries.
Do not add a second runtime.

## Everyday commands

```bash
sbcl --non-interactive --load lisp/test/test.lisp
sbcl --non-interactive --load lisp/build.lisp
./bin/pdpa-sg --target /path/to/project --format json
./bin/pdpa-sg --target /path/to/project --format sarif --out audit.sarif
```

Run the test suite before a commit. Build the scanner after a source change.
`bin/pdpa-sg` is build output. Git ignores it.

## Environment warning

The host has about 2.7 GB RAM and no swap. The scanner reads files line by line.
Keep scans on small scopes. Do not scan large dependency trees.

The scanner skips `.git`, `node_modules`, `target`, `out`, and `.cpcache`.
Keep these skip rules.

## File rules

- Keep the active tree free of `.clj`, `.cljc`, `.cljs`, `.edn`, and
  `package.json` files.
- Keep the scanner and tests in `lisp/`.
- Keep policy templates in `resources/policies/`.
- Keep the checklist manual. Do not add auto-tick code.
- Do not add a redaction command. The scanner reports findings. It does not edit
  target files.
- Preserve unrelated work. Stage only files for the current task.

## Verification

```bash
sbcl --non-interactive --load lisp/test/test.lisp
sbcl --non-interactive --load lisp/build.lisp
find . -path ./.git -prune -o -type f \
  \( -name '*.clj' -o -name '*.cljc' -o -name '*.cljs' -o -name '*.edn' -o -name 'package.json' \) -print
```

The test final line must be:

```text
TESTS DONE checks=98 tests=15 failures=0
```

The `find` command must print nothing.

## Commit rules

Use a focused commit message. Do not push or publish unless the owner asks.
Do not change `VERSION` unless the task is a release.
