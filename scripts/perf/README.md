# Performance Benchmark Workflow

Run all performance tests, gather system information, and update baseline
comments in the test source files. Execute this workflow after making changes
to Swift source files under `Sources/`.

## Steps

### Step 1 — Gather system information

Run the following three commands and extract the values described below.

1. Run `system_profiler SPHardwareDataType` and extract:
   - **Model Name** (e.g. "MacBook Pro")
   - **Chip** (e.g. "Apple M1 Pro")
   - **Memory** (e.g. "16 GB")

2. Run `sw_vers` and extract:
   - **ProductVersion** (e.g. "15.7")

3. Run `swift --version` and extract the version number from the output
   (e.g. from "Swift version 6.2 ..." extract "6.2").

From these values, compose the following identifiers to use in all
subsequent baseline entries:

- **Short Machine ID** — for the CPU profiler test comment. Format:
  `MBP <Chip short> <Year> <Memory>`. Examples of existing values:
    - "MBP M1 Max 2021 32GB"
    - "MBP M4 Max 2024 48GB"
    - "MBP M1 Pro 2021 16GB"

  To construct this: take the Model Name abbreviation (e.g. "MBP" for
  "MacBook Pro"), the chip name without "Apple" prefix (e.g. "M1 Pro"),
  a year if identifiable, and memory without space (e.g. "16GB").

- **Long Machine ID** — for measure-based test comments. Format:
  `<Model Name> <Chip short>, <Memory> RAM`. Examples:
    - "MacBook Pro M1 Pro, 16GB RAM"
    - "MacBook Pro M4 Max, 48GB RAM"
    - "Apple M3, 16GB RAM"

- **OS** — format: `macOS <ProductVersion>` (e.g. "macOS 15.7").

- **Swift** — just the version number (e.g. "6.2").

- **Date** — today's date in "Mon DD, YYYY" format (e.g. "Mar 24, 2026").

### Step 2 — Run the CPU profiler test (`testPerformanceSingleRun`)

Run `make test-performance` from the repository root.

**Parse the output**: Find the line matching the pattern:

```text
XXX.XX Mc  XX.X%: ContentBlockerConverter.convertArray
```

This is the first line printed under `=== CPU Profiler Results ===`.
Extract the full line as-is — it will be used verbatim in the comment.

**If the command fails** (e.g. xctrace not available), report the error
and skip to Step 3. Do not abort the entire workflow.

### Step 3 — Run the measure-based performance tests

For each test listed below, run the command and parse the average time.

| # | Filter expression | File path |
| --- | --- | --- |
| 1 | `ContentBlockerConverterTests/testPerformance$` | `Tests/ContentBlockerConverterTests/ContentBlockerConverterPerformanceTests.swift` |
| 2 | `ContentBlockerConverterTests/testSpecifichidePerformance` | same as above |
| 3 | `FilterEngineSerializationTests/testPerformanceSerialization` | `Tests/FilterEngineTests/FilterEngineSerializationTests.swift` |
| 4 | `FilterEngineSerializationTests/testPerformanceDeserialization` | same as above |
| 5 | `ByteArrayTrieTests/testPerformanceBuildTrie` | `Tests/FilterEngineTests/Utils/ByteArrayTrieTests.swift` |
| 6 | `ByteArrayTrieTests/testPerformanceFind` | same as above |
| 7 | `ByteArrayTrieTests/testPerformanceCollectPayload` | same as above |
| 8 | `TrieNodeTests/testPerformanceBuildTrie` | `Tests/FilterEngineTests/Utils/TrieNodeTests.swift` |
| 9 | `TrieNodeTests/testPerformanceFind` | same as above |
| 10 | `TrieNodeTests/testPerformanceCollectPayload` | same as above |

For each test:

1. Run: `swift test --filter '<Filter expression>'`

2. **Parse the output**: Find the line containing `average:` and extract
   the numeric value. The line looks like:

   ```text
   ...average: 1.169, relative standard deviation: ...
   ```

   Extract the number after `average:` (e.g. "1.169"). Round to 3
   decimal places.

