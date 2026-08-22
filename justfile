# uniTube — The Universal Tube Library for OpenSCAD
#
# uniTube has NO dependencies. A fresh clone renders immediately; `just setup`
# only verifies the toolchain. See docs/adr/0001-no-dependencies.md for why.

set shell := ["bash", "-euo", "pipefail", "-c"]

OUT := "out"

# List available recipes.
default:
    @just --list

# Verify the toolchain. There is nothing to install — uniTube has no dependencies.
setup:
    #!/usr/bin/env bash
    set -euo pipefail
    ok=0
    for t in openscad clang-format; do
      if command -v "$t" >/dev/null; then
        echo "  ok      $t  ($($t --version 2>&1 | head -1))"
      else
        echo "  MISSING $t"; ok=1
      fi
    done
    ver=$(openscad --version 2>&1 | grep -oE '[0-9]{4}\.[0-9]{2}' | head -1 || true)
    echo "  OpenSCAD version floor is 2021.01; found ${ver:-unknown}"
    echo
    echo "  uniTube has no dependencies. To use it from your own models, either"
    echo "  use <$(pwd)/src/uniTube.scad>, or symlink this repo into your"
    echo "  OpenSCAD library path (~/.local/share/OpenSCAD/libraries/uniTube)."
    exit $ok

