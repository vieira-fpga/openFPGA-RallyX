#!/usr/bin/env python3
import argparse
import concurrent.futures
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from _common import REPO_ROOT, Fail, ok, run, skip, step

# Modules outside src/fpga/rtl/ that testbenches reach into. Listed explicitly
# rather than globbed: core_top.v pulls in the PLL and the Analogizer, which
# would drag most of the project into every compile.
EXTRA_SOURCES = (
    "src/fpga/core/pocket_i2s.v",
    "src/fpga/core/nrx_hiscore.v",
    "src/fpga/apf/common.v",
)

# Quartus's own simulation model for altsyncram, which backs LINEBUF. Found ->
# the suite tests the real megafunction; not found -> sim/stubs.v supplies a
# behavioural stand-in instead and we say so.
ALTERA_MF = "quartus/eda/sim_lib/altera_mf.v"
QUARTUS_GLOBS = (
    "C:/intelFPGA_lite/*",
    "C:/intelFPGA/*",
    "~/intelFPGA_lite/*",
    "/opt/intelFPGA_lite/*",
)

# VHDL half of the suite. Icarus cannot read VHDL, so the T80 testbench runs
# under GHDL instead. winget puts ghdl.exe outside PATH until the shell is
# restarted, hence the package-dir glob.
# The LLVM-backed GHDL is listed first: it runs this design roughly an order of
# magnitude faster than mcode, which is the difference between zexdoc being an
# afternoon and being two days. Install it with
#   winget install MSYS2.MSYS2
#   C:\msys64\usr\bin\bash -lc "pacman -S mingw-w64-ucrt-x86_64-ghdl-llvm"
GHDL_GLOBS = (
    "C:/msys64/ucrt64/bin",
    "C:/msys64/mingw64/bin",
    "~/AppData/Local/Microsoft/WinGet/Packages/ghdl.ghdl*/bin",
    "C:/ghdl/bin",
    "/usr/local/bin",
)
# Analysis order matters in VHDL: the package first, the top last.
T80_SOURCES = (
    "src/fpga/rtl/cpu/T80_Pack.vhd",
    "src/fpga/rtl/cpu/T80_ALU.vhd",
    "src/fpga/rtl/cpu/T80_MCode.vhd",
    "src/fpga/rtl/cpu/T80_Reg.vhd",
    "src/fpga/rtl/cpu/T80.vhd",
    "src/fpga/rtl/cpu/T80s.vhd",
)
# --std=93 because T80 is VHDL-93; -fsynopsys for its non-standard IEEE
# packages; -fexplicit because T80 compares vectors with both std_logic_1164
# and std_logic_unsigned visible, an ambiguity Quartus resolves the same way;
# --syn-binding because T80's component is declared in a package, which GHDL's
# strict default binding refuses to resolve.
GHDL_FLAGS = ("--std=93", "-fsynopsys", "-fexplicit")
GHDL_ELAB_FLAGS = ("--syn-binding",)

# T80 at compiled speed: GHDL synthesises the VHDL to a Verilog netlist,
# Verilator turns that into C++, and sim/verilator/tb_t80.cpp drives it. This
# runs verilator_bin, Verilator's compiled half, and g++ directly rather than
# the `verilator` wrapper, whose generated make loses TMP on Windows when an
# MSYS2 make starts under another shell's runtime, and then cannot compile.
VERILATOR_GLOBS = (
    "C:/msys64/ucrt64/bin",
    "C:/msys64/mingw64/bin",
    "/usr/local/bin",
    "/usr/bin",
)
FUSE_TESTS = ".repos/fuse/z80/tests"
EXERCISERS = ".repos/z80-exercisers/roms"
Z80TEST = ".repos/z80test/z80test-1.2a"
# z80ccfscr draws a picture to compare by eye, so it is not run.
Z80TEST_TAPES = ("z80full", "z80doc", "z80flags", "z80docflags", "z80memptr", "z80ccf")
# The CPU test ROM, built by tools/build_test_rom.py. Its word at $0003 points
# at its test table.
CPU_TEST_ROM = "build/test-roms/zexall.bin"


