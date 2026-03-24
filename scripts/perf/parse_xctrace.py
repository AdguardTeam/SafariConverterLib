#!/usr/bin/env python3
"""Parse xctrace CPU Profiler trace and extract CORE_ACTIVE_CYCLE counts
for a target function.

Usage:
    python3 scripts/perf/parse_xctrace.py <trace_file> [<binary_path>] \
        [function_name]

    trace_file    — path to an .trace file (recorded with CPU Profiler)
    binary_path   — (optional) path to the test binary (.xctest bundle
                    MacOS binary). If omitted the script discovers it
                    from the cpu-profile schema.
    function_name — (optional) substring to match, default "convertArray"

The script:
  1. Exports the cpu-profile schema to discover the target binary
     (name, load-addr) and resolve the target function address.
  2. Exports the kdebug-counters-with-pmi-sample schema (PMI data,
     each sample = 1 Mc of CORE_ACTIVE_CYCLE).
  3. Collects unique callstack addresses for the xctest process.
  4. Batch-symbolicates them with atos.
  5. Counts PMI samples whose callstack contains the target function.
"""

import os
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET


def export_schema(trace_path, schema, extra_attrs=""):
    """Export a schema from an xctrace .trace file and return the XML root."""
    tmp = tempfile.NamedTemporaryFile(suffix=".xml", delete=False)
    tmp.close()
    xpath = (
        f'/trace-toc/run[@number="1"]'
        f'/data/table[@schema="{schema}"'
        f"{extra_attrs}]"
    )
    subprocess.run(
        ["xctrace", "export",
         "--input", trace_path,
         "--xpath", xpath,
         "--output", tmp.name],
        check=True,
        capture_output=True,
    )
    tree = ET.parse(tmp.name)
    os.unlink(tmp.name)
    return tree.getroot()


def find_binary_info(cpu_root, target):
    """From the cpu-profile XML find the binary that contains *target*.

    Returns (binary_path, load_addr_hex) or (None, None).
    """
    # Collect all binaries by id.
    binaries = {}
    for b in cpu_root.iter("binary"):
        bid = b.get("id")
        if bid:
            binaries[bid] = b

    # Find a frame whose name contains the target function.
    for frame in cpu_root.iter("frame"):
        name = frame.get("name", "")
        if target not in name:
            continue
        # The <binary> child may be inline or a ref.
        for b in frame.iter("binary"):
            ref = b.get("ref")
            actual = binaries.get(ref) if ref else b
            if actual is not None:
                path = actual.get("path")
                load = actual.get("load-addr")
                if path and load:
                    return path, load
    return None, None


def build_ref_map(root):
    """Build a global id → element map for ref resolution.

    xctrace XML reuses elements via id/ref attributes. An element
    like ``<kperf-bt ref="98"/>`` means "same as the element with
    id=98". This function collects every element that has an ``id``
    attribute so we can resolve refs later.
    """
    ref_map = {}
    for el in root.iter():
        eid = el.get("id")
        if eid is not None:
            ref_map[eid] = el
    return ref_map


def resolve(el, ref_map):
    """Return the actual element, following a single ref indirection."""
    ref = el.get("ref")
    if ref and ref in ref_map:
        return ref_map[ref]
    return el


def extract_addrs_from_bt(bt, ref_map):
    """Extract PC + stack addresses from a (possibly ref'd) kperf-bt."""
    bt = resolve(bt, ref_map)
    addrs = []

    # text-address (singular) — the sampled PC.
    for ta in bt.findall("text-address"):
        ta = resolve(ta, ref_map)
        if ta.text:
            try:
                a = int(ta.text)
                if a != 0:
                    addrs.append(a)
            except ValueError:
                pass

    # text-addresses (plural) — return addresses on the stack.
    for ta in bt.findall("text-addresses"):
        ta = resolve(ta, ref_map)
        if ta.text:
            for tok in ta.text.strip().split():
                try:
                    a = int(tok)
                    if a != 0:
                        addrs.append(a)
                except ValueError:
                    pass

    return addrs


