# roms/

Test ROMs, one folder per module, each written to prove one module on the
Pocket. A test ROM replaces the game's program ROM ($0000-$3FFF) and keeps the
rest of the core ROM image, so it draws with the game's own character ROM and
colours. You still need a MAME `rallyx.zip` or `nrallyx.zip` for those.

The sources are sdasz80 syntax. `tools/build_test_rom.py` assembles them; it
needs SDCC, which on Windows comes from MSYS2:

```
C:\msys64\usr\bin\bash -lc "pacman -S mingw-w64-ucrt-x86_64-sdcc"
```

## cpu/ - the Z80

`zexall.s` is Frank Cringle's zexall, the Z80 instruction exerciser, ported to
the Rally-X board. It runs 67 groups of instructions through every combination
of operands and flags it tests, CRCs the results, and compares each CRC with
the one a real Zilog Z80 produced. The header of `zexall.s` lists what changed
from the CP/M program.

Before the Pocket, it runs on T80 in simulation:

```
python tools/build_test_rom.py
python tools/sim.py --test tb_t80 --exercisers
```

### On the Pocket

1. Build and install the core as usual (`python tools/build.py --package`).
2. Build the test image from your MAME set:
   `python tools/build_test_rom.py --zip path/to/rallyx.zip`. It writes
   `build/test-roms/rallyx.rom` (or `nrallyx.rom`).
3. On the SD card, rename `Assets/rallyx/common/rallyx.rom` to keep it, and
   copy the test image in its place.
4. Start Rally-X from the Pocket's menu, and leave it running. The whole run
   takes about four and a quarter hours.
5. Afterwards, put the real `rallyx.rom` back.

If the screen stays blank, the text is in a palette line that draws nothing:
press any button or direction, and each press steps to the next of the 64
lines until the text shows.

The narrow panel on the right stays empty, except that after about 13 seconds
the core's high-score restore may paint your saved Rally-X high score into it.
That is the core, not the test, and it leaves the save file alone.

**A pass** looks like this:

- The top line reads `Z80 CPU TEST   ZEXALL`, and the second line names the
  group running, such as `(ADC,SBC) HL,(BC,DE,HL,SP)`.
- A grid fills in, one entry per group: `01 OK`, `02 OK`, and so on, four
  columns of 17. The running group shows `..` in place of `OK`.
- At the end, the grid is full to `67 OK`, the counts line reads
  `PASSED 67   FAILED 00`, and the bottom line reads `ALL TESTS DONE`.

**A failure** is any of:

- An entry that reads `ER` instead of `OK`, and `FAILED` above `00`. Three
  lines near the bottom then name the last group that failed and the CRC it
  expected and got. Note all three: the group number and the two CRCs are what
  the simulation needs to reproduce it.
- A group still showing `..` far past its time, which is a hang. Group 06
  (`ALUOP A,(B,C,D,E,H,L,(HL),A)`) takes about an hour and three quarters on
  its own; no other group takes more than an hour.
- Garbage on screen, or the game's attract mode instead of the test, which
  means the image was not loaded.
