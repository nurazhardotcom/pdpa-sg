# pdpa-sg - Architecture

## Goals

1. Use one runtime: SBCL.
2. Keep the scanner deterministic and easy to audit.
3. Keep the scan result small enough for an AI agent to read.
4. Keep the compliance pack useful without a service or database.
5. Keep the build free of external Lisp libraries.

## Runtime

- Compiler and runtime: SBCL 2.4 or newer.
- Build and system definition: ASDF.
- External Lisp libraries: none.
- Quicklisp: not used.
- Build output: `bin/pdpa-sg`.

The source is Common Lisp. The repository has no second implementation.

## Module map

| File | Role |
|---|---|
| `lisp/src/cli.lisp` | Parse flags, run the scan, set the exit code. |
| `lisp/src/config.lisp` | Read the JSON config. |
| `lisp/src/walk.lisp` | List files and apply skip rules. |
| `lisp/src/strainer.lisp` | Compile rule tiers and screen lines. |
| `lisp/src/match.lisp` | Match rule patterns. |
| `lisp/src/nric.lisp` | Validate NRIC and FIN check digits. |
| `lisp/src/rules.lisp` | Hold the 20-rule pack. |
| `lisp/src/scan.lisp` | Build findings, counts, and the clean flag. |
| `lisp/src/detect.lisp` | Apply rule tiers to a line. |
| `lisp/src/telemetry.lisp` | Record speed and batch adaptation. |
| `lisp/src/json.lisp` | Write JSON. |
| `lisp/src/sarif.lisp` | Write SARIF 2.1.0. |
| `lisp/src/policy.lisp` | Apply severity thresholds. |
| `lisp/src/text.lisp` | Text helpers. |
| `lisp/src/version.lisp` | Package version and rule stamp. |
| `lisp/test/test.lisp` | Test suite. |
| `lisp/build.lisp` | Build script. |
| `lisp/pdpa-sg.asd` | ASDF system definition. |

## Data flow

```text
target path
  -> walk.lisp
  -> strainer.lisp
  -> match.lisp + nric.lisp
  -> scan.lisp
  -> json.lisp or sarif.lisp
  -> stdout or --out file
```

1. `walk.lisp` lists regular files under the target.
2. `walk.lisp` skips `.git`, `node_modules`, `target`, `out`, and `.cpcache`.
3. `strainer.lisp` reads each file line by line.
4. `detect.lisp` applies the critical tier and, at depth 2, the standard tier.
5. `match.lisp` tests rule patterns. `nric.lisp` validates NRIC and FIN check
   digits.
6. `scan.lisp` collects findings and counts.
7. `sarif.lisp` writes the selected output format.
8. `cli.lisp` sets exit code `0`, `1`, or `2`.

## Rule pack

`lisp/src/rules.lisp` holds 20 rules. Each rule has:

- an identifier,
- a severity,
- a family,
- a pattern or predicate,
- a message.

The rule families cover NRIC and FIN numbers, contact data, credentials,
financial data, health data, logging, transfers, and policy gaps.

The scanner is line based. It does not build a data-flow graph. A finding means
that a line matches a rule. A human must confirm the context.

The `pdpa:ignore` marker skips a line. Use it for fictional test data and
documentation examples.

## Strainer and telemetry

The strainer is a mutable CLOS object. It holds:

- the active rule set,
- the batch size,
- the inspection depth,
- the velocity monitor.

The critical tier holds critical and high rules. The standard tier holds medium
and low rules. At depth 1 the engine skips the standard tier.

The strainer compiles each tier into a function with `compile`. This keeps the
line loop small.

The velocity monitor measures records per second. After each batch it classifies
the rate:

- A surge doubles the batch and restores full depth.
- A slowdown halves the batch.
- At the minimum batch size, a slowdown also lowers the depth by one tier.

The JSON `telemetry` object records velocity, peak, mean, records, batches, batch
size, depth, adaptations, last signal, mesh rebuilds, and the degraded flag.

## CLI contract

The CLI accepts:

- `--target` or `-t`
- `--config`
- `--format json|sarif`
- `--out`
- `--batch`
- `--depth`
- `--velocity`
- `--help` or `-h`
- `--version` or `-V`

The saved binary uses the SBCL runtime for `--help` and `--version`. Those two
flags print SBCL information. The tool handles all other flags.

Exit codes:

- `0`: scan completed. Findings do not change the code.
- `1`: scan, config, or write error.
- `2`: bad usage.

## Output contracts

### JSON

The result object has:

- `findings`: array of finding objects.
- `counts`: counts by severity and rule.
- `clean`: `true` when no finding exists.
- `telemetry`: scan speed and adaptation data.

### SARIF

The SARIF document uses version 2.1.0. It has:

- `driver.rules`: the rule metadata.
- `results`: the findings.
- `informationUri`: the repository URL.

## Config

The config is JSON. Supported keys:

- `maxCritical`: maximum allowed critical findings.
- `maxHigh`: maximum allowed high findings.
- `excludes`: path fragments to skip.

The policy layer fails when a threshold is exceeded. The scan still exits `0`
unless a config or read error occurs.

## Tests

`lisp/test/test.lisp` holds the test suite. It covers:

- NRIC and FIN check digits.
- Rule matching.
- `pdpa:ignore` behaviour.
- File walk and skip rules.
- JSON and SARIF shape.
- Policy thresholds.
- CLI parsing.
- Telemetry.

Run:

```bash
sbcl --non-interactive --load lisp/test/test.lisp
```

Expected final line:

```text
TESTS DONE checks=98 tests=15 failures=0
```

## CI

`.github/workflows/ci.yml` has two jobs:

1. `sbcl`: install SBCL, run tests, build the scanner, check JSON output, check
   SARIF output.
2. `lint`: fail when a legacy source or package file exists.

The CI has no other runtime.

## Limits

- The scanner is line based.
- The scanner does not redact data.
- The scanner does not edit the checklist.
- The scanner does not replace legal review.
- The rule pack is a triage aid, not a complete PDPA test suite.
