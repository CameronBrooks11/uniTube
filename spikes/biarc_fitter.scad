// SPIKE — biarc fitter prototype. NOT PART OF THE LIBRARY.
//
// Preserved deliberately (BACKLOG.md §3, decision 4). Nothing under src/ imports
// it, `just check` does not render it, and it is not on any release path.
//
// WHY IT IS NOT BUILT: PLAN.md §10 called biarc fitting "the single highest-value
// deferred item" on the grounds that a sampled P segment forfeits exact
// arclength, exact transport and CHECK-1. Measured, that billing is wrong:
//
//   arclength   0.025% at n=160 -- 0.19 mm on a 758 mm helix, and s is only ever
//               used as a RATIO (s_i/s_last), so a uniform shrink cancels exactly
//   transport   0.04 deg end-normal error, clean second order
//   CHECK-1     a REAL hole -- but closed in ~8 lines of discrete curvature
//               (src/ut_check.scad, _ut_min_circumradius), at the same accuracy
//
// And the one error large enough to ruin a physical part -- the end tangent --
// a fitter does NOT fix, because it derives span tangents from the same
// estimator. That was closed by a one-line three-point difference instead
// (2.237 -> 0.0141 deg at n=160).
//
// THE ARGUMENT THAT REMAINS, and it is real: RESOLUTION INDEPENDENCE. Measured,
// an arc-based path gives 7 stations at $fa=24 and 183 at $fa=0.5; a sampled path
// gives 161 either way. $fa and $fs are INERT on a P segment, so SPINE-5 ("no
// roll, no resolution") does not hold for it -- see docs/ir.md, which now says so.
// A fitter is the only route to fixing that, and it is also the prerequisite for
// ut_bezier and ut_bend_table.
//
// BUILD IT when one of those becomes a real requirement rather than a table
// entry. When you do: it belongs in src/frontend/ where f is still callable -- a
// spine-level refit of an existing P segment has no ground truth to fit against.
//
EPS = 1e-12;

// ---- biarc core -------------------------------------------------------------
// Equal-tangent-length biarc. Control points C1=P1+d*T1, C2=P2-d*T2.
// Existence condition |C2-C1| = 2d  ->  A d^2 + B d + C = 0.
function bi_d(P1,T1,P2,T2) =
  let(V = P2-P1, A = 2*(T1*T2 - 1), B = -2*(V*(T1+T2)), C = V*V)
  abs(A) < 1e-12
    ? (abs(B) < 1e-12 ? undef : -C/B)
    : let(disc = B*B - 4*A*C, sq = sqrt(max(disc,0)),
          r1 = (-B+sq)/(2*A), r2 = (-B-sq)/(2*A))
      (r1 > 1e-12 ? r1 : r2);

// one arc from P with tangent Tg to Q; returns a LIST of segments (splits >180)
function bi_leg(P, Tg, Q) =
  let(ch = Q-P, L = norm(ch), cx = cross(Tg, ch), s = norm(cx), phi = ut_turn(Tg, ch))
  (L < EPS) ? []
  : (s/L < 1e-9 || phi < 5e-5) ? [["L", P, Q]]
  : let(n = cx/s, m = cross(n, Tg), r = L/(2*sin(phi)), c = P + r*m,
        u = -m, v = cross(n,u), ang = 2*phi)
    ang <= 180 ? [ut_arc(c,u,v,r,ang)]
    : let(h = ang/2, u2 = cos(h)*u + sin(h)*v, v2 = -sin(h)*u + cos(h)*v)
      [ut_arc(c,u,v,r,h), ut_arc(c,u2,v2,r,h)];

function bi_span(P1,T1,P2,T2) =
  let(V = P2-P1, Lv = norm(V))
  (Lv < EPS) ? []
  : (norm(cross(T1,V))/Lv < 1e-9 && norm(cross(T2,V))/Lv < 1e-9 && T1*T2 > 0) ? [["L",P1,P2]]
  : let(d = bi_d(P1,T1,P2,T2))
    is_undef(d) || d <= 0 ? [["L",P1,P2]]
    : let(C1 = P1 + d*T1, C2 = P2 - d*T2, e = C2-C1, ne = norm(e))
      ne < EPS ? [["L",P1,P2]]
      : let(TJ = e/ne, J = C1 + d*TJ)
        concat(bi_leg(P1,T1,J), bi_leg(J,TJ,P2));

// ---- distance from a point to a segment ------------------------------------
function d_L(sg,q) = let(a=sg[1], b=sg[2], ab=b-a, L2=ab*ab,
                         u = L2<EPS?0:max(0,min(1,((q-a)*ab)/L2))) norm(q-(a+u*ab));
function d_A(sg,q) = let(c=sg[1],u=sg[2],v=sg[3],r=sg[4],ang=sg[5], n=cross(u,v),
                         w=q-c, oo=(w*n), wp=w-oo*n, lp=norm(wp),
                         a0=atan2(wp*v, wp*u), a=(a0<0?a0+360:a0))
  (lp>EPS && a<=ang) ? sqrt(pow(lp-r,2)+oo*oo)
  : min(norm(q-(c+r*u)), norm(q-(c+r*(cos(ang)*u+sin(ang)*v))));
function d_seg(sg,q) = sg[0]=="L" ? d_L(sg,q) : d_A(sg,q);
function d_segs(sgs,q,i=0) = i>=len(sgs) ? 1e18 : min(d_seg(sgs[i],q), d_segs(sgs,q,i+1));

// ---- adaptive fit -----------------------------------------------------------
NPROBE = 3;
function span_err(sgs, f, t0, t1, k=1) =
  k > NPROBE ? 0
  : max(d_segs(sgs, f(t0 + (t1-t0)*k/(NPROBE+1))), span_err(sgs,f,t0,t1,k+1));

function fit(f, df, t0, t1, tol, depth) =
  let(P1=f(t0), P2=f(t1), T1=ut_unit(df(t0)), T2=ut_unit(df(t1)),
      sgs = bi_span(P1,T1,P2,T2),
      e = len(sgs)==0 ? 0 : span_err(sgs, f, t0, t1))
  (depth<=0 || (len(sgs)>0 && e<=tol)) ? sgs
  : let(tm=(t0+t1)/2) concat(fit(f,df,t0,tm,tol,depth-1), fit(f,df,tm,t1,tol,depth-1));

function fit_curve(f, df, t=[0,1], tol=0.05, seed=4, maxdepth=10) =
  [ for (i=[0:seed-1]) each fit(f, df, t[0]+(t[1]-t[0])*i/seed, t[0]+(t[1]-t[0])*(i+1)/seed, tol, maxdepth) ];

