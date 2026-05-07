%% =========================================================
%  FILE 0 — RUN_ALL.m
%  PURPOSE : Master script — runs all 5 steps in sequence.
%            Just run this ONE file to get everything.
%  HOW TO RUN: >> run('RUN_ALL.m')
%              OR press F5 while this file is open.
%% =========================================================

clc; clear; close all;

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════╗\n');
fprintf('║  EV 4WD THERMAL-AWARE TORQUE VECTORING SIMULATION   ║\n');
fprintf('║  LQR Controller | Terrain: Flat + Hilly | 4-Wheel   ║\n');
fprintf('╚══════════════════════════════════════════════════════╝\n\n');

%% STEP 1 — Vehicle params, terrain, temperature profile
fprintf('[1/5] Loading vehicle parameters and terrain...\n');
run('STEP1_vehicle_params.m');
fprintf('\n');

%% STEP 2 — Thermal derating + LQR design
fprintf('[2/5] Designing thermal derating and LQR controller...\n');
run('STEP2_thermal_derating.m');
fprintf('\n');

%% STEP 3 — Run simulation
fprintf('[3/5] Running closed-loop simulation...\n');
run('STEP3_simulate.m');
fprintf('\n');

%% STEP 4 — Plot results
fprintf('[4/5] Generating result dashboard...\n');
run('STEP4_plot.m');
fprintf('\n');

%% STEP 5 — Build Simulink model
fprintf('[5/5] Building Simulink model (TV_Thermal_4WD.slx)...\n');
run('STEP5_simulink_builder.m');
fprintf('\n');

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════╗\n');
fprintf('║  ALL DONE!                                           ║\n');
fprintf('║  • Dashboard figure: open on screen                 ║\n');
fprintf('║  • Simulink model:   TV_Thermal_4WD.slx (open)      ║\n');
fprintf('║  • All data in workspace: results, terrain, p, th   ║\n');
fprintf('╚══════════════════════════════════════════════════════╝\n');