3. **If the test fails or the output cannot be parsed**, report the
   error and continue with the next test.

### Step 4 — Update baseline comments

For each test that produced a result, update the corresponding test
file. Before updating, check if a new entry is needed.

#### 4a — Tolerance check (skip if unchanged)

For **measure-based tests**: find the most recent baseline entry in the
test's doc comment that matches the current machine (by Long Machine ID).
If one exists and the new average is within **±5%** of the previous
value, **skip** the update for this test. Report that the result is
within tolerance.

For the **CPU profiler test**: find the most recent baseline entry under
the current machine's `// On <Short Machine ID>` group. If one exists
and the new Mc value is within **±3%** of the previous value, **skip**
the update. Report that the result is within tolerance.

If no previous baseline exists for this machine, always add a new entry.

#### 4b — Update `testPerformanceSingleRun` (CPU profiler format)

File:
`Tests/ContentBlockerConverterTests/ContentBlockerConverterPerformanceTests.swift`

Read the file and find the `testPerformanceSingleRun` function. Inside
its body, locate the block of `//` comments that contain CPU profiler
baselines.

- **If a group for the current machine already exists** (a line matching
  `// On <Short Machine ID>`), append a new entry at the end of that
  group, just before the next `// On ...` line or before the
  `let conversionResult` line. Use this format:

  ```swift
  //
  // <Date>
  // <CPU profiler result line verbatim from Step 2>
  ```

  If the change has a notable description (provided by the user or from
  git context), include it in parentheses after the date, e.g.:
  `// <Date> (description of change)`

- **If no group for the current machine exists**, add a new group block
  before the `let conversionResult` line:

  ```swift
  //
  // On <Short Machine ID>
  // CPU profiler result:
  //
  // <Date>
  // <CPU profiler result line verbatim from Step 2>
  ```

#### 4c — Update measure-based tests

For each measure-based test that has a new result:

1. Read the test file and find the test function.
2. Locate the doc comment block (`///` lines) immediately before the
   `func test...()` line.
3. Find the last `/// To get your machine info:` line in that doc
   comment — the new entry goes **before** that line.
4. Insert the new baseline entry in this exact format:

   ```swift
   /// Baseline results (<Date>):
   /// - Machine: <Long Machine ID>
   /// - OS: <OS>
   /// - Swift: <Swift>
   /// - Average execution time: ~<average> seconds
   ///
   ```

   Where `<average>` is the value from Step 3, formatted to 3 decimal
   places (e.g. "1.169").

### Step 5 — Report results

After all updates are complete, print a summary table:

```text
Performance Benchmark Results
=============================
Machine: <Long Machine ID>
OS: <OS>
Swift: <Swift>
Date: <Date>

Test                                          | Result        | Status
----------------------------------------------|---------------|--------
testPerformanceSingleRun                      | XXX.XX Mc XX% | Updated / Skipped / Failed
testPerformance                               | ~X.XXX sec    | Updated / Skipped / Failed
testSpecifichidePerformance                   | ~X.XXX sec    | Updated / Skipped / Failed
testPerformanceSerialization                  | ~X.XXX sec    | Updated / Skipped / Failed
testPerformanceDeserialization                | ~X.XXX sec    | Updated / Skipped / Failed
ByteArrayTrieTests/testPerformanceBuildTrie   | ~X.XXX sec    | Updated / Skipped / Failed
ByteArrayTrieTests/testPerformanceFind        | ~X.XXX sec    | Updated / Skipped / Failed
ByteArrayTrieTests/testPerformanceCollectPayload | ~X.XXX sec | Updated / Skipped / Failed
TrieNodeTests/testPerformanceBuildTrie        | ~X.XXX sec    | Updated / Skipped / Failed
TrieNodeTests/testPerformanceFind             | ~X.XXX sec    | Updated / Skipped / Failed
TrieNodeTests/testPerformanceCollectPayload   | ~X.XXX sec    | Updated / Skipped / Failed
```

Status meanings:

- **Updated** — new baseline entry added to the test file.
- **Skipped** — result within tolerance of previous baseline; no update.
- **Failed** — test failed or output could not be parsed.
