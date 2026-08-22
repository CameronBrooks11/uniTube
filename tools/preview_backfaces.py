"""Report what percentage of a preview image is BACK faces.

OpenSCAD's Cornfield scheme paints front faces yellow (#f9d72c) and back faces
green (#9dcb51). A closed part viewed from outside shows no back faces at all,
so any significant green in an OpenCSG preview means the preview is displaying
the SUBTRACTED geometry over the shell -- the model looks solid, or inside-out,
while every CGAL-based gate stays green.

Measured on examples/08_coaxial_jacket before ut_assemble wrapped its CSG in
render(): 79.3%. After: 0.0%. Used by `just preview`.
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
