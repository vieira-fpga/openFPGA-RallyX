# openFPGA-RallyX

An Analogue Pocket core that plays both Rally-X and New Rally-X.

## A note from morgan-vieira

I like ambitious ideas, simple systems, and software that feels obvious. Do not preserve complexity just because it already exists. Do not introduce machinery because it looks architecturally impressive. Understand the real constraint, then fight for the smallest model that makes the correct behavior unsurprising.

Channel both "measure twice, cut once" and "yagni". Fight scope creep. Try to honor the dev's intent in both a minimal and realistic fashion.

The rest of this document is meant to help you navigate the codebase and make changes effectively. Think of these instructions less as "hard rules", more as "good defaults". The developer's preferences should be able to override anything here.

## A small glossary

We need to be on the same page with terminology. When communicating, use this language:

- **you** means the agent reading this file and helping build the core.
- **we, us, and maintainers** mean morgan-vieira and the people building this core. These are who you are talking to now.
- **user** means the person using this core to play Rally-X on an Analogue Pocket.
- **modules** mean the individual Verilog/SystemVerilog building blocks that make up the core.

## The slow route

Modules are where this core gets built, and modules are where we refuse to rush. A module that compiles is not a module that works, and a simulation that passes is not a Pocket that boots.

Three tools, three jobs. **Icarus Verilog** simulates the Verilog modules. **GHDL** simulates the VHDL ones, which in practice means the T80 CPU - Icarus cannot read VHDL, so the Z80's cycle timing would otherwise be untestable. **Quartus Prime Lite 21.1** synthesises the bitstream, and is the only one of the three that produces something you can put on a Pocket. `python tools/sim.py` drives both simulators and skips the VHDL half with a note if GHDL is missing; `python tools/build.py` drives Quartus.

Every module takes the slow route, in order, every time:

1. **Prove it in simulation first.** Write a testbench and run it under Icarus Verilog - or GHDL, if the module is VHDL - before the module goes anywhere near Quartus. Exercise the ports, the edge cases, and the timing you are least sure about. Synthesis checks that a module is legal, not that it is right.
2. **Build the ROM that proves it.** Every module gets its own test ROM, built for that module's specific requirement — the video timing module gets a ROM that stresses sync and refresh, the VSU gets a ROM that plays known tones. A commercial game exercises everything at once and proves nothing in particular.
3. **Name the ROM.** When you hand a module over for testing, say exactly which ROM to load and exactly what a pass looks like on the Pocket — what should show on screen, what should come out of the speaker, and what a failure looks like instead. "Load something and see" is not an instruction.
4. **Ask for the hardware test, always.** You cannot see the Pocket's screen. Only the real bitstream on real hardware counts, and only a maintainer can watch it run. Ask for the test, wait for the verdict, and treat a clean simulation as a status update, not a conclusion. No module is done until a maintainer has watched it behave on the Pocket.

The same road, walked backwards, is how we diagnose. When a user reports a game misbehaving, resist the urge to patch the core and re-test the whole game. Isolate the symptom to a module, build or pick the test ROM that reproduces just that behavior, prove the fix in simulation, and ask for hardware again. A bug you can only reproduce inside a commercial game is a bug you have not yet found.

## Where code lives

