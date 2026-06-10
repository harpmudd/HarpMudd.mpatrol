# Moon Patrol (Irem, 1982) — Analogue Pocket

An Analogue Pocket port of **Moon Patrol** (Irem, 1982) by **HarpMudd**, built on
the openFPGA framework.

## The Game

Moon Patrol is a side-scrolling shooter from Irem, widely credited as the first
game with true parallax scrolling. You pilot the Moon Buggy across the lunar
surface, jumping craters and mines while shooting upward at alien attackers and
forward at ground obstacles — all against a multi-layer scrolling backdrop of
mountains and a city skyline. The course is divided into lettered checkpoints,
with the run from A–Z making up a full patrol.

## Hardware

Irem M52 board set.

| Part | Role |
|---|---|
| Zilog Z80 | Main CPU |
| Motorola 6803 (cpu68) | Sound CPU |
| 2× AY-3-8910 (YM2149) + MSM5205 ADPCM | Sound |
| Display | Horizontal CRT, 15 kHz, RGB, ~56.7 Hz |

## The Port

Built on the MiSTer **Arcade-MoonPatrol** core:

- **MiSTer port:** Sorgelig (November 2017)
- **FPGA arcade hardware implementation:** [PACE framework](http://pacedev.net/)
  (Mark McDougall); Moon Patrol sound board by Dar (darfpga); 6800/03-compatible
  cpu68 core by John E. Kent.

This Analogue Pocket build adapts that RTL to the openFPGA / APF framework intact,
re-wrapping only the MiSTer system layer. Native resolution, horizontal (240×248
visible), 4:3. Many thanks to the authors above.

## Controls

| Pocket | Action |
|---|---|
| **D-Pad ←/→** | Decelerate / Accelerate |
| **A** | Fire (up + forward) |
| **B** | Jump |
| **Start** | 1P Start |
| **Select** | Insert coin |

## ROMs

ROMs are **not** included. Build your own from the bundled `.mra` recipe in
`Assets/mpatrol/common/` — it lists the required MAME romset files by name and
CRC32, with no copyrighted data. Run it through the `mra` tool to produce
`mpatrol.rom`, then keep that `.rom` in the same folder (and on your Pocket SD
card).

## Credits

- **Original arcade game:** Irem (1982)
- **MiSTer port:** Sorgelig
- **FPGA arcade core:** PACE framework (Mark McDougall), sound board by Dar,
  cpu68 by John E. Kent
- **Analogue Pocket port:** HarpMudd

## About / Support

I'm into retro games and the Analogue Pocket, always cooking up something new.
I love being part of a community built on sharing and the love of games — so if
any of my projects bring you joy, grab me a coffee; it fuels the next thing.

☕ **[buymeacoffee.com/harpmudd](https://buymeacoffee.com/harpmudd)**
