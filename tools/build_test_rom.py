#!/usr/bin/env python3
import argparse
import glob
import os
import pathlib
import subprocess
import tempfile

import build_rom
from _common import REPO_ROOT, Fail, run, step

# Test ROMs replace the game's program ROM, $0000-$3FFF, and keep the rest of
# the core ROM image: the character ROM, the colour PROMs and the wave ROM.
PROGRAM_SIZE = 0x4000
SOURCE = "roms/cpu/zexall.s"
OUT_DIR = "build/test-roms"

# sdasz80 and sdldz80 come with SDCC. On Windows, MSYS2 has them:
#   C:\msys64\usr\bin\bash -lc "pacman -S mingw-w64-ucrt-x86_64-sdcc"
SDCC_GLOBS = (
    "C:/msys64/ucrt64/bin",
    "C:/msys64/mingw64/bin",
    "/usr/local/bin",
    "/usr/bin",
)


def find_tool(name: str) -> pathlib.Path:
    exe = f"{name}.exe" if os.name == "nt" else name
    for pattern in SDCC_GLOBS:
        for bindir in glob.glob(os.path.expanduser(pattern)):
            candidate = pathlib.Path(bindir) / exe
            if candidate.is_file():
                return candidate
    raise Fail(f"Could not find {name}. Install SDCC, which provides it.")


def parse_ihx(text: str) -> bytes:
    program = bytearray(b"\xff" * PROGRAM_SIZE)
    for line in text.splitlines():
        if not line.startswith(":"):
            continue
        record = bytes.fromhex(line[1:])
        length, address, kind = record[0], record[1] << 8 | record[2], record[3]
        if kind != 0:
            continue
        if address + length > PROGRAM_SIZE:
            raise Fail(f"Program runs past the ROM at ${address:04X}")
        program[address : address + length] = record[4 : 4 + length]
    return bytes(program)


def assemble(source: pathlib.Path) -> bytes:
    assembler = find_tool("sdasz80")
    linker = find_tool("sdldz80")
    env = os.environ.copy()
    env["PATH"] = str(assembler.parent) + os.pathsep + env.get("PATH", "")

    with tempfile.TemporaryDirectory(prefix="rallyx-rom-") as tmp:
        work = pathlib.Path(tmp)
        rel = work / f"{source.stem}.rel"
        ihx = work / f"{source.stem}.ihx"
        commands = (
            [str(assembler), "-o", "-l", str(rel), str(source)],
            [str(linker), "-i", str(ihx), str(rel)],
        )
        for command in commands:
            out = subprocess.run(
                command, capture_output=True, text=True, env=env, check=False
            )
            if out.returncode != 0 or "Error" in out.stdout + out.stderr:
                print(out.stdout + out.stderr)
                raise Fail(f"{pathlib.Path(command[0]).name} failed on {source}")
        return parse_ihx(ihx.read_text())


def core_image(zip_path: pathlib.Path, program: bytes) -> tuple[str, bytes]:
    if not zip_path.is_file():
        raise Fail(f"ROM zip not found: {zip_path}")
    members = build_rom.read_members(zip_path)
    setname = build_rom.identify(members)
    image = build_rom.assemble(zip_path, members, setname)
    return setname, program + image[PROGRAM_SIZE:]


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Assemble the CPU test ROM, roms/cpu/zexall.s. With --zip, also "
            "build a core ROM image that runs it in place of the game."
        )
    )
    parser.add_argument(
        "--zip",
        type=pathlib.Path,
        help="MAME rallyx.zip or nrallyx.zip, for the graphics and sound ROMs",
    )
    args = parser.parse_args()

    out_dir = REPO_ROOT / OUT_DIR
    out_dir.mkdir(parents=True, exist_ok=True)

    program = assemble(REPO_ROOT / SOURCE)
    program_path = out_dir / "zexall.bin"
    program_path.write_bytes(program)
    step(f"Wrote {program_path} ({len(program)} bytes)")

    if args.zip:
        setname, image = core_image(args.zip, program)
        image_path = out_dir / f"{setname}.rom"
        image_path.write_bytes(image)
        step(f"Wrote {image_path} ({len(image)} bytes), the zexall ROM for {setname}")


if __name__ == "__main__":
    run(main)