- `src/fpga/` - the Quartus project (Quartus Prime Lite 21.1, Cyclone V `5CEBA4`). `ap_core.qsf` is the source manifest: a module that is not listed there is not in the build, no matter where the file sits.
- `src/fpga/apf/` - Analogue's APF framework and the real top level, `apf_top`. Vendor code, and the one part every Pocket core shares. Don't touch it.
- `src/fpga/core/` - our glue between APF and the game: `core_top.v` (the module APF instantiates), `core_bridge_cmd.v` for the host bridge, `data_loader.sv` for ROM download, `pocket_i2s.v` for audio, `mf_pllbase` for clocks. Pocket-side work belongs here.
- `src/fpga/rtl/` - the Rally-X arcade hardware, inherited from the MiSTer core. `fpga_nrx.v` on top, then video, sprite, sound, bang, rams, linebuf, hvgen. Keep it as close to upstream as the port allows; drift here is how the game stops being the game.
- `src/fpga/rtl/cpu/` - the T80 Z80 core, third-party VHDL. Vendored unmodified, which is not the same as taken on trust. `sim/vhdl/` measures its instruction timing prefixed and unprefixed, its mode 0 interrupt handshake, and its actual results and flags against the canonical Z80 exercisers - whose expected values come from real hardware rather than from our reading of the datasheet. It is the one module we cannot fix, so it is the one we check hardest.
- `src/fpga/analogizer/` - Analogizer adapter support: analog video out and SNAC controllers over the cartridge port. Third-party, from RndMnkIII's Analogizer project rather than Analogue, with its own manifest `analogizer.qip`. Vendor code - keep it close to upstream and resist refactoring it. No maintainer owns the adapter, a CRT, or the SNAC harnesses, so we cannot verify the video modes or controller types: route those bug reports upstream instead of guessing at fixes here. What we do own is the hook block at the bottom of `core_top.v`, the `Enable Analogizer` menu entry, and `cartridge_adapter` in `core.json` - which turns cart power on for every user, adapter or not.
- `*.json` and `info.txt` at the repo root - the Pocket core definition files. Menu entries, dip switches, video modes, and ROM slots are declared here, not in RTL. `docs/analogue/core-definition-files/` is the spec. The exception is `updaters.json`, which the Pocket ignores: the openFPGA library reads it, and its `declare_ai` list tells updaters such as pupdate that this core was written with AI.
- `dist/` - the hand-authored half of the SD payload: core icon and platform art. `tools/package.py` merges it with the compiled bitstream into `release/`.
- `sim/` - Icarus Verilog testbenches, one per module, asserting the timing against the Namco board's numbers. `check.vh` holds the shared assertions; `stubs.v` supplies an inert `T80s` for the Verilog benches. The Z80's own cycle timing is tested in `sim/vhdl/` under GHDL, which `tools/sim.py` runs alongside Icarus. Read `sim/README.md` before adding one - it covers the uninitialized dividers every testbench has to force, and what is deliberately not tested. Run them all with `python tools/sim.py`, or one with `--test <name>`. Never listed in `ap_core.qsf` - simulation only.
- `tools/` - Python 3, one job per script: `sync.py` (fetch reference cores), `build_rom.py` (assemble `rallyx.rom` or `nrallyx.rom` from a MAME set), `sim.py` (run the `sim/` testbenches), `build.py` (headless Quartus compile; `--package` chains into the next one), `package.py` (bit-reverse the bitstream, lay out the SD card), `make_pocket_image.py` (art to Pocket `.bin`), `disasm.py` (disassemble Z80 code out of a ROM image; `--strings` first to find the data), `dump_chars.py` (render the character ROM as ASCII art). Standard library only, except `make_pocket_image.py`, which wants numpy and Pillow. Shared helpers in `_common.py`.

  `disasm.py` and `dump_chars.py` are for reading the game, not building it. Reach for them when a symptom is not in our RTL at all: the attract-mode CAST screen looked like a video bug for a long time, and is in fact gated on the credit counter at `$8024`, which `disasm.py` showed in one command. Before spending a day in `src/fpga/rtl/`, it is worth asking whether the original ROM does this on purpose.
- `docs/analogue/` - Analogue's openFPGA documentation, mirrored. The authority on APF, the bridge, and chip32.
- `docs/game/` - notes on the original arcade hardware, one folder per source document. `midway-parts-operating-manual/` covers Midway's January 1981 operator manual: board set, cabinet I/O, self-test, the factory switch card. These describe the 1980 machine, not this core - check them before believing what the RTL seems to do, but never treat them as a spec for what we ship.
- `.repos/` - vendored read-only references. Prefer their patterns over invented ones. Never edit or import from them. Sync with `python tools/sync.py`.