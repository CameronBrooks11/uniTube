// ut_turtle — a bender program as a path frontend.
//
//     ut_turtle([["feed", 60], ["bend", 90, "r", 24], ["feed", 40],
//                ["roll", 90], ["bend", 45, "r", 24], ["feed", 30]])
//
// This is the acceptance test for the whole multi-frontend thesis (ADR 0002):
// the spine is only canonical if a SECOND, very differently shaped frontend
// lowers to it without the spine growing a case.
//
// It is also literally how a CNC tube bender is programmed -- Length, Rotation,
// Angle -- and how bent-tube parts are specified in industry, which makes it
// round-trippable with real manufacturing data later.
//
// THE SHARPEST EVIDENCE THE IR IS RIGHT: `roll` emits NO GEOMETRY. It rotates
// the turtle's own up-vector, which changes the PLANE of every subsequent bend
// and therefore the shape of the path -- and then it is gone. Nothing about roll
// enters the spine, because a bender rotating the workpiece does not twist the
// tube. SPINE-5 (no roll in the IR) survives contact with the one frontend that
// has an explicit roll command.

// clang-format off
use <../ut_core.scad>;
use <../ut_math.scad>;
use <../ut_path.scad>;
// clang-format on

//   ["feed", d]                 straight, d mm along the current heading
//   ["bend", ang, "r", r]       bend by ang degrees at radius r, toward `up`
//   ["bend", ang, r]            the same, positionally
//   ["roll", ang]               rotate `up` about the heading. No geometry.
//
// A negative bend angle bends away from `up`. Bends larger than 180 degrees are
// split into equal arcs, because SPINE-4 caps a single arc at 180 so that the
// tangent sign can never be ambiguous.
function ut_turtle(cmds, start = [ 0, 0, 0 ], dir = [ 1, 0, 0 ], up = [ 0, 0, 1 ], frame = "transport", normal = undef,
                   twist = 0) = assert(len(cmds) > 0, "ut_turtle(): no commands")
    assert(abs(ut_unit(dir) * ut_unit(up)) < 1e-9, "ut_turtle(): up must be perpendicular to dir")
        ut_spine(_ut_tt(cmds, 0, start, ut_unit(dir), ut_unit(up), []), false,
                 concat([ [ "frame", frame ], [ "twist", twist ] ], is_undef(normal) ? [] : [[ "normal", normal ]]));

function _ut_bend_r(c) = c[2] == "r" ? c[3] : c[2];

// The fold. State is [pos, dir, up]; the accumulator is the segment list.
function _ut_tt(cmds, i, pos, dir, up, acc) =
    i >= len(cmds) ? assert(len(acc) > 0, "ut_turtle(): the commands produced no geometry") acc
    : let(c = cmds[i], kind = c[0]) kind == "roll" ? _ut_tt(cmds, i + 1, pos, dir, ut_rotv(up, c[1], dir), acc)
    : kind == "feed" ? assert(c[1] > ut_eps(), str("ut_turtle(): feed ", c[1], " at command ", i, " has no length"))
                           _ut_tt(cmds, i + 1, pos + c[1] * dir, dir, up, concat(acc, [ut_line(pos, pos + c[1] * dir)]))
    : kind == "bend" ? _ut_tt_bend(cmds, i, pos, dir, up, acc, c[1], _ut_bend_r(c))
                     : assert(false, str("ut_turtle(): unknown command \"", kind, "\" at index ", i)) acc;

function _ut_tt_bend(cmds, i, pos, dir, up, acc, ang, r) =
    assert(r > ut_eps(), str("ut_turtle(): bend radius ", r, " at command ", i, " must be positive"))
                assert(abs(ang) > ut_eps(),
                       str("ut_turtle(): bend of ", ang, " degrees at command ", i, " does nothing"))
            // SPINE-4 caps one arc at 180 degrees. Splitting is the FRONTEND's job:
            // the spine does not grow a case for it. The bend is replaced in
            // place by two halves and re-entered at the SAME index, so a bend of
            // any size converges by repeated halving.
            //
            // BOTH slices must be guarded against being empty. OpenSCAD SILENTLY
            // REVERSES a descending range -- [0:-1] evaluates to [-1, 0], with no
            // warning under --hardwarnings -- so an unguarded prefix splices
            // cmds[-1] (undef) into the program whenever the bend is the FIRST
            // command, and an unguarded suffix re-splices the bend itself when it
            // is the LAST. Measured: both aborted with
            // `unknown command "undef"`, naming the wrong cause entirely.
            abs(ang) > 180 - 1e-9
        ? _ut_tt(concat(i == 0 ? [] : [for (k = [0:i - 1]) cmds[k]], [ [ "bend", ang / 2, r ], [ "bend", ang / 2, r ] ],
                        i >= len(cmds) - 1 ? [] : [for (k = [i + 1:len(cmds) - 1]) cmds[k]]),
                 i, pos, dir, up, acc)
        : let(s = ang < 0 ? -1 : 1, a = abs(ang), toward = s * up, c = pos + r * toward,
              axis = ut_unit(cross(dir, toward)), u = ut_unit(pos - c), v = cross(axis, u))
              _ut_tt(cmds, i + 1, c + r * (cos(a) * u + sin(a) * v), -sin(a) * u + cos(a) * v, ut_rotv(up, a, axis),
                     concat(acc, [ut_arc(c, u, v, r, a)]));
