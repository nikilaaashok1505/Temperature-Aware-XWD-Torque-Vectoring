%% =========================================================
%  FILE 4 — STEP4_plot.m
%  PURPOSE : Generate a comprehensive 9-panel result dashboard
%            showing vehicle dynamics, torque, terrain, and thermal.
%  REQUIRES: STEP3_simulate.m to have been run first.
%  HOW TO RUN: >> run('STEP4_plot.m')
%% =========================================================

fprintf('=== Generating Simulation Dashboard ===\n');

t = results.t;

%% ---- COLOUR SCHEME (consistent, engineering style) ----
c_right   = [0.85, 0.20, 0.20];   % red    — right wheel
c_left    = [0.20, 0.45, 0.85];   % blue   — left wheel
c_des     = [0.20, 0.65, 0.20];   % green  — desired/reference
c_actual  = [0.10, 0.10, 0.10];   % black  — actual
c_temp    = [0.95, 0.55, 0.10];   % orange — temperature
c_alpha   = [0.60, 0.20, 0.70];   % purple — derating
c_grade   = [0.50, 0.30, 0.10];   % brown  — terrain
c_front   = [0.30, 0.70, 0.60];   % teal   — front axle

figure('Name', 'EV 4WD Torque Vectoring — Full Simulation Dashboard', ...
       'Color', [0.97 0.97 0.97], ...
       'Position', [50, 30, 1400, 950]);

%% ---- PANEL 1: TERRAIN (Road Grade) ----
subplot(3, 3, 1);
area(t, results.theta_deg, 'FaceColor', [0.80 0.70 0.55], 'EdgeColor', c_grade, 'LineWidth', 1.5, 'FaceAlpha', 0.6);
hold on;
plot(t, zeros(size(t)), 'k--', 'LineWidth', 0.8);
xlabel('Time (s)'); ylabel('Road Grade (°)');
title('Terrain Profile', 'FontWeight', 'bold');
legend('Grade angle', 'Flat', 'Location', 'northeast');
grid on; xlim([t(1), t(end)]);
text(4.5, 7, 'Hill Climb', 'FontSize', 8, 'Color', c_grade, 'FontWeight', 'bold');
text(7.5, -4, 'Descent', 'FontSize', 8, 'Color', [0.2 0.5 0.9], 'FontWeight', 'bold');

%% ---- PANEL 2: LONGITUDINAL SPEED ----
subplot(3, 3, 2);
plot(t, results.vx, 'Color', c_actual, 'LineWidth', 2);
xlabel('Time (s)'); ylabel('Speed (m/s)');
title('Longitudinal Speed', 'FontWeight', 'bold');
grid on; xlim([t(1), t(end)]);
ylim([12, 22]);

%% ---- PANEL 3: BATTERY TEMPERATURE + DERATING ----
subplot(3, 3, 3);
yyaxis left;
plot(t, results.T_batt, 'Color', c_temp, 'LineWidth', 2.5);
yline(35, '--', 'T_{safe}=35°C', 'Color', c_des,   'LineWidth', 1, 'LabelHorizontalAlignment','left', 'FontSize', 7);
yline(45, '--', 'T_{warn}=45°C', 'Color', [0.9 0.7 0], 'LineWidth', 1, 'LabelHorizontalAlignment','left', 'FontSize', 7);
yline(60, '--', 'T_{max}=60°C',  'Color', c_right, 'LineWidth', 1, 'LabelHorizontalAlignment','left', 'FontSize', 7);
ylabel('Battery Temp (°C)', 'Color', c_temp);
ax = gca; ax.YColor = c_temp;

yyaxis right;
plot(t, results.alpha * 100, 'Color', c_alpha, 'LineWidth', 2, 'LineStyle', '--');
ylabel('Derating α (%)', 'Color', c_alpha);
ax.YColor = c_alpha;

xlabel('Time (s)');
title('Battery Temp & Thermal Derating', 'FontWeight', 'bold');
legend({'T_{battery}', '', '', '', '\alpha(T)'}, 'Location', 'northeast', 'FontSize', 7);
grid on; xlim([t(1), t(end)]);

%% ---- PANEL 4: REAR WHEEL TORQUE (Left vs Right) ----
subplot(3, 3, 4);
plot(t, results.T_right, 'Color', c_right, 'LineWidth', 2, 'DisplayName', 'Rear Right');
hold on;
plot(t, results.T_left,  'Color', c_left,  'LineWidth', 2, 'DisplayName', 'Rear Left');
plot(t, results.T_fr,    'Color', c_front, 'LineWidth', 1.5, 'LineStyle', ':', 'DisplayName', 'Front (each)');
xlabel('Time (s)'); ylabel('Torque (N·m)');
title('Wheel Torque Allocation (4WD)', 'FontWeight', 'bold');
legend('Location', 'northeast', 'FontSize', 8);
grid on; xlim([t(1), t(end)]);
% Annotate thermal shutdown region if any
if any(results.alpha < 0.05)
    xregion_start = t(find(results.alpha < 0.05, 1, 'first'));
    xregion_end   = t(find(results.alpha < 0.05, 1, 'last'));
    patch([xregion_start xregion_end xregion_end xregion_start], ...
          [0 0 900 900], 'r', 'FaceAlpha', 0.08, 'EdgeColor', 'none');
    text(xregion_start, 820, 'Thermal Shutdown', 'FontSize', 7, 'Color', 'r');
end

