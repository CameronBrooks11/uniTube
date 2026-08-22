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

    # RULE 3 — import lines must be well-formed. clang-format rewrites
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

# CI equivalent: formatting + rules + every example and test renders warning-free.
check: fmt-check lint guards
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