def find_iverilog(override):
    if override:
        if not override.is_file():
            raise Fail(f"iverilog not found: {override}")
        return override
    found = shutil.which("iverilog")
    if not found:
        raise Fail(
            "Could not find iverilog. Install Icarus Verilog and put it on PATH, "
            "or pass --iverilog /path/to/iverilog"
        )
    return Path(found)


def find_altera_mf():
    env = os.environ.get("QUARTUS_ROOTDIR")
    if env:
        candidate = Path(env).parent / ALTERA_MF
        if candidate.is_file():
            return candidate
    found = []
    for pattern in QUARTUS_GLOBS:
        for install in glob.glob(os.path.expanduser(pattern)):
            candidate = Path(install) / ALTERA_MF
            if candidate.is_file():
                found.append(candidate)
    return max(found) if found else None


def sources(root):
    rtl = root / "src" / "fpga" / "rtl"
    files = sorted(rtl.glob("*.v"))
    if not files:
        raise Fail(f"No RTL found under {rtl}")

    for extra in EXTRA_SOURCES:
        path = root / extra
        if not path.is_file():
            raise Fail(f"Missing source: {path}")
        files.append(path)

    files.append(root / "sim" / "stubs.v")

    altera_mf = find_altera_mf()
    if altera_mf:
        step(f"altsyncram model: {altera_mf}")
        files.append(altera_mf)
        return files, []

    step("altsyncram model not found -- LINEBUF falls back to sim/stubs.v")
    files = [f for f in files if f.name != "LINEBUF.v"]
    return files, ["-DLINEBUF_STUB"]


def find_ghdl(override):
    if override:
        if not override.is_file():
            raise Fail(f"ghdl not found: {override}")
        return override
    found = shutil.which("ghdl")
    if found:
        return Path(found)
    exe = "ghdl.exe" if os.name == "nt" else "ghdl"
    for pattern in GHDL_GLOBS:
        for bindir in glob.glob(os.path.expanduser(pattern)):
            candidate = Path(bindir) / exe
            if candidate.is_file():
                return candidate
    return None


def ghdl_is_mcode(ghdl):
    """True for the mcode backend, which interprets instead of compiling.

    mcode elaborates as part of `ghdl -r`; the llvm and gcc backends need a
    separate `ghdl -e` that produces a real executable, and take their generic
    overrides there rather than at run time.
    """
    out = subprocess.run(
        [str(ghdl), "--version"], capture_output=True, text=True, check=False
    )
    return "mcode" in (out.stdout + out.stderr).lower()


def run_one_vhdl(ghdl, bench, root, workdir, image=None, max_cycles=None):
    """Analyse the T80 sources plus one VHDL bench, then run it.

    Runs from the repository root: tb_t80_exerciser opens its test image by a
    path relative to the root, so the working directory is load-bearing.
    """
    lib = workdir / bench.stem
    lib.mkdir(parents=True, exist_ok=True)
    srcs = [str(root / s) for s in T80_SOURCES] + [str(bench)]

    # A compiled bench links against the toolchain's DLLs but lands in a temp
    # directory, so GHDL's own bin has to be on PATH or it will not start.
    env = os.environ.copy()
    env["PATH"] = str(Path(ghdl).parent) + os.pathsep + env.get("PATH", "")

    built = subprocess.run(
        [str(ghdl), "-a", *GHDL_FLAGS, f"--workdir={lib}", *srcs],
        capture_output=True,
        text=True,
        check=False,
        cwd=str(root),
        env=env,
    )
    if built.returncode != 0:
        print(built.stdout, end="")
        print(built.stderr, end="", file=sys.stderr)
        return False

    # --image and --max-mcycles only apply to the bench that declares those
    # generics; passing them to any other bench is an elaboration error.
    generics = []
    if bench.stem == "tb_t80_exerciser":
        if image:
            generics.append(f"-gIMAGE={image}")
        if max_cycles:
            generics.append(f"-gMAX_MCYCLES={max_cycles}")

    mcode = ghdl_is_mcode(ghdl)
    if mcode:
        command = [
            str(ghdl),
            "-r",
            *GHDL_FLAGS,
            *GHDL_ELAB_FLAGS,
            f"--workdir={lib}",
            bench.stem,
            *generics,
            "--ieee-asserts=disable",
        ]
    else:
        exe = lib / f"{bench.stem}.exe"
        elaborated = subprocess.run(
            [
                str(ghdl),
                "-e",
                *GHDL_FLAGS,
                *GHDL_ELAB_FLAGS,
                f"--workdir={lib}",
                "-o",
                str(exe),
                *generics,
                bench.stem,
            ],
            capture_output=True,
            text=True,
            check=False,
            cwd=str(lib),
            env=env,
        )
        if elaborated.returncode != 0:
            print(elaborated.stdout, end="")
            print(elaborated.stderr, end="", file=sys.stderr)
            return False
        command = [str(exe), "--ieee-asserts=disable"]

    # Streamed rather than captured. A zexdoc run is measured in hours, and
    # buffering it to the end means no progress while it runs and nothing at all
    # if it is interrupted. stderr is folded in because GHDL's `report` goes
    # there, and keeping one pipe keeps the lines in order.
    #
    # GHDL prefixes each report with file:line:col:@time:(level): -- matched
    # non-greedily, because on Windows the path contains a drive colon.
    prefix = re.compile(r"^.*?:\d+:\d+:@[^:]*:\([^)]*\): ?")
    proc = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        cwd=str(root),
        env=env,
    )

    saw_fail = False
    for line in proc.stdout:
        if "FAIL" in line:
            saw_fail = True
        print(prefix.sub("", line).rstrip(), flush=True)
    proc.wait()

    return proc.returncode == 0 and not saw_fail


