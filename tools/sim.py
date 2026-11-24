#!/usr/bin/env python3
import argparse
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from _common import REPO_ROOT, Fail, ok, run, step

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


def discover(sim_dir, only):
    benches = sorted(sim_dir.glob("tb_*.v")) + sorted(
        (sim_dir / "vhdl").glob("tb_*.vhd")
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


def simulate(root, only, iverilog, ghdl_path, image=None, max_cycles=None):
    sim_dir = root / "sim"
    iverilog = find_iverilog(iverilog)
    step(f"Icarus: {iverilog}")

    ghdl = find_ghdl(ghdl_path)
    if ghdl:
        step(f"GHDL: {ghdl}")
    else:
        step("GHDL not found — VHDL testbenches will be skipped")

    srcs, defines = sources(root)
    benches = discover(sim_dir, only)
    step(f"Running {len(benches)} testbench(es)")
    print()

    passed, failed, skipped = [], [], []
    with tempfile.TemporaryDirectory(prefix="rallyx-sim-") as tmp:
        for bench in benches:
            if bench.suffix == ".vhd":
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
    args = parser.parse_args()
    simulate(
        args.root, args.test, args.iverilog, args.ghdl, args.image, args.max_mcycles
    )


if __name__ == "__main__":
    run(main)