%% ---- PANEL 5: TORQUE DIFFERENCE (Vectoring Command) ----
subplot(3, 3, 5);
area(t, results.T_diff, 'FaceColor', [0.90 0.85 0.95], 'EdgeColor', c_alpha, 'LineWidth', 1.5);
hold on;
yline(0, 'k--', 'LineWidth', 0.8);
xlabel('Time (s)'); ylabel('T_{diff} (N·m)');
title('Torque Vectoring Command (ΔT)', 'FontWeight', 'bold');
grid on; xlim([t(1), t(end)]);
text(0.5, max(results.T_diff)*0.8, 'Right > Left (turn right)', 'FontSize', 7, 'Color', c_right);
text(0.5, min(results.T_diff)*0.8, 'Left > Right (turn left)',  'FontSize', 7, 'Color', c_left);

%% ---- PANEL 6: YAW RATE (Actual vs Desired) ----
subplot(3, 3, 6);
plot(t, results.r_des * (180/pi), 'Color', c_des,    'LineWidth', 2, 'LineStyle', '--', 'DisplayName', 'Desired r*');
hold on;
plot(t, results.r     * (180/pi), 'Color', c_actual, 'LineWidth', 2, 'DisplayName', 'Actual r');
xlabel('Time (s)'); ylabel('Yaw Rate (°/s)');
title('Yaw Rate Tracking', 'FontWeight', 'bold');
legend('Location', 'northeast', 'FontSize', 8);
grid on; xlim([t(1), t(end)]);

%% ---- PANEL 7: LATERAL LANE ERROR ----
subplot(3, 3, 7);
plot(t, results.e_lat * 100, 'Color', c_left, 'LineWidth', 2);
hold on;
yline(0, '--', 'LineWidth', 1, 'Color', [0.5 0.5 0.5]);
yline( 10, ':', 'Lane boundary +10cm', 'Color', [0.8 0.2 0.2], 'FontSize', 7, 'LabelHorizontalAlignment', 'left');
yline(-10, ':', 'Lane boundary -10cm', 'Color', [0.8 0.2 0.2], 'FontSize', 7, 'LabelHorizontalAlignment', 'left');
xlabel('Time (s)'); ylabel('Lateral Error (cm)');
title('Lane Keeping Error', 'FontWeight', 'bold');
grid on; xlim([t(1), t(end)]);

%% ---- PANEL 8: TERRAIN FORCES BREAKDOWN ----
subplot(3, 3, 8);
area(t, results.Fgrade, 'FaceColor', [0.95 0.85 0.70], 'EdgeColor', c_grade, 'LineWidth', 1.2, 'DisplayName', 'Grade');
hold on;
area(t, results.Fdrag,  'FaceColor', [0.70 0.85 0.95], 'EdgeColor', c_left,  'LineWidth', 1.2, 'FaceAlpha', 0.7, 'DisplayName', 'Aero Drag');
area(t, results.Frr,    'FaceColor', [0.80 0.95 0.75], 'EdgeColor', c_des,   'LineWidth', 1.2, 'FaceAlpha', 0.7, 'DisplayName', 'Rolling Resist.');
xlabel('Time (s)'); ylabel('Force (N)');
title('Longitudinal Road Load Breakdown', 'FontWeight', 'bold');
legend('Location', 'northeast', 'FontSize', 7);
grid on; xlim([t(1), t(end)]);

%% ---- PANEL 9: LATERAL VELOCITY + STEERING ----
subplot(3, 3, 9);
yyaxis left;
plot(t, results.vy * 100, 'Color', c_actual, 'LineWidth', 2);
ylabel('Lateral Velocity (cm/s)', 'Color', c_actual);
yyaxis right;
plot(t, rad2deg(results.delta), 'Color', c_right, 'LineWidth', 1.5, 'LineStyle', '--');
ylabel('Steering Angle (°)', 'Color', c_right);
xlabel('Time (s)');
title('Lateral Velocity & Steering', 'FontWeight', 'bold');
grid on; xlim([t(1), t(end)]);
legend({'v_y', 'δ (steering)'}, 'Location', 'northeast', 'FontSize', 8);

%% ---- GLOBAL TITLE ----
sgtitle('EV 4WD Torque Vectoring — Thermal-Aware LQR Controller | Flat & Hilly Terrain', ...
        'FontSize', 14, 'FontWeight', 'bold', 'Color', [0.15 0.15 0.15]);

%% ---- PRINT SUMMARY TABLE ----
fprintf('\n=========== SIMULATION SUMMARY ===========\n');
fprintf('  Peak road grade          : %+.1f°\n',  max(results.theta_deg));
fprintf('  Min road grade           : %+.1f°\n',  min(results.theta_deg));
fprintf('  Max battery temperature  : %.1f °C\n',  max(results.T_batt));
fprintf('  Min thermal derating α   : %.2f  (%.0f%% torque)\n', min(results.alpha), min(results.alpha)*100);
fprintf('  Max rear torque (right)  : %.1f N·m\n', max(results.T_right));
fprintf('  Max rear torque (left)   : %.1f N·m\n', max(results.T_left));
fprintf('  Peak torque difference ΔT: %.1f N·m\n', max(abs(results.T_diff)));
fprintf('  Max lateral lane error   : %.4f m (%.2f cm)\n', max(abs(results.e_lat)), max(abs(results.e_lat))*100);
fprintf('  Max yaw rate error       : %.4f rad/s\n', max(abs(results.r - results.r_des)));
fprintf('==========================================\n');
fprintf('\nDone. Dashboard figure now open.\n');
fprintf('Next step → run STEP5_simulink_builder.m to build the Simulink model.\n');