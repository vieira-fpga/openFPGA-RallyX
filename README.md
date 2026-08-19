> [!NOTE]
> This core was developed with Claude Opus 5 (1M context) in Claude Code.

# openFPGA-RallyX

An Analogue Pocket core that plays both Rally-X and New Rally-X.

## Installation

There are two ways to get the core onto your card. You will have to find the game
ROM yourself.

### With Pupdate

[Pupdate](https://github.com/mattpannella/pupdate/releases) is the easy way. This
core is on its list, so Pupdate will fetch it, install it to
`Cores/MorganVieira.Rally-X`, and keep it current as new versions are released.

If you run an Analogizer adapter, Pupdate is also what writes its
`analogizer.bin` config file. [ANALOGIZER.md](ANALOGIZER.md) covers that.

### By hand

Grab the [latest release](https://github.com/morgan-vieira/openFPGA-RallyX/releases/latest),
unzip it, and merge `Cores`, `Platforms` and `Assets` into the root of your SD
card. The zip is already laid out the way the Pocket expects, so there's nothing
to rename or move once it's across.

### The game ROM

This part is the same either way. The core ships with no game data in it and
never will, so you'll need a MAME set of your own: `rallyx.zip` for Rally-X, or
`nrallyx.zip` for New Rally-X. Pupdate won't do this bit for you.

The Pocket can't read a MAME zip, so `tools/build_rom.py` turns one into the
single image the core loads:

```
python tools/build_rom.py --zip path/to/rallyx.zip
```

It works out which of the two sets you handed it, checks every part against its
CRC32, and writes `build/rallyx.rom` or `build/nrallyx.rom`. Either one comes out
at 21,280 bytes.

That CRC32 check is worth having. Wrong or half-renamed parts still add up to
exactly the right size, and the image they produce boots to a black screen.
That looks like a broken core rather than a bad zip, so the script rejects the
file instead.

Copy the image to `Assets/rallyx/common/` on your SD card, creating that folder
if it isn't there. Both games can live in it at once. The Pocket asks which one
you want each time the core starts, and you can switch between them from the core
menu while it's running.

The script only needs Python 3.

### High scores

The core keeps your high score between sessions. There's nothing to set up and
no menu entry for it. The Pocket writes the score out when you quit the core,
turn the Pocket off, or put it to sleep, and reads it back the next time you
start the game.

Each game gets its own file in `Saves/rallyx/common/`, named after the ROM you
loaded, so `rallyx.rom` gives you `rallyx.sav`. Delete the file to put the high
score back to the factory default.

## Analogizer

[Analogizer](https://github.com/RndMnkIII/Analogizer) is a cartridge-slot adapter
that adds analog video output and SNAC controller support, and this core works
with it. [ANALOGIZER.md](ANALOGIZER.md) covers the video modes, which pads work
and where the A/B switch has to sit for each one, where the config lives, and
which problems to report here rather than upstream.

The adapter draws its power from the cartridge slot, so this core switches that
slot on for everybody, adapter or not. Don't leave a cartridge in the slot while
this core is running.

## Legal

TBD