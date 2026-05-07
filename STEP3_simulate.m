%% =========================================================
%  FILE 3 — STEP3_simulate.m
%  PURPOSE : Run the full closed-loop simulation:
%              - 4WD torque vectoring
%              - LQR yaw + lane-keeping controller
%              - Terrain-aware dynamics (flat + hilly)
%              - Thermal derating of max torque
%  REQUIRES: STEP1 and STEP2 must be run first.
%  HOW TO RUN: >> run('STEP3_simulate.m')
%% =========================================================

fprintf('=== Running Full Vehicle Dynamics Simulation ===\n');

%% --- SIMULATION SETUP ---
dt   = 0.01;                  % timestep (s) — 100 Hz
t    = terrain.t;             % time vector from STEP1
N    = length(t);

%% --- PRE-ALLOCATE LOG ARRAYS ---
vy_log       = zeros(1, N);   % lateral velocity (m/s)
r_log        = zeros(1, N);   % yaw rate (rad/s)
e_lat_log    = zeros(1, N);   % lateral lane error (m)
e_hdg_log    = zeros(1, N);   % heading error (rad)
T_left_log   = zeros(1, N);   % left wheel torque (N·m)
T_right_log  = zeros(1, N);   % right wheel torque (N·m)
T_fl_log     = zeros(1, N);   % front-left torque (N·m)
T_fr_log     = zeros(1, N);   % front-right torque (N·m)
delta_log    = zeros(1, N);   % actual steering command (rad)
Tdiff_log    = zeros(1, N);   % torque difference command (N·m)
ax_log       = zeros(1, N);   % longitudinal accel (m/s²)
Frr_log      = zeros(1, N);   % rolling resistance force (N)
Fgrade_log   = zeros(1, N);   % grade resistance force (N)
Fdrag_log    = zeros(1, N);   % aerodynamic drag force (N)
r_des_log    = zeros(1, N);   % desired yaw rate (rad/s)
alpha_log    = terrain.alpha; % thermal derating (pre-computed)

%% --- INITIAL STATE ---
x = [0; 0; 0; 0];   % [vy, psi_dot, e_lat, e_heading]

