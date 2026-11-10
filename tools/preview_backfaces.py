"""Report what percentage of a preview image is BACK faces.

OpenSCAD's Cornfield scheme paints front faces yellow (#f9d72c) and back faces
green (#9dcb51). A part viewed from outside shows no back faces at all, so any
significant green in an OpenCSG preview means a solid is inside-out or the
preview is not showing the part -- the model looks solid while every
CGAL-based gate stays green, because CGAL repairs orientation in a boolean.

Measured on examples/08_coaxial_jacket with the swept faces wound inside-out:
79.3%. Wound the way polyhedron() expects: 0.0%. Used by `just preview`.
"""

import sys

from PIL import Image


def back_face_percent(path: str) -> float:
    # tobytes(), not getdata(): getdata is deprecated in Pillow 11 and its
    # replacement does not exist in older ones. Raw bytes work in every version.
    px = Image.open(path).convert("RGB").tobytes()
    model = back = 0
    for i in range(0, len(px), 3):
        r, g, b = px[i], px[i + 1], px[i + 2]
        if r > 250 and g > 250 and b > 215:  # background
            continue
        model += 1
        if g > r and g > 60:  # markedly greener than the yellow front face
            back += 1
    return 100.0 * back / max(model, 1)


if __name__ == "__main__":
    print("%.1f" % back_face_percent(sys.argv[1]))
