%% =========================================================
%  FILE 1 — STEP1_vehicle_params.m
%  PURPOSE : Define all vehicle, terrain, and thermal parameters.
%            Run this file FIRST before anything else.
%  HOW TO RUN: >> run('STEP1_vehicle_params.m')
%              OR just press F5 / Run while this file is open.
%% =========================================================
 
clear; clc;
fprintf('=== Loading Vehicle & Terrain Parameters ===\n');
 
%% --- 1. VEHICLE PHYSICAL PARAMETERS ---
p.m    = 1800;       % Total vehicle mass (kg)  — EV SUV class
p.L    = 2.87;       % Wheelbase (m)
p.tw   = 1.60;       % Track width (m)
p.hcg  = 0.52;       % Centre-of-gravity height (m)
p.Iz   = 3200;       % Yaw moment of inertia (kg·m²)
p.a    = 1.30;       % CG to front axle (m)
p.b    = p.L - p.a;  % CG to rear axle (m)
 
%% --- 2. TYRE / CORNERING STIFFNESS ---
p.Cf   = 95000;      % Front cornering stiffness (N/rad)
p.Cr   = 90000;      % Rear cornering stiffness  (N/rad)
p.mu   = 0.85;       % Peak tyre–road friction coefficient (dry asphalt)
 
%% --- 3. DRIVETRAIN ---
p.R_wheel  = 0.33;   % Wheel radius (m)
p.T_max    = 900;    % Max torque per rear wheel (N·m)  — 4WD rear bias
p.T_base   = 450;    % Baseline drive torque per wheel (N·m)
p.eta_drive= 0.95;   % Drivetrain efficiency
 
%% --- 4. AERODYNAMICS ---
p.Cd  = 0.28;        % Drag coefficient
p.A   = 2.40;        % Frontal area (m²)
p.rho = 1.225;       % Air density (kg/m³)
 
%% --- 5. THERMAL DERATING THRESHOLDS (Battery Surface Temp) ---
%    Based on WLTP dataset (Scientific Data 2025) thermal profiles:
%    Normal operation : 20–35 °C
%    Warning zone     : 35–45 °C  → linear torque ramp-down
%    Critical zone    : 45–60 °C  → aggressive derating
%    Shutdown         : > 60 °C   → zero torque
th.T_safe  = 35;     % (°C) Full torque below this
th.T_warn  = 45;     % (°C) 50 % torque at this point
th.T_max   = 60;     % (°C) Zero torque at or above this
 
%% --- 6. TERRAIN PROFILE (Normal + Hilly, 10 s simulation) ---
%    time vector: 0..10 s at 100 Hz
t_sim  = 0 : 0.01 : 10;   % time (s)
N      = length(t_sim);
 
%  Road grade angle θ (rad) as a function of time
%    t = 0–3 s   : flat road      (0°)
%    t = 3–5 s   : uphill ramp    (0 → 8°)  
%    t = 5–7 s   : steep hill     (8°)
%    t = 7–9 s   : downhill ramp  (8° → -5°)
%    t = 9–10 s  : flat recovery  (0°)
theta_deg          = zeros(1, N);
theta_deg(t_sim >= 3 & t_sim < 5)  = 8 * (t_sim(t_sim >= 3 & t_sim < 5)  - 3) / 2;
theta_deg(t_sim >= 5 & t_sim < 7)  = 8;
theta_deg(t_sim >= 7 & t_sim < 9)  = 8 - 13*(t_sim(t_sim >= 7 & t_sim < 9) - 7)/2;
theta_deg(t_sim >= 9)               = 0;
terrain.theta      = deg2rad(theta_deg);  % road grade in radians
terrain.grade_pct  = tan(terrain.theta)*100; % percent grade
terrain.t          = t_sim;
 
%  Longitudinal speed profile (m/s) — accelerate then cruise
vx_profile         = zeros(1, N);
vx_profile         = 15 + 5*sin(pi*t_sim/10);  % smooth speed variation 15–20 m/s
terrain.vx         = vx_profile;
 
%% --- 7. STEERING INPUT (lane-keeping, gentle curve) ---
%    Small sinusoidal steering to simulate lane tracking
delta_profile      = 0.03 * sin(2*pi*0.3*t_sim);   % (rad) ≈ ±1.7°
terrain.delta      = delta_profile;
 
%% --- 8. SYNTHETIC BATTERY TEMPERATURE PROFILE ---
%    Replicates WLTP drive-cycle thermal profile from:
%    Scientific Data (2025) — surface temps 20-45°C with load-driven rise
%    Formula: T(t) = T_ambient + rise_from_load + terrain_spike
T_ambient   = 28;    % °C  (representative Indian subcontinent ambient)
T_load_rise = 12 * (1 - exp(-t_sim / 4));          % thermal lag from motor load
T_hill_spike= 6  * max(0, sin(pi*(t_sim-4)/4));     % extra heat during hill climb
T_recovery  = -3 * max(0, (t_sim - 8)/2);           % cooling on flat recovery
terrain.T_batt = T_ambient + T_load_rise + T_hill_spike + T_recovery;
 
% --- Clamp to physical range ---
terrain.T_batt = max(terrain.T_batt, T_ambient);
 
fprintf('  Vehicle mass        : %.0f kg\n', p.m);
fprintf('  Track width         : %.2f m\n', p.tw);
fprintf('  Max wheel torque    : %.0f N·m\n', p.T_max);
fprintf('  Simulation time     : %.1f s at 100 Hz\n', t_sim(end));
fprintf('  Terrain: flat → uphill (8°) → downhill (-5°) → flat\n');
fprintf('  Battery T range     : %.1f – %.1f °C\n', min(terrain.T_batt), max(terrain.T_batt));
fprintf('\nDone. Workspace now contains: p (params), th (thermal), terrain.\n');
fprintf('Next step → run STEP2_thermal_derating.m\n');
 