%% --- MAIN SIMULATION LOOP ---
for k = 1 : N
    
    vx     = terrain.vx(k);        % current longitudinal speed (m/s)
    delta  = terrain.delta(k);     % driver steering input (rad)
    theta  = terrain.theta(k);     % road grade (rad)
    T_batt = terrain.T_batt(k);    % battery surface temperature (°C)
    alpha  = alpha_log(k);         % thermal derating factor [0,1]
    
    %% -- DESIRED YAW RATE (steady-state bicycle model) --
    K_us   = (p.m / p.L^2) * (p.b/p.Cf - p.a/p.Cr);   % understeer gradient
    if abs(vx) > 1
        r_des = (vx * delta) / (p.L * (1 + K_us * vx^2));
    else
        r_des = 0;
    end
    r_des = max(min(r_des, 0.5), -0.5);   % physical yaw rate limit
    
    %% -- LQR CONTROL LAW --
    %  State error from desired: [vy, (r - r_des), e_lat, e_heading]
    x_err = x - [0; r_des; 0; 0];
    u     = -K_lqr * x_err;       % u = [delta_cmd, T_diff]
    
    delta_cmd = u(1);              % steering correction (rad)
    T_diff    = u(2);              % torque difference (N·m)
    
    %  Total steering: driver input + LQR correction
    delta_total = delta + delta_cmd;
    delta_total = max(min(delta_total, 0.5), -0.5);  % saturate ±0.5 rad
    
    %% -- TERRAIN LOAD TORQUE DEMAND --
    %  Forces that the drivetrain must overcome:
    Fgrade = p.m * 9.81 * sin(theta);            % grade resistance (N)
    Frr    = 0.015 * p.m * 9.81 * cos(theta);    % rolling resistance (N)
    Fdrag  = 0.5 * p.rho * p.Cd * p.A * vx^2;   % aero drag (N)
    F_load = Fgrade + Frr + Fdrag;                % total longitudinal load
    
    %  Torque demand per wheel to overcome terrain
    T_terrain_per_wheel = (F_load * p.R_wheel) / (4 * p.eta_drive);
    T_base_dyn = p.T_base + T_terrain_per_wheel;  % dynamic base torque
    
    %% -- THERMAL DERATING APPLICATION --
    T_max_eff = alpha * p.T_max;                  % effective max torque
    T_base_dyn = min(T_base_dyn, T_max_eff);      % cap to thermal limit
    
    
    %% -- TORQUE ALLOCATION (4WD: rear vectoring, front baseline) --
    %  Rear wheels get the torque vectoring correction
    T_rear_right = T_base_dyn + T_diff/2;
    T_rear_left  = T_base_dyn - T_diff/2;
    
    %  Front wheels: flat split, 30% of rear torque (4WD bias)
    T_front_each = 0.30 * T_base_dyn;
    
    %  Saturate all wheels between 0 and thermal-limited max
    T_rear_right = min(max(T_rear_right, 0), T_max_eff);
    T_rear_left  = min(max(T_rear_left,  0), T_max_eff);
    T_front_each = min(max(T_front_each, 0), 0.5 * T_max_eff);
    
    %% -- VEHICLE DYNAMICS (4-STATE BICYCLE MODEL + GRADE) --
    %  Tyre slip angles
    if abs(vx) > 0.5
        alpha_f = delta_total - (x(1) + p.a * x(2)) / vx;
        alpha_r =              - (x(1) - p.b * x(2)) / vx;
    else
        alpha_f = 0;  alpha_r = 0;
    end
    
    %  Lateral tyre forces (linear model)
    Fy_f = p.Cf * alpha_f;
    Fy_r = p.Cr * alpha_r;
    
    %  Yaw moment from torque vectoring
    M_tv = (T_rear_right - T_rear_left) / p.tw;
    
    %  State derivatives
    dx    = zeros(4,1);
    dx(1) = (Fy_f + Fy_r) / p.m - vx * x(2);          % vy_dot
    dx(2) = (p.a*Fy_f - p.b*Fy_r + M_tv) / p.Iz;      % psi_ddot
    dx(3) = x(1) + vx * x(4);                           % e_lat_dot
    dx(4) = x(2) - r_des;                               % e_heading_dot
    
    %  Euler integration
    x = x + dx * dt;
    
    %  Longitudinal acceleration (informational)
    F_net = (T_rear_right + T_rear_left + 2*T_front_each) / p.R_wheel ...
            - F_load - p.m*9.81*sin(theta);
    ax    = F_net / p.m;
    
    %% -- LOG RESULTS --
    vy_log(k)      = x(1);
    r_log(k)       = x(2);
    e_lat_log(k)   = x(3);
    e_hdg_log(k)   = x(4);
    T_left_log(k)  = T_rear_left;
    T_right_log(k) = T_rear_right;
    T_fl_log(k)    = T_front_each;
    T_fr_log(k)    = T_front_each;
    delta_log(k)   = delta_total;
    Tdiff_log(k)   = T_diff;
    ax_log(k)      = ax;
    Frr_log(k)     = Frr;
    Fgrade_log(k)  = Fgrade;
    Fdrag_log(k)   = Fdrag;
    r_des_log(k)   = r_des;
end

%% --- PACK RESULTS INTO STRUCT ---
results.t          = t;
results.vy         = vy_log;
results.r          = r_log;
results.r_des      = r_des_log;
results.e_lat      = e_lat_log;
results.e_hdg      = e_hdg_log;
results.T_left     = T_left_log;
results.T_right    = T_right_log;
results.T_fl       = T_fl_log;
results.T_fr       = T_fr_log;
results.T_diff     = Tdiff_log;
results.delta      = delta_log;
results.ax         = ax_log;
results.Fgrade     = Fgrade_log;
results.Frr        = Frr_log;
results.Fdrag      = Fdrag_log;
results.T_batt     = terrain.T_batt;
results.alpha      = alpha_log;
results.vx         = terrain.vx;
results.theta_deg  = rad2deg(terrain.theta);

fprintf('  Simulation complete: %d steps @ %.0f Hz\n', N, 1/dt);
fprintf('  Max lateral error   : %.4f m\n',    max(abs(results.e_lat)));
fprintf('  Max yaw rate error  : %.4f rad/s\n', max(abs(results.r - results.r_des)));
fprintf('  Min alpha (derating): %.2f at T=%.1f°C\n', ...
        min(results.alpha), max(results.T_batt));
fprintf('  Max T_right         : %.1f N·m\n',  max(results.T_right));
fprintf('  Max T_left          : %.1f N·m\n',  max(results.T_left));
fprintf('\nDone. Workspace now contains: results struct.\n');
fprintf('Next step → run STEP4_plot.m\n');