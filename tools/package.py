#!/usr/bin/env python3
import argparse
import json
import shutil
import zipfile
from pathlib import Path

from _common import REPO_ROOT, Fail, ok, run, step

BIT_REVERSE = bytes(int(f"{value:08b}"[::-1], 2) for value in range(256))


def read_metadata(root):
    core_json = root / "core.json"
    if not core_json.is_file():
        raise Fail(f"Core definition not found: {core_json}")
    meta = json.loads(core_json.read_text(encoding="utf-8"))["core"]["metadata"]
    return meta


def copy_into(src, dest_dir):
    if not src.is_file():
        raise Fail(f"Missing file: {src}")
    shutil.copy2(src, dest_dir / src.name)


def write_zip(release, zip_path):
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(release.rglob("*")):
            name = path.relative_to(release).as_posix()
            if path.is_dir():
                if not any(path.iterdir()):
                    archive.writestr(name + "/", "")
            else:
                archive.write(path, name)


def package(root, sd_root, make_zip):
    meta = read_metadata(root)
    platform = meta["platform_ids"][0]
    core_name = f"{meta['author']}.{meta['shortname']}"

    fpga_out = root / "src/fpga/output_files/ap_core.rbf"
    dist = root / "dist"
    release = root / "release"

    if not fpga_out.is_file():
        raise Fail(f"Bitstream not found: {fpga_out}  (compile in Quartus first)")

    step("Building SD layout under release/")
    if release.exists():
        shutil.rmtree(release)
    core_dir = release / "Cores" / core_name
    plat_dir = release / "Platforms"
    plat_img = plat_dir / "_images"
    asset_dir = release / "Assets" / platform / "common"
    for path in (core_dir, plat_img, asset_dir):
        path.mkdir(parents=True)

    step("Reversing bitstream -> bitstream.rbf_r")
    bitstream = fpga_out.read_bytes().translate(BIT_REVERSE)
    (core_dir / "bitstream.rbf_r").write_bytes(bitstream)

    for src in sorted(root.glob("*.json")):
        copy_into(src, core_dir)
    copy_into(root / "info.txt", core_dir)
    copy_into(dist / "icon.bin", core_dir)
    copy_into(dist / "platforms" / f"{platform}.json", plat_dir)
    plat_bin = dist / "platforms" / "_images" / f"{platform}.bin"
    if plat_bin.is_file():
        copy_into(plat_bin, plat_img)

    # The instance JSONs, one per game. Updaters such as pupdate read the ROM
    # filenames out of them to fetch the ROMs.
    shutil.copytree(dist / "assets", release / "Assets", dirs_exist_ok=True)

    ok(f"Core folder: Cores/{core_name}")
    ok(f"Bitstream:   {len(bitstream)} bytes")

    if sd_root:
        step(f"Copying to SD card: {sd_root}")
        if not sd_root.is_dir():
            raise Fail(f"SD path not found: {sd_root}")
        shutil.copytree(release, sd_root, dirs_exist_ok=True)
        ok(f"Copied to {sd_root}")

    if make_zip:
        zip_path = root / f"{core_name}_{meta['version']}_{meta['date_release']}.zip"
        step(f"Zipping release -> {zip_path.name}")
        zip_path.unlink(missing_ok=True)
        write_zip(release, zip_path)
        ok(f"Wrote {zip_path.name}")

    step("Done.")


def main():
    parser = argparse.ArgumentParser(
        description="Bit-reverse the bitstream and assemble the Pocket SD layout."
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=REPO_ROOT,
        help="repository root (default: %(default)s)",
    )
    parser.add_argument(
        "--sd-root", type=Path, help="also copy the layout onto this SD card root"
    )
    parser.add_argument(
        "--zip", action="store_true", help="write a distributable release archive"
    )
    args = parser.parse_args()
    package(args.root, args.sd_root, args.zip)


if __name__ == "__main__":
    run(main)
