%% =========================================================
%  FILE 2 — STEP2_thermal_derating.m
%  PURPOSE : (a) Define the thermal derating function alpha(T)
%                which scales max torque based on battery temp.
%            (b) Design the LQR controller for yaw + lane keeping.
%  REQUIRES: STEP1_vehicle_params.m to have been run first.
%  HOW TO RUN: >> run('STEP2_thermal_derating.m')
%% =========================================================

fprintf('=== Designing Thermal Derating + LQR Controller ===\n');

%% --- 1. THERMAL DERATING FUNCTION alpha(T) ---
%
%  alpha(T) maps battery surface temperature to a torque scale factor:
%
%   T <= T_safe  : alpha = 1.0  (full torque)
%   T_safe < T < T_warn : linear ramp  1.0 → 0.5
%   T_warn < T < T_max  : linear ramp  0.5 → 0.0
%   T >= T_max   : alpha = 0.0  (thermal shutdown)
%
%  This protects battery longevity and prevents thermal runaway.

alpha_fn = @(T) max(0, ...
    (T <= th.T_safe) .* 1.0 + ...
    (T > th.T_safe & T <= th.T_warn) .* (1.0 - 0.5*(T - th.T_safe)/(th.T_warn - th.T_safe)) + ...
    (T > th.T_warn & T <  th.T_max ) .* (0.5 - 0.5*(T - th.T_warn)/(th.T_max  - th.T_warn)) ...
);

% Pre-compute alpha over entire battery temperature profile
terrain.alpha = alpha_fn(terrain.T_batt);

fprintf('  Thermal derating alpha(T):\n');
fprintf('    T = 25°C  →  alpha = %.2f\n', alpha_fn(25));
fprintf('    T = 35°C  →  alpha = %.2f\n', alpha_fn(35));
fprintf('    T = 40°C  →  alpha = %.2f\n', alpha_fn(40));
fprintf('    T = 45°C  →  alpha = %.2f\n', alpha_fn(45));
fprintf('    T = 55°C  →  alpha = %.2f\n', alpha_fn(55));
fprintf('    T = 60°C  →  alpha = %.2f\n', alpha_fn(60));

%% --- 2. LINEARISED BICYCLE MODEL (state-space for LQR design) ---
%
%  4-state model:  x = [vy, psi_dot, e_lat, e_heading]
%    vy         : lateral velocity (m/s)
%    psi_dot    : yaw rate (rad/s)
%    e_lat      : lateral lane error (m)
%    e_heading  : heading error (rad)
%
%  Control input: u = [delta_cmd, T_diff]
%    delta_cmd  : steering correction (rad)
%    T_diff     : left–right torque difference (N·m)

vx_design = 18;   % linearise at 18 m/s (mid-range cruise speed)

Cf = p.Cf;  Cr = p.Cr;
m  = p.m;   Iz = p.Iz;
a  = p.a;   b  = p.b;
tw = p.tw;

% State matrix A (4x4)
A = [ -(Cf+Cr)/(m*vx_design),           (-(Cf*a - Cr*b)/(m*vx_design) - vx_design),  0,  0;
      -(Cf*a - Cr*b)/(Iz*vx_design),    -(Cf*a^2 + Cr*b^2)/(Iz*vx_design),           0,  0;
       1,                                 0,                                            0,  vx_design;
       0,                                 1,                                            0,  0       ];

% Input matrix B (4x2): columns = [delta_cmd, T_diff]
B = [ Cf/m,               0;
      Cf*a/Iz,             1/(Iz*tw);   % T_diff creates yaw via tw
      0,                   0;
      0,                   0          ];

%% --- 3. LQR CONTROLLER DESIGN ---
%
%  Q weights: penalise lateral error (e_lat) and yaw rate heavily
%  R weights: modest penalty on control effort
%
%  Tuning guide:
%    Increase Q(3,3) → tighter lane keeping
%    Increase Q(2,2) → snappier yaw response
%    Increase R      → smoother, less aggressive control

Q = diag([10,   ...   % vy        - moderate
          200,  ...   % psi_dot   - high (yaw stability priority)
          500,  ...   % e_lat     - very high (lane keeping)
          100]);      % e_heading - high

R = diag([0.5,  ...   % delta_cmd effort
          1e-5]);     % T_diff effort (small R = allow large torque diff)

% Solve Riccati equation
[K_lqr, ~, ~] = lqr(A, B, Q, R);

fprintf('\n  LQR gain matrix K (2x4):\n');
fprintf('    K = \n');
disp(K_lqr);
fprintf('  State-space: A(%dx%d), B(%dx%d)\n', size(A,1), size(A,2), size(B,1), size(B,2));
fprintf('\nDone. Workspace now contains: alpha_fn, K_lqr, A, B.\n');
fprintf('Next step → run STEP3_simulate.m\n');