def find_verilator():
    exe = ".exe" if os.name == "nt" else ""
    for pattern in VERILATOR_GLOBS:
        for bindir in glob.glob(os.path.expanduser(pattern)):
            verilator = Path(bindir) / f"verilator_bin{exe}"
            gxx = Path(bindir) / f"g++{exe}"
            root = Path(bindir).parent / "share" / "verilator"
            if verilator.is_file() and gxx.is_file() and root.is_dir():
                return verilator, gxx, root
    return None


def build_t80_model(ghdl, verilator, root, workdir):
    verilator_bin, gxx, verilator_root = verilator
    lib = workdir / "t80_lib"
    obj = workdir / "t80_obj"
    lib.mkdir(parents=True, exist_ok=True)
    netlist = workdir / "t80s.v"
    exe = workdir / ("tb_t80.exe" if os.name == "nt" else "tb_t80")

    env = os.environ.copy()
    env["PATH"] = os.pathsep.join(
        [str(Path(ghdl).parent), str(gxx.parent), env.get("PATH", "")]
    )
    env["VERILATOR_ROOT"] = str(verilator_root)
    include = verilator_root / "include"

    steps = (
        [str(ghdl), "-a", *GHDL_FLAGS, f"--workdir={lib}"]
        + [str(root / s) for s in T80_SOURCES],
        # T2Write => 0, as fpga_nrx.v instantiates it.
        [str(ghdl), "--synth", *GHDL_FLAGS, *GHDL_ELAB_FLAGS, f"--workdir={lib}"]
        + ["-gT2Write=0", "--out=verilog", "T80s"],
        [str(verilator_bin), "--cc", "-O3", "--prefix", "Vt80s"]
        + ["--top-module", "T80s", "-Wno-fatal", "-Wno-lint", "-Wno-style"]
        + [str(netlist), "--Mdir", str(obj)],
    )
    for command in steps:
        out = subprocess.run(
            command, capture_output=True, text=True, env=env, check=False
        )
        if out.returncode != 0:
            print(out.stdout + out.stderr, file=sys.stderr)
            raise Fail(f"T80 model build failed at: {Path(command[0]).name}")
        if "--synth" in command:
            netlist.write_text(out.stdout)

    sources = sorted(str(f) for f in obj.glob("*.cpp")) + [
        str(include / "verilated.cpp"),
        str(include / "verilated_threads.cpp"),
        str(root / "sim" / "verilator" / "tb_t80.cpp"),
    ]
    command = [str(gxx), "-O2", "-std=c++17", "-w", f"-I{obj}", f"-I{include}"]
    command += [f"-I{include / 'vltstd'}", *sources, "-o", str(exe)]
    out = subprocess.run(command, capture_output=True, text=True, env=env, check=False)
    if out.returncode != 0:
        print(out.stdout + out.stderr, file=sys.stderr)
        raise Fail("T80 model build failed at: g++")
    return exe, env