def parse_pmi_samples(pmi_root, ref_map):
    """Parse PMI rows and return (xctest_rows, total_rows).

    Each xctest_row is a list of int addresses from the callstack.
    """
    # Build process id→name and thread id→process-id maps.
    procs = {}
    for p in pmi_root.iter("process"):
        pid = p.get("id")
        name = p.get("fmt", "")
        if pid:
            procs[pid] = name

    threads = {}
    for t in pmi_root.iter("thread"):
        tid = t.get("id")
        if tid is None:
            continue
        for p in t.iter("process"):
            actual_p = resolve(p, ref_map)
            ref = actual_p.get("id") or p.get("ref")
            if ref:
                threads[tid] = ref
                break

    # Find xctest process id.
    xctest_id = None
    for pid, name in procs.items():
        if "xctest" in name:
            xctest_id = pid
            break
    if xctest_id is None:
        sys.exit("Error: xctest process not found in PMI data.")

    xctest_rows = []
    total = 0
    for row in pmi_root.iter("row"):
        total += 1
        # Resolve thread → process.
        thread_el = row.find("thread")
        if thread_el is None:
            continue
        thread_el = resolve(thread_el, ref_map)
        tref = thread_el.get("ref") or thread_el.get("id")
        proc_id = threads.get(tref)
        if proc_id != xctest_id:
            continue

        # Collect addresses from kperf-bt (with ref resolution).
        addrs = []
        for bt in row.findall("kperf-bt"):
            addrs = extract_addrs_from_bt(bt, ref_map)
        xctest_rows.append(addrs)

    return xctest_rows, total


def symbolicate(binary_path, load_addr_hex, addresses):
    """Batch-symbolicate *addresses* with atos -i (inline frames).

    Returns a dict mapping int(addr) → list of symbolicated lines.
    With -i, each address may produce multiple lines (inline chain);
    blank lines in atos output separate groups.
    """
    if not addresses:
        return {}
    sorted_addrs = sorted(addresses)
    hex_input = "\n".join(hex(a) for a in sorted_addrs) + "\n"
    result = subprocess.run(
        ["atos", "-i", "-o", binary_path, "-l", load_addr_hex],
        input=hex_input,
        capture_output=True,
        text=True,
    )

    # Split output into groups separated by blank lines.
    groups = []
    current = []
    for line in result.stdout.splitlines():
        if line.strip() == "":
            if current:
                groups.append(current)
                current = []
        else:
            current.append(line)
    if current:
        groups.append(current)

    symbols = {}
    for addr, group in zip(sorted_addrs, groups):
        symbols[addr] = group
    return symbols


def main():
    if len(sys.argv) < 2:
        sys.exit(
            "Usage: parse_xctrace.py <trace_file> "
            "[binary_path] [function_name]"
        )

    trace_path = sys.argv[1]
    binary_override = None
    target = "convertArray"

    if len(sys.argv) >= 3 and os.path.exists(sys.argv[2]):
        binary_override = sys.argv[2]
    if len(sys.argv) >= 4:
        target = sys.argv[3]
    elif len(sys.argv) >= 3 and not os.path.exists(sys.argv[2]):
        target = sys.argv[2]

    # 1. Discover the binary from the cpu-profile schema.
    cpu_root = export_schema(trace_path, "cpu-profile")
    binary_path, load_addr = find_binary_info(cpu_root, target)
    if binary_override:
        binary_path = binary_override
    if binary_path is None or load_addr is None:
        sys.exit(
            f"Error: could not find binary info for '{target}' "
            "in cpu-profile data."
        )

    # 2. Export and parse PMI data.
    pmi_root = export_schema(
        trace_path,
        "kdebug-counters-with-pmi-sample",
    )
    ref_map = build_ref_map(pmi_root)
    xctest_rows, total_pmi = parse_pmi_samples(pmi_root, ref_map)

    # 3. Collect unique addresses and symbolicate.
    unique_addrs = set()
    for row_addrs in xctest_rows:
        unique_addrs.update(row_addrs)

    symbols = symbolicate(binary_path, load_addr, unique_addrs)

    # Build a set of addresses that belong to the target function.
    # With -i, each address maps to a list of lines (inline chain).
    target_addrs = set()
    for addr, lines in symbols.items():
        if any(target in line for line in lines):
            target_addrs.add(addr)

    # 4. Count PMI samples that contain the target.
    target_samples = 0
    for row_addrs in xctest_rows:
        if target_addrs.intersection(row_addrs):
            target_samples += 1

    xctest_total = len(xctest_rows)
    mc = target_samples
    pct = (target_samples / xctest_total * 100) if xctest_total else 0

    # Find the full function name from the symbols.
    func_name = target
    for lines in symbols.values():
        for line in lines:
            if target in line:
                # Strip " (in Binary) (file:line)" suffix.
                func_name = line.split(" (in ")[0]
                break
        if func_name != target:
            break

    print(f"{mc:.2f} Mc  {pct:.1f}%: {func_name}")
    print(f"Total: {xctest_total:.2f} Mc")


if __name__ == "__main__":
    main()
