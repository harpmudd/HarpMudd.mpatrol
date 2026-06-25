"""
pack_rom.py — Build a flat ROM image for the HarpMudd Moon Patrol Pocket core.

Moon Patrol runs on Irem M52 hardware: a Z80 main CPU + a 6803 sound CPU driving
two AY-3-8910 (YM2149) PSGs and an MSM5205 ADPCM. The whole romset is twelve
4 KB ROMs streamed to the FPGA in one straight concatenation (no mirrors, no
gaps, no padding). The M52 colour palette is synthesised in RTL, so there are
NO colour PROMs in the image (matching the MiSTer Arcade-MoonPatrol .mra).

ROM image layout (0xC000 bytes, byte offset = dn_addr in the FPGA). The decode
ranges below are exactly platform.vhd's romp_cs / romc*_cs / roms*_cs / romb*_cs
and the sound board's own dn_addr decode for mp-s1.1a:

  0x0000-0x3FFF  Z80 main program        mpa-1.3m / mpa-2.3l / mpa-3.3k / mpa-4.3j
  0x4000-0x5FFF  char / tile graphics    mpe-5.3e / mpe-4.3f
  0x6000-0x7FFF  sprite graphics         mpb-2.3m / mpb-1.3n
  0x8000-0xAFFF  parallax bg bitmaps     mpe-3.3h / mpe-2.3k / mpe-1.3l
  0xB000-0xBFFF  6803 sound program      mp-s1.1a   (-> moon_patrol_sound_board)
Image ends at 0xC000 — NO zero-padding.

Usage:
  python pack_rom.py            (writes mpatrol.rom into dist/Assets/mpatrol/common/)
"""

import sys
import zipfile
import zlib
import os

DEFAULT_ZIP_DIR = r"C:\Projects\Downloaded_Artifacts"
ASSETS_DIR      = r"C:\Projects\HarpMudd.mpatrol\dist\Assets\mpatrol\common"

ROM_IMAGE_SIZE = 0xC000   # 49152 bytes. Do NOT pad past this.

# (CRC32, expected_size, description, rom_image_offset, mirror_offset_or_None)
MPATROL_ROM_DEFS = [
    # --- Z80 main CPU program (platform.vhd romp_cs: dn_addr[15:14]="00") ---
    (0x5873a860, 0x1000, "mpa-1.3m  (Z80 prog 0)",       0x0000, None),
    (0xf4b85974, 0x1000, "mpa-2.3l  (Z80 prog 1)",       0x1000, None),
    (0x2e1a598c, 0x1000, "mpa-3.3k  (Z80 prog 2)",       0x2000, None),
    (0xdd05b587, 0x1000, "mpa-4.3j  (Z80 prog 3)",       0x3000, None),
    # --- Char / tile graphics (romc1_cs 0x4000, romc2_cs 0x5000) ---
    (0xe3ee7f75, 0x1000, "mpe-5.3e  (char gfx 1)",       0x4000, None),
    (0xcca6d023, 0x1000, "mpe-4.3f  (char gfx 2)",       0x5000, None),
    # --- Sprite graphics (roms1_cs 0x6000, roms2_cs 0x7000) ---
    (0x707ace5e, 0x1000, "mpb-2.3m  (sprite gfx 1)",     0x6000, None),
    (0x9b72133a, 0x1000, "mpb-1.3n  (sprite gfx 2)",     0x7000, None),
    # --- Parallax background bitmaps (romb1/2/3_cs 0x8000/9000/A000) ---
    (0xa0919392, 0x1000, "mpe-3.3h  (bg bitmap 1)",      0x8000, None),
    (0xc7aa1fb0, 0x1000, "mpe-2.3k  (bg bitmap 2)",      0x9000, None),
    (0xc46a7f72, 0x1000, "mpe-1.3l  (bg bitmap 3)",      0xA000, None),
    # --- 6803 sound CPU program (-> moon_patrol_sound_board dn decode) ---
    (0x561d3108, 0x1000, "mp-s1.1a  (6803 sound prog)",  0xB000, None),
]

OUT_NAME = "mpatrol.rom"
DESC     = "Moon Patrol (Irem, 1982)"


def crc32_of(data):
    return zlib.crc32(data) & 0xFFFFFFFF


def load_zip_by_crc(zip_path):
    found = {}
    with zipfile.ZipFile(zip_path) as zf:
        for info in zf.infolist():
            data = zf.read(info.filename)
            found[crc32_of(data)] = data
    return found


def load_dir_by_crc(zip_dir):
    found = {}
    zips = sorted(f for f in os.listdir(zip_dir) if f.lower().endswith('.zip'))
    if not zips:
        print(f"  (no zip files found in {zip_dir})")
        return found
    for zname in zips:
        print(f"  scanning {zname}")
        try:
            found.update(load_zip_by_crc(os.path.join(zip_dir, zname)))
        except Exception as e:
            print(f"  WARNING: could not read {zname}: {e}")
    return found


def main():
    out_path = os.path.join(ASSETS_DIR, OUT_NAME)

    print(f"ROM packer - {DESC}")
    print(f"Output: {out_path}\n")
    print(f"Scanning all zips in: {DEFAULT_ZIP_DIR}")
    found = load_dir_by_crc(DEFAULT_ZIP_DIR)
    print()

    image = bytearray(ROM_IMAGE_SIZE)
    errors = []

    for (crc, size, desc, offset, mirror) in MPATROL_ROM_DEFS:
        if crc in found:
            data = found[crc]
            if len(data) != size:
                errors.append(f"  WRONG SIZE  {desc}: expected {size}, got {len(data)}")
                continue
            image[offset:offset + size] = data
            if mirror is not None:
                image[mirror:mirror + size] = data
            print(f"  OK          {desc}  @ 0x{offset:05X}")
        else:
            errors.append(f"  MISSING     {desc}  (CRC {crc:08x})")

    print()
    if errors:
        print("MISSING OR INVALID ROMs:")
        for e in errors:
            print(e)
        sys.exit(1)

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "wb") as f:
        f.write(image)

    print(f"\nSUCCESS: wrote {len(image)} bytes (0x{len(image):X}) -> {out_path}")


if __name__ == "__main__":
    main()