def exerciser_count(image):
    # zexdoc and zexall open with JP start; 12 bytes into start, LD HL,tests
    # loads a zero-terminated table of test pointers. tb_t80.cpp reads it the
    # same way to run one entry.
    mem = bytearray(0x100) + image.read_bytes()
    start = mem[0x101] | mem[0x102] << 8
    table = mem[start + 13] | mem[start + 14] << 8
    count = 0
    while mem[table + 2 * count] or mem[table + 2 * count + 1]:
        count += 1
    return count


def t80_runs(root, exercisers):
    fuse = root / FUSE_TESTS
    runs = [
        ("FUSE", ["fuse", str(fuse / "tests.in"), str(fuse / "tests.expected")]),
        ("prelim", ["cpm", str(root / EXERCISERS / "prelim.com")]),
    ]
    if not exercisers:
        return runs

    for tape in Z80TEST_TAPES:
        runs.append((tape, ["tap", str(root / Z80TEST / f"{tape}.tap")]))
    for name in ("zexdoc", "zexall"):
        image = root / EXERCISERS / f"{name}.cim"
        if not image.is_file():
            runs.append((name, ["cpm", str(image)]))
            continue
        for index in range(exerciser_count(image)):
            runs.append(
                (f"{name} {index:2d}", ["cpm", str(image), "--test", str(index)])
            )

    rom = root / CPU_TEST_ROM
    if not rom.is_file():
        skip(f"{CPU_TEST_ROM} not built, so the CPU test ROM is not run")
        return runs
    data = rom.read_bytes()
    table = data[3] | data[4] << 8
    count = 0
    while data[table + 2 * count] or data[table + 2 * count + 1]:
        count += 1
    for index in range(count):
        runs.append(
            (f"test ROM {index:2d}", ["rallyx", str(rom), "--test", str(index)])
        )
    return runs


def run_t80_model(ghdl, verilator, root, workdir, exercisers):
    step("T80 model: GHDL synth -> Verilator -> g++")
    exe, env = build_t80_model(ghdl, verilator, root, workdir)
    runs = t80_runs(root, exercisers)
    step(f"T80 model: {len(runs)} run(s)")

    def one(run):
        name, args = run
        out = subprocess.run(
            [str(exe), *args],
            capture_output=True,
            text=True,
            errors="replace",
            env=env,
            cwd=str(root),
            check=False,
        )
        return name, out.returncode == 0, out.stdout + out.stderr

    # The runs are independent, so they share the machine's cores. Each prints
    # its verdict on one line; a failing run's whole output follows it.
    failed = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=os.cpu_count()) as pool:
        for name, passed, output in pool.map(one, runs):
            verdict = [
                line
                for line in output.splitlines()
                if line.startswith(("PASS", "FAIL"))
            ]
            print(f"  {name:10s} {verdict[-1] if verdict else 'no verdict'}")
            if not passed:
                failed += 1
                print(output)
    return failed == 0


def discover(sim_dir, only):
    benches = (
        sorted(sim_dir.glob("tb_*.v"))
        + sorted((sim_dir / "vhdl").glob("tb_*.vhd"))
        + sorted((sim_dir / "verilator").glob("tb_*.cpp"))
    )
    if not benches:
        raise Fail(f"No testbenches found under {sim_dir}")
    if not only:
        return benches
    wanted = [b for b in benches if only in b.stem]
    if not wanted:
        known = ", ".join(b.stem for b in benches)
        raise Fail(f"No testbench matching '{only}'. Known: {known}")
    return wanted


