<div align="center">
    <p>
        <a href="https://github.com/vieira-fpga" target="_blank">
            <picture>
                <source media="(prefers-color-scheme: dark)" srcset="https://github.com/vieira-fpga/.github/raw/HEAD/.github/assets/logo-dark.svg" />
                <source media="(prefers-color-scheme: light)" srcset="https://github.com/vieira-fpga/.github/raw/HEAD/.github/assets/logo-light.svg" />
                <img height="100" src="https://github.com/vieira-fpga/.github/raw/HEAD/.github/assets/logo-light.svg" alt="Vieira FPGA" />
            </picture>
        </a>
        <br /> <br />
        <a href="https://x.com/morganvieira" target="_blank">
            <picture>
                <source media="(prefers-color-scheme: dark)" srcset="https://github.com/vieira-fpga/.github/raw/HEAD/.github/assets/icons/twitter-dark.svg" />
                <source media="(prefers-color-scheme: light)" srcset="https://github.com/vieira-fpga/.github/raw/HEAD/.github/assets/icons/twitter-light.svg" />
                <img width="24" src="https://github.com/vieira-fpga/.github/raw/HEAD/.github/assets/icons/twitter-light.svg" alt="X" />
            </picture>
        </a>
    </p>
</div>

___

# openFPGA-RallyX
Rally-X and New Rally-X for the Analogue Pocket | By [Vieira FPGA](https://github.com/vieira-fpga)

___

## General TLDR
Install the core with Pupdate or by hand, build a ROM image from your own MAME set with `tools/build_rom.py`, and copy it to `Assets/rallyx/common/`. The Pocket asks which game to load each time the core starts.

___

## Introduction
<sup><i>The core is licensed under the GNU GPL v3, see LICENSE for more information.</i>
<br />
Ported by <a href="https://github.com/morgan-vieira">Morgan Vieira</a> for <a href="https://github.com/vieira-fpga">Vieira FPGA</a> with Claude Opus 5 (1M context) in Claude Code
</sup>

Rally-X is Namco's 1980 maze-chase arcade game. You drive a car through a scrolling maze and collect every flag while enemy cars chase you. A smoke screen holds them off for a moment, and a radar shows where the flags and the chasers are. New Rally-X followed in 1981.
<br /> <br />
This core runs both. The arcade hardware comes from MiSTer-X's MiSTer core, and the Z80 is the T80 CPU core. The Pocket side is ours: the APF glue, ROM loading, audio, and high score saves.

## Installation
There are two ways to get the core onto your card. Either way, you have to find the game ROM yourself.

### With Pupdate
[Pupdate](https://github.com/mattpannella/pupdate/releases) is the easy way. This core is on its list, so Pupdate fetches it, installs it to `Cores/MorganVieira.Rally-X`, and updates it when new versions come out.
<br /> <br />
If you run an Analogizer adapter, Pupdate also writes its `analogizer.bin` config file. [ANALOGIZER.md](ANALOGIZER.md) covers that.

### By Hand
Grab the [latest release](https://github.com/vieira-fpga/openFPGA-RallyX/releases/latest), unzip it, and merge `Cores`, `Platforms` and `Assets` into the root of your SD card. The zip already has the layout the Pocket expects, so there's nothing to rename or move once it's across.

## The Game ROM
This part is the same either way. The core ships with no game data in it and never will, so you need a MAME set of your own: `rallyx.zip` for Rally-X, or `nrallyx.zip` for New Rally-X. Pupdate won't do this bit for you.
<br /> <br />
The Pocket can't read a MAME zip, so `tools/build_rom.py` turns one into the single image the core loads:
<br />

```
python tools/build_rom.py --zip path/to/rallyx.zip
```

It works out which of the two sets you handed it, checks every part against its CRC32, and writes `build/rallyx.rom` or `build/nrallyx.rom`. Either one comes out at 21,280 bytes. The script only needs Python 3.
<br /> <br />
That CRC32 check is worth having. Wrong or half-renamed parts still add up to exactly the right size, and the image they produce boots to a black screen. That looks like a broken core rather than a bad zip, so the script rejects the file instead.
<br /> <br />
Copy the image to `Assets/rallyx/common/` on your SD card, creating that folder if it isn't there. Both games can live in it at once. The Pocket asks which one you want each time the core starts, and you can switch between them from the core menu while it's running.

## High Scores
The core keeps your high score between sessions. There's nothing to set up and no menu entry for it. The Pocket writes the score out when you quit the core, turn the Pocket off, or put it to sleep, and reads it back the next time you start the game.
<br /> <br />
Each game gets its own file in `Saves/rallyx/common/`, named after the ROM you loaded, so `rallyx.rom` gives you `rallyx.sav`. Delete the file to put the high score back to the factory default.

## Difficulty
Both games share one Difficulty menu, but they read it differently. Rally-X sets both the car count and the difficulty from it. New Rally-X only reads the car count, and only ever starts with 3 or 4 cars.
<br /> <br />
Each option names what Rally-X does first, then the New Rally-X car count in brackets. `2 Cars, Medium (NRX 4)` gives 2 cars on Medium in Rally-X and 4 cars in New Rally-X. The default gives 3 cars in both.

## Analogizer
[Analogizer](https://github.com/RndMnkIII/Analogizer) is a cartridge-slot adapter that adds analog video output and SNAC controller support, and this core works with it. [ANALOGIZER.md](ANALOGIZER.md) covers the video modes, which pads work and where the A/B switch has to sit for each one, where the config lives, and which problems to report here rather than upstream.

> [!WARNING]
> The adapter draws its power from the cartridge slot, so this core switches that slot on for everybody, adapter or not. Don't leave a cartridge in the slot while this core is running.

## Legal
Rally-X © 1980 NAMCO LTD. All rights reserved. Rally-X is a trademark of BANDAI NAMCO ENTERTAINMENT INC. All other trademarks, logos, and copyrights are property of their respective owners.
<br /> <br />
The authors, contributors, and maintainers of this core are in no way associated with or endorsed by Bandai Namco Entertainment Inc.

## Credits
- Morgan Vieira (Analogue Pocket port) - [GitHub](https://github.com/morgan-vieira) | [X](https://x.com/morganvieira)
- MiSTer-X (Rally-X arcade hardware) - [MiSTer core](https://github.com/MiSTer-devel/Arcade-RallyX_MiSTer)
- Daniel Wallner (T80 Z80 CPU core)
- RndMnkIII (Analogizer) - [GitHub](https://github.com/RndMnkIII/Analogizer)
