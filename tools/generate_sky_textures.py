#!/usr/bin/env python3
"""Generate the cloud textures for the stylized sky shader.

These are 100% procedural (periodic value noise) and original to this repo,
so they carry no third-party license. They feed the MIT-licensed GDQuest
stylized-sky shader (adapted, single-pass) in assets/sky/stylized_sky.gdshader.

Regenerate with: python3 tools/generate_sky_textures.py
"""
import math
import random
from PIL import Image

SIZE = 256
OUT = "assets/sky"


def make_value_noise(size, cells, seed):
    """Tileable value noise via a wrapped lattice."""
    rnd = random.Random(seed)
    lat = [[rnd.random() for _ in range(cells)] for _ in range(cells)]
    img = Image.new("L", (size, size))
    px = img.load()
    for y in range(size):
        gy = y / size * cells
        y0 = int(gy) % cells
        y1 = (y0 + 1) % cells
        fy = gy - int(gy)
        sy = fy * fy * (3 - 2 * fy)
        for x in range(size):
            gx = x / size * cells
            x0 = int(gx) % cells
            x1 = (x0 + 1) % cells
            fx = gx - int(gx)
            sx = fx * fx * (3 - 2 * fx)
            v = (lat[y0][x0] * (1 - sx) + lat[y0][x1] * sx) * (1 - sy) + \
                (lat[y1][x0] * (1 - sx) + lat[y1][x1] * sx) * sy
            px[x, y] = int(v * 255)
    return img


def fbm(size, base_cells, octaves, seed):
    acc = [[0.0] * size for _ in range(size)]
    amp, total = 1.0, 0.0
    for o in range(octaves):
        n = make_value_noise(size, base_cells * (2 ** o), seed + o)
        p = n.load()
        for y in range(size):
            for x in range(size):
                acc[y][x] += (p[x, y] / 255.0) * amp
        total += amp
        amp *= 0.5
    img = Image.new("L", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            px[x, y] = int(acc[y][x] / total * 255)
    return img


def smoothstep(e0, e1, v):
    t = max(0.0, min(1.0, (v - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def main():
    import os
    os.makedirs(OUT, exist_ok=True)

    # Cloud shape: broad puffy blobs. fBM then a contrast curve so the
    # shader's density smoothstep has distinct cloud / clear regions.
    shape = fbm(SIZE, 4, 4, 1234)
    sp = shape.load()
    for y in range(SIZE):
        for x in range(SIZE):
            sp[x, y] = int(smoothstep(0.38, 0.72, sp[x, y] / 255.0) * 255)
    shape.save(f"{OUT}/cloud_shape.png")

    # Detail noise: higher-frequency wobble that erodes cloud edges.
    noise = fbm(SIZE, 16, 3, 987)
    noise.save(f"{OUT}/cloud_noise.png")

    # Height curve: density vs. raymarch progress through the cloud layer.
    # Fades in at the bottom, peaks mid-layer, fades at the top.
    curves = Image.new("L", (64, 64))
    cp = curves.load()
    for x in range(64):
        t = x / 63.0
        v = math.sin(t * math.pi) ** 1.5
        for y in range(64):
            cp[x, y] = int(v * 255)
    curves.save(f"{OUT}/cloud_curves.png")

    print("wrote", OUT + "/cloud_shape.png,", OUT + "/cloud_noise.png,", OUT + "/cloud_curves.png")


if __name__ == "__main__":
    main()