def run_one(iverilog, bench, srcs, defines, sim_dir, workdir):
    vvp_out = workdir / f"{bench.stem}.vvp"
    compile_cmd = [
        str(iverilog),
        "-g2012",
        "-I",
        str(sim_dir),
        "-s",
        bench.stem,
        "-o",
        str(vvp_out),
        *defines,
        str(bench),
        *[str(s) for s in srcs],
    ]
    built = subprocess.run(compile_cmd, capture_output=True, text=True, check=False)
    if built.returncode != 0:
        print(built.stdout, end="")
        print(built.stderr, end="", file=sys.stderr)
        return False

    result = subprocess.run(
        ["vvp", str(vvp_out)], capture_output=True, text=True, check=False
    )
    print(result.stdout, end="")
    if result.stderr.strip():
        print(result.stderr, end="", file=sys.stderr)

    # the testbenches report their own verdict; trust it over the exit code,
    # which vvp leaves at 0 even when $display printed failures
    return result.returncode == 0 and "FAIL" not in result.stdout


def simulate(
    root, only, iverilog, ghdl_path, image=None, max_cycles=None, exercisers=False
):
    sim_dir = root / "sim"
    iverilog = find_iverilog(iverilog)
    step(f"Icarus: {iverilog}")

    ghdl = find_ghdl(ghdl_path)
    if ghdl:
        step(f"GHDL: {ghdl}")
    else:
        step("GHDL not found — VHDL testbenches will be skipped")

    verilator = find_verilator()
    if verilator:
        step(f"Verilator: {verilator[0]}")
    else:
        step("Verilator not found, so the T80 model run is skipped")

    srcs, defines = sources(root)
    benches = discover(sim_dir, only)
    step(f"Running {len(benches)} testbench(es)")
    print()

    passed, failed, skipped = [], [], []
    with tempfile.TemporaryDirectory(prefix="rallyx-sim-") as tmp:
        for bench in benches:
            if bench.suffix == ".cpp":
                if ghdl is None or verilator is None:
                    step(f"{bench.stem}: SKIPPED, needs both GHDL and Verilator")
                    skipped.append(bench.stem)
                    print()
                    continue
                ok_run = run_t80_model(ghdl, verilator, root, Path(tmp), exercisers)
            elif bench.suffix == ".vhd":
                if ghdl is None:
                    step(f"{bench.stem}: SKIPPED — ghdl not found (VHDL bench)")
                    skipped.append(bench.stem)
                    print()
                    continue
                ok_run = run_one_vhdl(ghdl, bench, root, Path(tmp), image, max_cycles)
            else:
                ok_run = run_one(iverilog, bench, srcs, defines, sim_dir, Path(tmp))
            if ok_run:
                passed.append(bench.stem)
            else:
                failed.append(bench.stem)
            print()

    tail = f", {len(skipped)} skipped" if skipped else ""
    step(f"{len(passed)} passed, {len(failed)} failed{tail}")
    for name in passed:
        ok(f"pass  {name}")
    for name in failed:
        print(f"    fail  {name}")
    for name in skipped:
        print(f"    skip  {name}")

    if failed:
        raise Fail(f"{len(failed)} testbench(es) failed")


def main():
    parser = argparse.ArgumentParser(
        description="Run the Icarus Verilog timing testbenches under sim/."
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=REPO_ROOT,
        help="repository root (default: %(default)s)",
    )
    parser.add_argument(
        "--test", help="run only testbenches whose name contains this substring"
    )
    parser.add_argument(
        "--iverilog", type=Path, help="path to iverilog (default: autodetect)"
    )
    parser.add_argument(
        "--ghdl",
        type=Path,
        help="path to ghdl for the VHDL benches (default: autodetect)",
    )
    parser.add_argument(
        "--image",
        help=(
            "test image for tb_t80_exerciser, relative to the repo root "
            "(default: prelim.com; try .repos/z80-exercisers/roms/zexdoc.cim)"
        ),
    )
    parser.add_argument(
        "--max-mcycles",
        type=int,
        help=(
            "cycle budget for tb_t80_exerciser, in MILLIONS of T-states "
            "(default: the bench's own 40)"
        ),
    )
    parser.add_argument(
        "--exercisers",
        action="store_true",
        help=(
            "also run z80test and every zexdoc and zexall entry against the "
            "T80 model, spread across all cores (tens of minutes)"
        ),
    )
    args = parser.parse_args()
    simulate(
        args.root,
        args.test,
        args.iverilog,
        args.ghdl,
        args.image,
        args.max_mcycles,
        args.exercisers,
    )


if __name__ == "__main__":
    run(main)
