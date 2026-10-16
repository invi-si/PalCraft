# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Original flat polygon icons. No reference image, jar or game pixels are read.

Artwork: Invi, CC-BY-4.0. The coordinates and palette below are the source.
"""
import os
from pathlib import Path
from PIL import Image, ImageDraw
NAMES = ['Bed', 'Parrot', 'ParrotHead', 'Cat', 'Fox', 'IronGolem', 'Panda', 'Rabbit', 'Wolf', 'Camel', 'Horse', 'Enderman', 'Slime', 'Witch', 'EnderDragon']
PACKAGES = {'/Game/MinecraftBlocks/T_MC_Bed': 'Bed', '/Game/MinecraftParrot103/T_MC_ParrotIcon': 'Parrot', '/Game/MinecraftElytra104/T_ParrotHead': 'ParrotHead', **{'/Game/MinecraftCreatures105/T_MC_' + n + 'Icon': n for n in ['Cat', 'Fox', 'IronGolem', 'Panda', 'Rabbit', 'Wolf']}, **{'/Game/MinecraftRideables106/T_MC_' + n + 'Icon': n for n in ['Camel', 'Horse']}, **{'/Game/MinecraftHostiles107/T_MC_' + n + 'Icon': n for n in ['Enderman', 'Slime', 'Witch']}, '/Game/MinecraftBossD/T_MC_EnderDragonIcon': 'EnderDragon'}

def render(name, size=256):
    im = Image.new('RGBA', (256, 256))
    d = ImageDraw.Draw(im)
    ink = '#253243'
    light = '#f2e9d5'
    gold = '#efbe67'
    teal = '#58bca5'

    def p(points, color=ink):
        d.polygon(points, fill=color)

    def r(box, color=ink):
        d.rectangle(box, fill=color)

    def eye(x, y):
        r((x, y, x + 10, y + 10), light)
    if name == 'Bed':
        r((33, 126, 223, 182))
        r((33, 100, 48, 211))
        r((208, 146, 223, 211))
        r((49, 126, 207, 160), teal)
        r((53, 109, 93, 137), light)
    elif name in ('Parrot', 'ParrotHead'):
        p([(82, 179), (79, 91), (109, 55), (151, 55), (176, 89), (165, 144), (140, 188), (109, 220)], teal)
        p([(103, 115), (147, 117), (132, 176), (103, 190)], ink)
        p([(161, 79), (209, 107), (162, 119)], gold)
        p([(99, 61), (107, 33), (122, 57)], gold)
        eye(143, 80)
        if name == 'ParrotHead':
            im = im.crop((65, 27, 220, 182)).resize((256, 256), Image.Resampling.NEAREST)
    elif name in ('Cat', 'Fox', 'Wolf'):
        color = {'Cat': gold, 'Fox': '#d9875f', 'Wolf': '#99adba'}[name]
        p([(54, 89), (47, 38), (99, 65), (157, 65), (209, 38), (202, 89), (209, 155), (166, 205), (90, 205), (47, 155)], color)
        p([(61, 72), (59, 56), (83, 72)], ink)
        p([(173, 72), (197, 56), (195, 72)], ink)
        p([(83, 137), (128, 155), (173, 137), (166, 185), (128, 205), (90, 185)], light)
        r((79, 111, 95, 121))
        r((161, 111, 177, 121))
        p([(116, 149), (140, 149), (128, 164)])
        if name == 'Cat':
            for y in (150, 165):
                r((26, y, 77, y + 4))
                r((179, y, 230, y + 4))
    elif name == 'IronGolem':
        p([(63, 86), (91, 86), (91, 49), (165, 49), (165, 86), (193, 86), (216, 184), (187, 194), (169, 135), (169, 216), (140, 216), (128, 174), (116, 216), (87, 216), (87, 135), (69, 194), (40, 184)], '#9eb7b5')
        r((98, 63, 158, 102), ink)
        eye(106, 76)
        eye(139, 76)
        p([(105, 124), (128, 109), (151, 124), (128, 155)], gold)
    elif name == 'Panda':
        p([(55, 96), (41, 57), (66, 33), (99, 66), (157, 66), (190, 33), (215, 57), (201, 96), (205, 177), (167, 211), (89, 211), (51, 177)])
        p([(73, 91), (101, 73), (155, 73), (183, 91), (191, 168), (158, 195), (98, 195), (65, 168)], light)
        p([(77, 111), (98, 101), (115, 132), (98, 148), (77, 139)])
        p([(179, 111), (158, 101), (141, 132), (158, 148), (179, 139)])
        eye(91, 118)
        eye(155, 118)
        p([(116, 161), (140, 161), (128, 177)])
    elif name == 'Rabbit':
        p([(80, 125), (65, 34), (91, 28), (118, 111), (138, 111), (165, 28), (191, 34), (176, 125), (193, 157), (177, 202), (128, 220), (79, 202), (63, 157)], '#c8ad99')
        p([(82, 42), (99, 103), (91, 109)], light)
        p([(174, 42), (157, 103), (165, 109)], light)
        eye(91, 151)
        eye(155, 151)
        p([(118, 174), (138, 174), (128, 185)], ink)
    elif name in ('Camel', 'Horse'):
        color = gold if name == 'Camel' else '#ad856d'
        p([(46, 124), (127, 124), (145, 63), (172, 48), (188, 67), (220, 94), (213, 122), (174, 111), (167, 171), (160, 218), (139, 218), (137, 173), (88, 173), (78, 218), (57, 218), (62, 163), (36, 153)], color)
        p([(145, 64), (154, 27), (171, 55)], ink)
        eye(179, 79)
        if name == 'Camel':
            p([(61, 126), (75, 85), (95, 88), (113, 126)], color)
        else:
            p([(139, 65), (123, 92), (124, 130), (143, 110)], ink)
        p([(44, 127), (24, 108), (24, 164), (37, 165)], ink)
    elif name == 'Enderman':
        r((84, 35, 172, 103))
        p([(81, 111), (175, 111), (202, 224), (182, 227), (158, 149), (153, 230), (131, 230), (128, 175), (125, 230), (103, 230), (98, 149), (74, 227), (54, 224)])
        r((96, 67, 117, 76), '#c4a2ed')
        r((139, 67, 160, 76), '#c4a2ed')
    elif name == 'Slime':
        p([(49, 81), (199, 66), (219, 201), (43, 215), (33, 135)], teal)
        p([(49, 81), (199, 66), (183, 96), (62, 110)], '#a4ddc5')
        r((79, 126, 99, 147))
        r((155, 119, 175, 140))
        r((112, 165, 143, 175))
    elif name == 'Witch':
        p([(63, 202), (79, 124), (177, 124), (193, 202)], teal)
        r((94, 102, 162, 153), light)
        p([(38, 109), (88, 90), (123, 28), (147, 82), (218, 109)], ink)
        p([(91, 87), (147, 82), (158, 96), (82, 99)], gold)
        r((105, 119, 114, 128))
        r((143, 119, 152, 128))
        p([(118, 132), (138, 132), (128, 143)], '#bc916f')
    elif name == 'EnderDragon':
        p([(116, 125), (78, 82), (19, 53), (40, 120), (66, 115), (80, 151), (112, 155)], '#8272b3')
        p([(140, 125), (178, 82), (237, 53), (216, 120), (190, 115), (176, 151), (144, 155)], '#8272b3')
        p([(108, 89), (113, 52), (128, 37), (143, 52), (148, 89), (141, 173), (162, 210), (135, 226), (123, 202), (105, 178)], ink)
        p([(113, 55), (94, 29), (117, 39)], gold)
        p([(143, 55), (162, 29), (139, 39)], gold)
        r((115, 69, 124, 77), teal)
        r((132, 69, 141, 77), teal)
        p([(110, 147), (79, 174), (90, 184), (121, 164)], gold)
        p([(146, 147), (177, 174), (166, 184), (135, 164)], gold)
    else:
        raise ValueError(name)
    return im.resize((size, size), Image.Resampling.NEAREST)

def generate(output):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    for name in NAMES:
        render(name).save(output / (name + '.png'))
    (output / 'LICENSE.txt').write_text('Original polygon icon artwork by Invi. CC BY 4.0.\nSource geometry: tools/release/original_icons.py\nNo third-party image inputs.\n')
if __name__ == '__main__':
    import sys
    generate(sys.argv[1])
