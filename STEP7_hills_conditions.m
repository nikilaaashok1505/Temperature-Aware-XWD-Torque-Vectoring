%% --- SMART THERMAL + PERFORMANCE MANAGEMENT ---

theta_deg_current = rad2deg(theta);

% --- Detect hill condition ---
slope_high = abs(theta_deg_current) > 5;   % threshold ~5°

% --- Define boost (how much extra torque allowed) ---
boost_factor = 0.25;   % 25% temporary boost
boost = boost_factor * p.T_max;

% --- Adaptive torque limit ---
if slope_high && alpha < 0.8
    % Allow temporary boost for hill climbing
    T_max_eff = min(p.T_max, alpha * p.T_max + boost);
    
    % Reduce torque vectoring (prioritize traction)
    T_diff = 0.5 * T_diff;   % damp vectoring
else
    % Normal thermal derating
    T_max_eff = alpha * p.T_max;
end

% --- Apply torque cap ---
T_base_dyn = min(T_base_dyn, T_max_eff);