# Format all first-party .scad sources in place. reference/ is never touched.
fmt:
    #!/usr/bin/env bash
    set -euo pipefail
    mapfile -t files < <(find src examples tests -name '*.scad' 2>/dev/null | sort)
    [ ${#files[@]} -eq 0 ] || clang-format -i "${files[@]}"
    echo "formatted ${#files[@]} file(s)"

# Fail if any first-party source is not correctly formatted.
fmt-check:
    #!/usr/bin/env bash
    set -euo pipefail
    mapfile -t files < <(find src examples tests -name '*.scad' 2>/dev/null | sort)
    [ ${#files[@]} -eq 0 ] || clang-format --dry-run -Werror "${files[@]}"
    echo "fmt-check ok (${#files[@]} file(s))"

# The project's own rules, enforced. See AGENTS.md.
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    fail=0

    # LINT RULE 1 — src/ may never import from reference/ (AGENTS.md rule 2,
    # the licence quarantine). These are the LINT's own numbers; AGENTS.md rule
    # N is a different list, and each rule below names the project rule it backs.
    if grep -rnE '^[[:space:]]*(use|include)[[:space:]]*<[^>]*reference/' src/ 2>/dev/null; then
      echo "LINT FAIL: a file under src/ imports from reference/ (see AGENTS.md)"; fail=1
    fi

    # LINT RULE 2 — no file under src/ may emit top-level geometry or echo on
    # import (AGENTS.md rule 3).
    # Top-level statements sit at column 0; `function f(` / `module m(` / `use <`
    # / assignments do not match this pattern, but `cube(`, `echo(`, `if (` do.
    if find src -name '*.scad' -print0 2>/dev/null \
         | xargs -0 -r grep -nE '^[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(' ; then
      echo "LINT FAIL: top-level geometry or echo under src/ (library and demo must not share a file)"; fail=1
    fi

    # LINT RULE 3 — import lines must be well-formed. clang-format rewrites
    # `use <a/b.scad>` into `use<a / b.scad>` unless the block is wrapped in
    # `// clang-format off` / `on`, and the resulting error names the wrong file.
    if find src examples tests -name '*.scad' -print0 2>/dev/null \
         | xargs -0 -r grep -nE '^[[:space:]]*(use|include)[[:space:]]*<' \
         | grep -vE ':(use|include) <[^ >]+>;$' ; then
      echo "LINT FAIL: malformed import line. Use exactly \`use <path>;\` inside a"
      echo "           // clang-format off / on block. See AGENTS.md."; fail=1
    fi

    [ $fail -eq 0 ] && echo "lint ok"
    exit $fail

# Every file in tests/guards/ MUST fail. An untested guard is worthless.
guards:
    #!/usr/bin/env bash
    set -uo pipefail
    mkdir -p "{{OUT}}/guards"
    fail=0; n=0
    for f in tests/guards/*.scad; do
      [ -e "$f" ] || continue
      if openscad --hardwarnings -o "{{OUT}}/guards/$(basename "${f%.scad}").stl" "$f" >/dev/null 2>&1; then
        echo "  GUARD DID NOT FIRE: $f rendered successfully but must abort"; fail=1
      else
        echo "  ok  $(basename "$f") aborted as required"; n=$((n+1))
      fi
    done
    [ $fail -eq 0 ] && echo "guards ok ($n guard(s) fired)"
    exit $fail

# Every advisory warning the library can emit must still be emitted.
warnings:
    #!/usr/bin/env bash
    set -uo pipefail
    mkdir -p "{{OUT}}/warnings"
    # These are echo() calls, NOT OpenSCAD WARNING: lines, so --hardwarnings does
    # not promote them and tests/guards/ cannot cover them -- a guard must abort.
    # Silencing one would otherwise pass every gate.
    log="{{OUT}}/warnings/w_all.log"
    openscad --hardwarnings -o "{{OUT}}/warnings/w_all.stl" tests/warnings/w_all.scad >"$log" 2>&1 || true
    fail=0
    for w in CHECK-2 CHECK-3 NET-4; do
      if grep -q "WARNING \[uniTube\] $w" "$log"; then
        echo "  ok   $w still fires"
      else
        echo "  FAIL $w no longer fires -- it was silenced, or its trigger changed"; fail=1
      fi
    done
    exit $fail

# PREVIEW must not lie. F5 is the mode this library is used in, and OpenCSG
# renders difference() by depth-peeling the framebuffer rather than computing
# geometry -- so a hollow assembly can display as a solid slug while every
# CGAL-based gate is green. Nothing here looked at preview until 2026-08-21.
#
# The signal needs no tuning: a closed part viewed from outside shows NO back
# faces. Measured on examples/08 before the fix: 79.3% back faces. After: 0.0%.
# There is nothing in between to threshold against. See tools/preview_backfaces.py.
preview:
    #!/usr/bin/env bash
    set -uo pipefail
    mkdir -p "{{OUT}}/preview"
    # OpenCSG needs a real GL context. QT_QPA_PLATFORM=offscreen has none and
    # OpenSCAD SEGFAULTS -- which is why every other recipe here can stay
    # headless and this one cannot. Under a bare CI runner, borrow one.
    if [ -n "${DISPLAY:-}" ]; then
      RUN=""
    elif command -v xvfb-run >/dev/null; then
      RUN="xvfb-run -a --server-args=-screen 0 1024x768x24"
    else
      echo "  preview needs a GL context (a DISPLAY, or xvfb-run) -- NOT skipping, a skip here reads as a pass"; exit 1
    fi
    py=python3
    if ! python3 -c 'import PIL' >/dev/null 2>&1; then
      command -v uvx >/dev/null || { echo "  preview needs Pillow or uvx -- NOT skipping, a skip here reads as a pass"; exit 1; }
      py="uvx --with pillow python3"
    fi
    fail=0
    for f in examples/*.scad; do
      b=$(basename "${f%.scad}")
      png="{{OUT}}/preview/$b.png"
      # NO --render: this is the OpenCSG preview path, deliberately.
      $RUN openscad -o "$png" --imgsize=420,380 --viewall --autocenter "$f" >/dev/null 2>&1
      [ -s "$png" ] || { echo "  FAIL $b  (no preview image produced -- no GL?)"; fail=1; continue; }
      # An example that deliberately exposes an interior declares it in the file.
      if grep -q 'preview-exposes-interior' "$f"; then limit=100; else limit=2; fi
      pct=$($py tools/preview_backfaces.py "$png")
      if awk -v p="$pct" -v l="$limit" 'BEGIN{exit !(p>l)}'; then
        echo "  FAIL $b  ${pct}% of the model is BACK faces -- preview is showing the subtracted bore"; fail=1
      else
        echo "  ok  $b  ${pct}%"
      fi
    done
    [ $fail -eq 0 ] && echo "preview ok"
    exit $fail

# CI equivalent: formatting + rules + every example and test renders warning-free.
check: fmt-check lint guards warnings preview
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "{{OUT}}/check"
    n=0
    while IFS= read -r f; do
      # --hardwarnings turns an unknown named argument into exit 1. Without it
      # OpenSCAD exits 0 — that is the exact bug class that broke this library
      # for 19 months (see docs/verification.md). Never drop this flag.
      # The target MUST be .stl: with -o *.csg a failing assert() exits 0.
      openscad --hardwarnings -o "{{OUT}}/check/$(basename "${f%.scad}").stl" "$f" 2>&1 \
        | sed "s|^|    [$(basename "$f")] |" || { echo "CHECK FAIL: $f"; exit 1; }
      n=$((n+1))
    done < <(find examples tests -maxdepth 1 -name '*.scad' 2>/dev/null | sort)
    echo "check ok ($n file(s) rendered warning-free)"

# The assert-only subset. Fast: these files render nothing of consequence.
test:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "{{OUT}}/test"
    n=0
    while IFS= read -r f; do
      openscad --hardwarnings -o "{{OUT}}/test/$(basename "${f%.scad}").stl" "$f" 2>&1 \
        | sed "s|^|    [$(basename "$f")] |" || { echo "TEST FAIL: $f"; exit 1; }
      n=$((n+1))
    done < <(find tests -maxdepth 1 -name '*.scad' 2>/dev/null | sort)
    echo "test ok ($n file(s))"

# Forced-CGAL manifoldness over every example. A raw polyhedron() is never
# validated in preview, so "renders clean" is NOT evidence of a valid solid.
cgal:
    #!/usr/bin/env bash
    set -uo pipefail
    mkdir -p "{{OUT}}/cgal"
    fail=0
    for f in examples/*.scad; do
      b=$(basename "${f%.scad}")
      # Wrap the example's part() in a PROVABLY NO-OP intersection. A subtracted
      # tiny cube would also force CGAL but perturbs the geometry -- at the
      # origin of a manifold that is inside the material.
      printf 'use <../../%s>;\nintersection() { part(); cube(1e6, center = true); }\n' "$f" \
        > "{{OUT}}/cgal/$b.wrap.scad"
      log="{{OUT}}/cgal/$b.log"
      openscad --hardwarnings -o "{{OUT}}/cgal/$b.stl" "{{OUT}}/cgal/$b.wrap.scad" >"$log" 2>&1 || true
      # "Simple: yes" alone is NOT a pass -- AGENTS.md says so, and this recipe
      # did not implement its own rule. Measured: a self-intersecting run logs
      # BOTH "CGAL ERROR: assertion violation!" and "Simple: yes", openscad
      # exits 0, and this reported ok.
      if grep -qiE 'CGAL error|assertion violation|Unable to convert|not.*valid 2-manifold' "$log"; then
        echo "  FAIL $b  (CGAL raised an error)"; grep -iE 'CGAL error|assertion violation|Unable to convert' "$log" | head -2 | sed 's/^/       /'; fail=1
      elif grep -q 'Simple: *yes' "$log"; then
        echo "  ok  $b  $(grep -m1 'Volumes:' "$log" | tr -s ' ')"
      else
        echo "  FAIL $b"; grep -iE 'Simple|not.*valid|ERROR' "$log" | head -3 | sed 's/^/       /'; fail=1
      fi
    done
    exit $fail

# The full pre-release gate: CGAL manifoldness plus the partspec contracts.
verify: cgal
    #!/usr/bin/env bash
    set -uo pipefail
    if [ -d checks ]; then just partspec; else echo "  (no checks/ directory)"; fi

# Declared engineering intent, verified. See checks/.
partspec:
    #!/usr/bin/env bash
    set -uo pipefail
    # partspec is a DEV-TIME oracle, not a library dependency: uniTube itself
    # still links to nothing. The mesh extra is required -- without it every
    # geometry check is skipped and the run reports "5 skipped", not a pass.
    if ! command -v uvx >/dev/null; then echo "  partspec needs uvx (astral uv); skipping"; exit 0; fi
    fail=0
    for d in checks/*/; do
      [ -f "$d/spec.py" ] || continue
      n=$(basename "$d")
      echo "  -- $n"
      uvx --from 'partspec[mesh]==0.7.6' partspec check "$d/spec.py" \
          --out "{{OUT}}/partspec/$n" 2>&1 | sed 's/^/     /' || fail=1
    done
    exit $fail

# Render every example to out/ for eyeballing.
render:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "{{OUT}}/render"
    find examples -name '*.scad' | sort | while IFS= read -r f; do
      openscad -o "{{OUT}}/render/$(basename "${f%.scad}").stl" "$f" 2>/dev/null
      echo "  {{OUT}}/render/$(basename "${f%.scad}").stl"
    done

# Remove all build output.
clean:
    rm -rf "{{OUT}}"
