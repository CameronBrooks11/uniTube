"""Print the signed volume of an STL, in the file's own units cubed.

A closed mesh whose faces are wound counter-clockwise seen from outside -- what
STL specifies, and what OpenSCAD exports for its own primitives -- has a
POSITIVE volume by the divergence theorem. A negative one is inside-out.

This exists because an inside-out polyhedron() is invisible on OpenSCAD 2021.01:
CGAL repairs the orientation in any boolean, so every network rendered correctly
there while a plain ut_tube() exported with all its normals reversed, and on a
Manifold-backend OpenSCAD difference() then subtracted nothing. Measured on
examples/01_elbow before the fix: -5865.23. After: +5865.23. Used by `just check`.

Reads ASCII and binary STL. Standard library only.
"""

import re
import struct
import sys


def triangles(path: str):
    with open(path, "rb") as fh:
        data = fh.read()
    # A binary STL is an 80-byte header, a count, then 50 bytes per triangle.
    # Test the size rather than the leading "solid", which binary files may carry.
    if len(data) >= 84 and len(data) == 84 + 50 * struct.unpack_from("<I", data, 80)[0]:
        for i in range(struct.unpack_from("<I", data, 80)[0]):
            v = struct.unpack_from("<9f", data, 84 + 50 * i + 12)
            yield v[0:3], v[3:6], v[6:9]
        return
    v = [
        tuple(float(x) for x in m)
        for m in re.findall(rb"vertex\s+(\S+)\s+(\S+)\s+(\S+)", data)
    ]
    for i in range(0, len(v) - 2, 3):
        yield v[i], v[i + 1], v[i + 2]


def signed_volume(path: str) -> float:
    total = 0.0
    n = 0
    for a, b, c in triangles(path):
        n += 1
        total += (
            a[0] * (b[1] * c[2] - b[2] * c[1])
            - a[1] * (b[0] * c[2] - b[2] * c[0])
            + a[2] * (b[0] * c[1] - b[1] * c[0])
        )
    if n == 0:
        raise SystemExit(f"{path}: no triangles")
    return total / 6


if __name__ == "__main__":
    print("%.6g" % signed_volume(sys.argv[1]))
