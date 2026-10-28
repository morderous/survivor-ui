"""The launcher's art, from Wenrexa's "Assets: UI RPG Game Interface [Lite
Version]" (https://wenrexa.itch.io/werdanta03, Creative Commons Zero v1.0):
the pieces the launcher draws, copied here under plain names, and two made
from them (an inner frame without the title band; the arrow turned down).

    python make_art.py <the pack's PNG folder>
"""
import os
import sys

from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else r"D:\WoW-Survivors\assets\wenrexa-werdanta03\files\AssetsUIWerdantaN3\PNG"
HERE = os.path.dirname(os.path.abspath(__file__))

COPIES = {
    "frame": "PanelSettings.png",            # the window's frame, its title band left out when drawn
    "card": "PanelInventory_Stats.png",      # a small dark card with a thin rim
    "button-red": "Button03.png",
    "button-red-wide": "Button01.png",
    "button-stone": "MessageBox_Button.png",
    "plaque": "Selector04.png",              # the title's plaque
    "switch-on": "Switch_04.png",
    "switch-off": "Switch_05.png",
    "close": "Menu_Close.png",
    "minimize": "BtnIcon02.png",
    "bar-back": "ProgressBar01_Background.png",
    "bar-green": "ProgressBar01_Bar.png",
    "bar-border": "ProgressBar01_Border.png",
    "scroll-track": "ScrollBar01.png",
    "scroll-thumb": "Slider01.png",
    "field": "Slider02.png",                 # a long stone track, for drop-downs
    "gem-red": "Switch_02.png",              # the message boxes' kinds
    "gem-green": "Switch_01.png",
    "gem-blue": "Switch_03.png",
}


def main():
    for name, source in COPIES.items():
        Image.open(os.path.join(SRC, source)).convert("RGBA").save(os.path.join(HERE, name + ".png"), optimize=True)
    # The window's frame and an inner frame (Menu02): their dark title band
    # (rows 12 to 46, the rim's own stretch of it too) made the body and rim
    # below it, row 100, so the sides stretch clean.
    for name, source in (("frame", "PanelSettings.png"), ("inset", "Menu02.png")):
        piece = Image.open(os.path.join(SRC, source)).convert("RGBA")
        w, h = piece.size
        body = [piece.getpixel((x, 100)) for x in range(w)]
        for y in range(12, 47):
            for x in range(w):
                piece.putpixel((x, y), body[x])
        piece.save(os.path.join(HERE, name + ".png"), optimize=True)
    # The scroll bars' track, upright.
    Image.open(os.path.join(SRC, "ScrollBar01.png")).convert("RGBA").rotate(90, expand=True).save(
        os.path.join(HERE, "scroll-track-v.png"), optimize=True)
    # The drop-downs' arrow: the play button's triangle turned to point down.
    Image.open(os.path.join(SRC, "BtnIcon07.png")).convert("RGBA").rotate(-90, expand=True).save(
        os.path.join(HERE, "arrow-down.png"), optimize=True)
    print("art made in", HERE)


if __name__ == "__main__":
    main()
