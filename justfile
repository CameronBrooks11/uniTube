# uniTube — The Universal Tube Library for OpenSCAD
#
# uniTube has NO dependencies. A fresh clone renders immediately; `just setup`
# only verifies the toolchain. See PLAN.md §9.1 for why.

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

    # RULE 1 — src/ may never import from reference/ (licence quarantine).
    if grep -rnE '^[[:space:]]*(use|include)[[:space:]]*<[^>]*reference/' src/ 2>/dev/null; then
      echo "LINT FAIL: a file under src/ imports from reference/ (see AGENTS.md)"; fail=1
    fi

    # RULE 2 — no file under src/ may emit top-level geometry or echo on import.
    # Top-level statements sit at column 0; `function f(` / `module m(` / `use <`
    # / assignments do not match this pattern, but `cube(`, `echo(`, `if (` do.
    if find src -name '*.scad' -print0 2>/dev/null \
         | xargs -0 -r grep -nE '^[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(' ; then
      echo "LINT FAIL: top-level geometry or echo under src/ (library and demo must not share a file)"; fail=1
    fi

    [ $fail -eq 0 ] && echo "lint ok"
    exit $fail

# CI equivalent: formatting + rules + every example and test renders warning-free.
check: fmt-check lint
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "{{OUT}}/check"
    n=0
    while IFS= read -r f; do
      # --hardwarnings turns an unknown named argument into exit 1. Without it
      # OpenSCAD exits 0 — that is the exact bug class that broke this library
      # for 19 months (see PLAN.md §1). Never drop this flag.
      # The target MUST be .stl: with -o *.csg a failing assert() exits 0.
      openscad --hardwarnings -o "{{OUT}}/check/$(basename "${f%.scad}").stl" "$f" 2>&1 \
        | sed "s|^|    [$(basename "$f")] |" || { echo "CHECK FAIL: $f"; exit 1; }
      n=$((n+1))
    done < <(find examples tests -name '*.scad' 2>/dev/null | sort)
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
    done < <(find tests -name '*.scad' 2>/dev/null | sort)
    echo "test ok ($n file(s))"

# Slow mesh-property gate: forced CGAL manifoldness. Run before a release.
verify:
    #!/usr/bin/env bash
    set -euo pipefail
    # An example opts in by forcing a boolean (see examples/00_smoke.scad); a raw
    # polyhedron() is never validated otherwise, so "renders clean" proves nothing.
    mkdir -p "{{OUT}}/verify"
    fail=0
    while IFS= read -r f; do
      log="{{OUT}}/verify/$(basename "${f%.scad}").log"
      openscad --hardwarnings -o "{{OUT}}/verify/$(basename "${f%.scad}").stl" "$f" >"$log" 2>&1 || fail=1
      if grep -qiE 'not.*valid 2-manifold|CGAL error' "$log"; then
        echo "VERIFY FAIL: $f"; grep -iE 'not.*valid|CGAL error' "$log" | sed 's/^/    /'; fail=1
      elif grep -q 'Simple:' "$log"; then
        echo "  $(basename "$f"): $(grep -m1 'Simple:' "$log" | tr -s ' ')"
      else
        echo "  $(basename "$f"): no CGAL report (does not force a boolean — not verified)"
      fi
    done < <(find examples -name '*.scad' 2>/dev/null | sort)
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
