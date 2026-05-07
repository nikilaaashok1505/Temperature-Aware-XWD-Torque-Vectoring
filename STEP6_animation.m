%% =========================================================
% STEP6_REALTIME_VISUAL_ULTRA.m
% ULTRA-REALISTIC 3D Environment + Live Telemetry Graphs
% Requires: results struct, terrain struct
%% =========================================================

t     = results.t;
vx    = results.vx;
vy    = results.vy;
r     = results.r;
T     = results.T_batt;
alpha = results.alpha;
theta = terrain.theta;

%% ---- Integrate position, heading, elevation ----
N   = length(t);
x   = zeros(1,N);
y   = zeros(1,N);
z   = zeros(1,N);
psi = zeros(1,N);
dt  = t(2) - t(1);

for i = 2:N
    psi(i) = psi(i-1) + r(i)*dt;
    x(i)   = x(i-1) + (vx(i)*cos(psi(i)) - vy(i)*sin(psi(i)))*dt;
    y(i)   = y(i-1) + (vx(i)*sin(psi(i)) + vy(i)*cos(psi(i)))*dt;
    z(i)   = z(i-1) + vx(i)*sin(theta(i))*dt;
end

road_len = max(x)*1.15 + 50;
road_hw  = 4.0;

%% ---- Pre-generate fixed random scene elements ----
rng(7);

% Trees: position, height, radius, color variation
nTrees = 60;
side_sign  = [ones(1,nTrees/2), -ones(1,nTrees/2)];
tree_px    = rand(1,nTrees)*road_len;
tree_py    = side_sign .* (road_hw + 3 + rand(1,nTrees)*14);
tree_h     = 5 + rand(1,nTrees)*7;
tree_tr    = 0.18 + rand(1,nTrees)*0.12;   % trunk radius
tree_cr    = 1.8  + rand(1,nTrees)*2.2;    % canopy radius
tree_layers= 2 + round(rand(1,nTrees)*2);  % canopy layers
tree_gc    = [0.10+rand(nTrees,1)*0.20, ...
              0.35+rand(nTrees,1)*0.25, ...
              0.05+rand(nTrees,1)*0.12];    % green RGB

% Rocks
nRocks = 20;
rock_px = rand(1,nRocks)*road_len;
rock_py = (sign(rand(1,nRocks)-0.5)) .* (road_hw+1.5 + rand(1,nRocks)*18);
rock_s  = 0.3 + rand(1,nRocks)*0.8;

% Road cracks/texture patches
nPatch = 40;
patch_px = rand(1,nPatch)*road_len;
patch_py = -road_hw + rand(1,nPatch)*road_hw*2;

%% ---- Wheel base geometry ----
WB = 2.7;   % wheelbase
TK = 1.55;  % track width
WR = 0.33;  % wheel radius
WW = 0.22;  % wheel width

%% ---- Figure ----
fig = figure('Position',[30 30 1600 860], ...
             'Color',[0.05 0.05 0.08], ...
             'Name','EV Ultra-Realistic Simulation', ...
             'NumberTitle','off');

%% ================================================================
% HELPER FUNCTIONS (defined at bottom as local functions)
%% ================================================================

%% ---- Animation loop ----
step = max(1, round(N/500));   % auto-subsample for speed

for i = 1:step:N

    clf('reset');
    set(fig,'Color',[0.05 0.05 0.08]);

    %% ============================================================
    %  PANEL 1 — 3D SCENE  (left 62%)
    %% ============================================================
    ax1 = axes('Position',[0.01 0.28 0.61 0.70]);
    hold(ax1,'on');

    %% --- Sky dome (gradient via stacked horizontal bands) ---
    sky_colors = [0.53 0.81 0.98;   % horizon
                  0.25 0.55 0.85;
                  0.10 0.35 0.72;
                  0.05 0.18 0.55];  % zenith
    nBands = size(sky_colors,1);
    sky_zmax = max(z)+28;
    sky_zmin = max(z)-1;
    for b = 1:nBands-1
        zb0 = sky_zmin + (b-1)*(sky_zmax-sky_zmin)/(nBands-1);
        zb1 = sky_zmin + b*(sky_zmax-sky_zmin)/(nBands-1);
        fc  = (sky_colors(b,:)+sky_colors(b+1,:))/2;
        fill3([-200 road_len+200 road_len+200 -200], ...
              [-80 -80 80 80], ...
              [zb0 zb0 zb1 zb1], fc, ...
              'EdgeColor','none','FaceAlpha',0.95);
    end

    %% --- Sun disc ---
    sun_az = pi/4;
    sun_el = 0.45;
    sun_d  = 60;
    sx = x(i) + sun_d*cos(sun_el)*cos(sun_az);
    sy =        sun_d*cos(sun_el)*sin(sun_az);
    sz = z(i) + sun_d*sin(sun_el);
    % Glow rings
    for gr = 4:-1:1
        sr = 1.5*gr;
        th_s = linspace(0,2*pi,20);
        fill3(sx+sr*cos(th_s), sy+sr*sin(th_s), sz*ones(1,20), ...
              [1.0 0.95 0.60], 'EdgeColor','none','FaceAlpha',0.08*gr);
    end
    % Core
    th_s = linspace(0,2*pi,20);
    fill3(sx+1.2*cos(th_s), sy+1.2*sin(th_s), sz*ones(1,20), ...
          [1.0 0.98 0.82],'EdgeColor','none');

    %% --- Distant mountains (silhouette) ---
    mtn_x = [x(i)-200, x(i)-120, x(i)-60, x(i)+20, x(i)+80, ...
              x(i)+160, x(i)+240, x(i)+300];
    mtn_h = [8, 14, 10, 16, 11, 13, 9, 7];
    mtn_y_far = 75;
    for m = 1:length(mtn_x)-1
        bz = z(i)-0.5;
        fill3([mtn_x(m) mtn_x(m+1) (mtn_x(m)+mtn_x(m+1))/2], ...
              [mtn_y_far mtn_y_far mtn_y_far], ...
              [bz bz bz+mtn_h(m)], [0.38 0.42 0.50], ...
              'EdgeColor','none','FaceAlpha',0.7);
    end

    %% --- Ground (grass with subtle variation) ---
    gx_v = [-50, road_len+50, road_len+50, -50];
    gy_v = [-70, -70, 70, 70];
    gz_v = (z(i)-0.15)*ones(1,4);
    fill3(gx_v, gy_v, gz_v, [0.18 0.42 0.14], 'EdgeColor','none');

    % Grass texture patches
    rng(99);
    for gp = 1:120
        gpx = x(i)-25 + rand*50;
        gpy = -65 + rand*130;
        if abs(gpy) > road_hw+0.5
            gc2 = [0.14+rand*0.12, 0.38+rand*0.18, 0.10+rand*0.10];
            fill3([gpx gpx+0.6 gpx+0.3], [gpy gpy gpy+0.6], ...
                  z(i)*ones(1,3), gc2,'EdgeColor','none','FaceAlpha',0.6);
        end
    end

    %% --- Road base with elevation profile ---
    % Paved surface
    n_seg = 40;
    seg_len = road_len / n_seg;
    for sg = 1:n_seg
        sx0 = (sg-1)*seg_len;   sx1 = sg*seg_len;
        % interpolate z along road
        iz0 = interp1(x, z, min(sx0,max(x)), 'linear','extrap');
        iz1 = interp1(x, z, min(sx1,max(x)), 'linear','extrap');
        fill3([sx0 sx1 sx1 sx0], ...
              [-road_hw -road_hw road_hw road_hw], ...
              [iz0 iz1 iz1 iz0]*0 + (iz0+iz1)/2, ...   % flat per seg
              [0.22 0.22 0.24], 'EdgeColor','none');
    end

    % Road shoulder (lighter asphalt edge)
    sh = 0.5;
    fill3([0 road_len road_len 0], ...
          [road_hw road_hw road_hw+sh road_hw+sh], ...
          zeros(1,4), [0.32 0.30 0.28],'EdgeColor','none');
    fill3([0 road_len road_len 0], ...
          [-road_hw -road_hw -road_hw-sh -road_hw-sh], ...
          zeros(1,4), [0.32 0.30 0.28],'EdgeColor','none');

    % White edge lines
    plot3([0 road_len], [ road_hw  road_hw], [0.02 0.02], ...
          'w-','LineWidth',2.2);
    plot3([0 road_len], [-road_hw -road_hw], [0.02 0.02], ...
          'w-','LineWidth',2.2);

    % Yellow centre dashes
    dash_l = 3.0; dash_g = 5.0;
    dxs = 0:dash_l+dash_g:road_len;
    for d = 1:length(dxs)
        plot3([dxs(d) dxs(d)+dash_l],[0 0],[0.03 0.03], ...
              '-','Color',[0.95 0.85 0.10],'LineWidth',1.8);
    end

    % Road texture cracks (static detail)
    for cp = 1:nPatch
        if abs(patch_px(cp)-x(i)) < 35
            plot3([patch_px(cp) patch_px(cp)+0.4+rand*0.8], ...
                  [patch_py(cp) patch_py(cp)+rand*0.3], ...
                  [0.015 0.015], '-','Color',[0.15 0.15 0.16], ...
                  'LineWidth',0.5);
        end
    end

    % Kilometre marker posts
    for km = 0:10:road_len
        if abs(km - x(i)) < 50
            fill3([km-0.05 km+0.05 km+0.05 km-0.05], ...
                  [road_hw+0.05 road_hw+0.05 road_hw+sh road_hw+sh], ...
                  [0 0 1.2 1.2], [0.9 0.9 0.9],'EdgeColor','none');
        end
    end

    %% --- Rocks ---
    for rk = 1:nRocks
        if abs(rock_px(rk)-x(i)) < 40
            rs = rock_s(rk);
            rc = [0.45+rand*0.15, 0.43+rand*0.12, 0.38+rand*0.10];
            drawRock(ax1, rock_px(rk), rock_py(rk), z(i), rs, rc);
        end
    end

    %% --- Trees (realistic multi-layer cones + round top) ---
    for tr = 1:nTrees
        if abs(tree_px(tr)-x(i)) < 55
            drawTree(ax1, tree_px(tr), tree_py(tr), z(i), ...
                     tree_h(tr), tree_tr(tr), tree_cr(tr), ...
                     tree_layers(tr), tree_gc(tr,:));
        end
    end

    %% --- Tyre tracks / path trail ---
    if i > 5
        ii = max(1,i-120):i;
        % Left tyre track
        lx = x(ii) - TK/2*sin(psi(ii));
        ly = y(ii) + TK/2*cos(psi(ii));
        plot3(lx, ly, z(ii)+0.008, '-','Color',[0.08 0.08 0.10],'LineWidth',1.5);
        % Right tyre track
        rx2 = x(ii) + TK/2*sin(psi(ii));
        ry2 = y(ii) - TK/2*cos(psi(ii));
        plot3(rx2, ry2, z(ii)+0.008, '-','Color',[0.08 0.08 0.10],'LineWidth',1.5);
    end

    %% --- Car body (realistic multi-part patch) ---
    temp_norm = min(max((T(i)-30)/25, 0), 1);
    % Body colour: metallic silver → warm orange tint with heat
    body_base = [0.72+temp_norm*0.28, ...
                 0.74-temp_norm*0.30, ...
                 0.78-temp_norm*0.45];
    drawCar(ax1, x(i), y(i), z(i), psi(i), body_base, WB, TK, WR, WW);

    %% --- Suspension / wheel dust ---
    spd = sqrt(vx(i)^2 + vy(i)^2);
    if spd > 1.5
        for p = 1:12
            ang = rand*2*pi;
            pr  = rand*0.6;
            px_ = x(i) + pr*cos(ang);
            py_ = y(i) + pr*sin(ang);
            pz_ = z(i) + rand*0.25;
            alpha_d = 0.15 + rand*0.35;
            sz_ = 2 + rand*5;
            plot3(px_, py_, pz_, '.', ...
                  'Color',[0.72 0.68 0.60 ], ...
                  'MarkerSize', sz_);
        end
    end

    %% --- Torque vectoring arrows on wheels ---
    dT = results.T_right(i) - results.T_left(i);
    arrow_scale = 0.010;
    % Front axle torque arrow
    fx = x(i) + WB/2*cos(psi(i));
    fy = y(i) + WB/2*sin(psi(i));
    quiver3(fx, fy, z(i)+WR, ...
            -sin(psi(i))*dT*arrow_scale, cos(psi(i))*dT*arrow_scale, 0, ...
            'Color',[1 0.3 0.1],'LineWidth',2.5,'MaxHeadSize',2,'AutoScale','off');
    % Rear axle
    bx2 = x(i) - WB/2*cos(psi(i));
    by2 = y(i) - WB/2*sin(psi(i));
    quiver3(bx2, by2, z(i)+WR, ...
            -sin(psi(i))*dT*arrow_scale*0.6, cos(psi(i))*dT*arrow_scale*0.6, 0, ...
            'Color',[0.3 0.6 1.0],'LineWidth',2.0,'MaxHeadSize',2,'AutoScale','off');

    %% --- Headlight beams (night feel) ---
    hl_x = x(i) + 2.3*cos(psi(i));
    hl_y = y(i) + 2.3*sin(psi(i));
    for hl = [-0.65 0.65]
        hlx2 = hl_x + 14*cos(psi(i));
        hly2 = hl_y + hl + 14*sin(psi(i));
        fill3([hl_x hl_x+0.5 hlx2+0.5 hlx2], ...
              [hl_y+hl hl_y+hl+0.1 hly2+1.2 hly2-0.2], ...
              [z(i)+0.55 z(i)+0.55 z(i)+0.1 z(i)+0.1], ...
              [1 0.98 0.82],'EdgeColor','none','FaceAlpha',0.07);
    end

    %% --- Chase camera ---
    lag   = max(1, i-30);
    cdist = 16;
    chgt  = 5.5;
    cfwd  = 6;
    cpx   = x(i) - cdist*cos(psi(lag));
    cpy   = y(i) - cdist*sin(psi(lag));
    set(ax1,'CameraPosition', [cpx, cpy, z(i)+chgt]);
    set(ax1,'CameraTarget',   [x(i)+cfwd*cos(psi(i)), ...
                               y(i)+cfwd*sin(psi(i)), z(i)+0.6]);
    set(ax1,'CameraUpVector', [0 0 1]);
    set(ax1,'CameraViewAngle', 52);

    %% Axis/lighting
    win = 32;
    xlim(ax1,[x(i)-win, x(i)+win]);
    ylim(ax1,[-18 18]);
    zlim(ax1,[min(z)-1, max(z)+26]);
    axis(ax1,'off');
    set(ax1,'Clipping','off');

    %% --- HUD box ---
    spd_kmh = vx(i)*3.6;
    bat_pct  = min(100, max(0, 100 - (T(i)-30)*3));
    hud = sprintf(['  SPD  %5.1f km/h\n' ...
                   '  BAT  %5.1f °C\n'  ...
                   '  ALT  %5.1f m\n'   ...
                   '  YAW  %5.2f °/s\n' ...
                   '  ΔTq  %+5.1f Nm'], ...
        spd_kmh, T(i), z(i), rad2deg(r(i)), ...
        results.T_right(i)-results.T_left(i));
    text(ax1, 0.012, 0.985, hud, ...
         'Units','normalized','VerticalAlignment','top', ...
         'FontName','Courier New','FontSize',9,'Color',[0.9 1.0 0.6], ...
         'BackgroundColor',[0 0 0 0.62],'Margin',5,'Interpreter','none');

    % Time stamp
    text(ax1, 0.5, 0.99, sprintf('t = %.2f s', t(i)), ...
         'Units','normalized','HorizontalAlignment','center', ...
         'VerticalAlignment','top','FontSize',11,'Color','w', ...
         'FontWeight','bold');

    %% ============================================================
    %  PANEL 2 — Battery Temperature
    %% ============================================================
    ax2 = axes('Position',[0.645 0.565 0.345 0.40]);
    fill([t(1:i), fliplr(t(1:i))], [T(1:i), 30*ones(1,i)], ...
         [0.85 0.25 0.15],'FaceAlpha',0.18,'EdgeColor','none');
    hold(ax2,'on');
    plot(t(1:i), T(1:i), '-','Color',[0.95 0.35 0.20],'LineWidth',2.2);
    plot(t(i),   T(i),   'o','Color',[1 0.9 0.2], ...
         'MarkerSize',7,'MarkerFaceColor',[1 0.9 0.2]);
    yline(50,'--','Color',[1 0.55 0.1],'LineWidth',1.5);
    text(t(end)*0.98, 50.8, 'Danger 50°C', ...
         'Color',[1 0.55 0.1],'FontSize',7.5,'HorizontalAlignment','right');
    yline(40,':','Color',[0.9 0.85 0.4],'LineWidth',1.2);
    ylabel('Temp (°C)','Color','w','FontSize',8);
    title('Battery Temperature','Color','w','FontSize',9,'FontWeight','normal');
    set(ax2,'Color',[0.08 0.08 0.11],'XColor','w','YColor','w', ...
            'GridColor',[1 1 1],'GridAlpha',0.08,'FontSize',8);
    xlim([t(1) t(end)]); ylim([20 65]); grid on; box off;

    %% ============================================================
    %  PANEL 3 — Torque Vectoring (NEW)
    %% ============================================================
    ax3 = axes('Position',[0.645 0.28 0.345 0.24]);
    fill([t(1:i), fliplr(t(1:i))], ...
         [results.T_right(1:i), zeros(1,i)], ...
         [0.20 0.55 1.0],'FaceAlpha',0.20,'EdgeColor','none');
    hold(ax3,'on');
    fill([t(1:i), fliplr(t(1:i))], ...
         [results.T_left(1:i), zeros(1,i)], ...
         [1.0 0.40 0.15],'FaceAlpha',0.20,'EdgeColor','none');
    plot(t(1:i), results.T_right(1:i), '-','Color',[0.30 0.65 1.0],'LineWidth',1.8);
    plot(t(1:i), results.T_left(1:i),  '-','Color',[1.0 0.50 0.20],'LineWidth',1.8);
    plot(t(1:i), results.T_right(1:i)-results.T_left(1:i), ...
         '--','Color',[0.55 1.0 0.45],'LineWidth',1.4);
    plot(t(i), results.T_right(i), 'o','Color',[0.30 0.65 1.0], ...
         'MarkerSize',5,'MarkerFaceColor',[0.30 0.65 1.0]);
    plot(t(i), results.T_left(i),  'o','Color',[1.0 0.50 0.20], ...
         'MarkerSize',5,'MarkerFaceColor',[1.0 0.50 0.20]);
    yline(0,'-','Color',[0.5 0.5 0.5],'LineWidth',0.8);
    legend('T_{right}','T_{left}','\DeltaT (R-L)', ...
           'Location','northwest','TextColor','w','FontSize',7.5, ...
           'Color',[0.08 0.08 0.11],'EdgeColor','none');
    ylabel('Torque (Nm)','Color','w','FontSize',8);
    title('Wheel Torque Vectoring','Color','w','FontSize',9,'FontWeight','normal');
    set(ax3,'Color',[0.08 0.08 0.11],'XColor','w','YColor','w', ...
            'GridColor',[1 1 1],'GridAlpha',0.08,'FontSize',8);
    xlim([t(1) t(end)]); grid on; box off;

    %% ============================================================
    %  PANEL 4 — Derating & Slope
    %% ============================================================
    ax4 = axes('Position',[0.645 0.03 0.345 0.215]);
    yyaxis(ax4,'left');
    plot(t(1:i), alpha(1:i), '-','Color',[0.35 0.75 1.0],'LineWidth',1.8);
    ylabel('\alpha Derating','Color',[0.35 0.75 1.0],'FontSize',8);
    set(ax4,'YColor',[0.35 0.75 1.0]);
    yyaxis(ax4,'right');
    plot(t(1:i), rad2deg(theta(1:i)), '--','Color',[0.90 0.72 0.30],'LineWidth',1.8);
    hold(ax4,'on');
    % Fill slope area
    fill([t(1:i), fliplr(t(1:i))], ...
         [rad2deg(theta(1:i)), zeros(1,i)], ...
         [0.90 0.72 0.30],'FaceAlpha',0.12,'EdgeColor','none');
    ylabel('Slope (°)','Color',[0.90 0.72 0.30],'FontSize',8);
    set(ax4,'YColor',[0.90 0.72 0.30]);
    xlabel('Time (s)','Color','w','FontSize',8);
    title('Derating & Road Slope','Color','w','FontSize',9,'FontWeight','normal');
    set(ax4,'Color',[0.08 0.08 0.11],'XColor','w', ...
            'GridColor',[1 1 1],'GridAlpha',0.08,'FontSize',8);
    xlim([t(1) t(end)]); grid on; box off;

    %% ============================================================
    %  PANEL 5 — Speed bar (bottom)
    %% ============================================================
    ax5 = axes('Position',[0.01 0.03 0.61 0.21]);
    spd_all = vx*3.6;
    % Gradient-style area: colour by speed
    fill([t(1:i), fliplr(t(1:i))], [spd_all(1:i), zeros(1,i)], ...
         [0.20 0.50 0.95],'FaceAlpha',0.45,'EdgeColor','none');
    hold(ax5,'on');
    plot(t(1:i), spd_all(1:i), '-','Color',[0.45 0.75 1.0],'LineWidth',2);
    plot(t(i), spd_all(i), 'o','Color','w','MarkerSize',7,'MarkerFaceColor','w');
    % Acceleration shading
    acc = [0 diff(vx)/dt];
    pos_acc = acc; pos_acc(acc<=0) = 0;
    neg_acc = acc; neg_acc(acc>=0) = 0;
    yyaxis(ax5,'right');
    area(t(1:i), pos_acc(1:i)*3.6,'FaceColor',[0.30 0.90 0.40],'FaceAlpha',0.25,'EdgeColor','none');
    hold(ax5,'on');
    area(t(1:i), neg_acc(1:i)*3.6,'FaceColor',[1.0 0.35 0.25],'FaceAlpha',0.25,'EdgeColor','none');
    ylabel('Accel (km/h/s)','Color','w','FontSize',7.5);
    set(ax5,'YColor','w');
    yyaxis(ax5,'left');
    ylabel('Speed (km/h)','Color','w','FontSize',8);
    set(ax5,'YColor','w');
    xlabel('Time (s)','Color','w','FontSize',8);
    title('Vehicle Speed  |  Green=accel  Red=brake','Color','w', ...
          'FontSize',9,'FontWeight','normal');
    set(ax5,'Color',[0.08 0.08 0.11],'XColor','w', ...
            'GridColor',[1 1 1],'GridAlpha',0.08,'FontSize',8);
    xlim([t(1) t(end)]); grid on; box off;

    drawnow limitrate;
end   % end animation loop


%% ================================================================
%% LOCAL HELPER FUNCTIONS
%% ================================================================

function drawCar(ax, cx, cy, cz, heading, body_col, WB, TK, WR, WW)
% Draws a detailed car: body, roof, windshield, windows, 4 wheels

    Rz = [cos(heading) -sin(heading); sin(heading) cos(heading)];

    function [Xw,Yw,Zw] = rot2(lx,ly,lz)
        p = Rz*[lx(:)'; ly(:)'];
        Xw = p(1,:)' + cx;
        Yw = p(2,:)' + cy;
        Zw = lz(:) + cz;
    end

    % ---- Main body (low, wide box) ----
    BL=4.6; BW=1.9; BH=0.9;
    [bx,by,bz] = boxPatch(BL,BW,BH,0,0,WR);
    for f=1:size(bx,2)
        [Xw,Yw,Zw] = rot2(bx(:,f), by(:,f), bz(:,f));
        patch(ax, Xw,Yw,Zw, body_col, 'EdgeColor','k','EdgeAlpha',0.25,'LineWidth',0.4);
    end

    % ---- Roof (smaller box, centred, higher) ----
    RL=2.4; RW=1.65; RH=0.65;
    [bx,by,bz] = boxPatch(RL,RW,RH,0,0,WR+BH);
    roof_col = body_col*0.72;
    for f=1:size(bx,2)
        [Xw,Yw,Zw] = rot2(bx(:,f), by(:,f), bz(:,f));
        patch(ax, Xw,Yw,Zw, roof_col,'EdgeColor','k','EdgeAlpha',0.25,'LineWidth',0.4);
    end

    % ---- Windshield (angled quad, front) ----
    ws_pts = [-BL/2+0.35  BL/2-RL/2-0.05;
               0           0         ];
    wsX = [ws_pts(1,1) ws_pts(1,2) ws_pts(1,2) ws_pts(1,1)];
    wsY = [-RW/2 -RW/2 RW/2 RW/2]*0.95;
    wsZ = [WR+BH WR+BH+RH WR+BH+RH WR+BH];
    [Xw,Yw,Zw] = rot2(wsX,wsY,wsZ);
    patch(ax, Xw,Yw,Zw,[0.55 0.78 0.88],'FaceAlpha',0.55, ...
          'EdgeColor','k','EdgeAlpha',0.3,'LineWidth',0.4);

    % Rear windshield
    rwX = [BL/2-RL/2+0.05 BL/2-0.3  BL/2-0.3  BL/2-RL/2+0.05];
    [Xw,Yw,Zw] = rot2(rwX, wsY, wsZ);
    patch(ax, Xw,Yw,Zw,[0.45 0.65 0.80],'FaceAlpha',0.55, ...
          'EdgeColor','k','EdgeAlpha',0.3,'LineWidth',0.4);

    % ---- 4 Wheels ----
    wheel_pos = [ WB/2,  TK/2;
                  WB/2, -TK/2;
                 -WB/2,  TK/2;
                 -WB/2, -TK/2];
    for w = 1:4
        wlx = wheel_pos(w,1);
        wly = wheel_pos(w,2);
        drawWheel(ax, cx, cy, cz, heading, wlx, wly, WR, WW);
    end

    % ---- Brake lights (red glow rear) ----
    for rl = [-0.6 0.6]
        th_l = linspace(0,2*pi,12);
        lx2 = -BL/2*ones(1,12);
        ly2 = rl + 0.12*sin(th_l);
        lz2 = (WR+0.4) + 0.12*cos(th_l);
        [Xw,Yw,Zw] = rot2(lx2,ly2,lz2);
        patch(ax, Xw,Yw,Zw,[0.95 0.1 0.1],'EdgeColor','none','FaceAlpha',0.9);
    end

    % ---- Headlights ----
    for hl = [-0.65 0.65]
        th_l = linspace(0,2*pi,12);
        lx2 = BL/2*ones(1,12);
        ly2 = hl + 0.13*sin(th_l);
        lz2 = (WR+0.4) + 0.13*cos(th_l);
        [Xw,Yw,Zw] = rot2(lx2,ly2,lz2);
        patch(ax, Xw,Yw,Zw,[1 0.97 0.82],'EdgeColor','none','FaceAlpha',0.95);
    end
end

function drawWheel(ax, cx, cy, cz, heading, lx, ly, WR, WW)
% Draws a single wheel cylinder + tread detail + hub
    nth = 16;
    th  = linspace(0,2*pi,nth+1);
    Rz  = [cos(heading) -sin(heading); sin(heading) cos(heading)];

    % Tyre profile (dark rubber)
    wx_edge = WW/2;
    for side = [-1 1]
        xe = lx*ones(1,nth+1);
        ye = ly + side*wx_edge*ones(1,nth+1);
        ze = cz + WR + WR*sin(th);
        p  = Rz*[xe; ye-cy];
        patch(ax, p(1,:)+cx, p(2,:)+cy, ze, ...
              [0.12 0.12 0.12],'EdgeColor','none');
    end
    % Tread band
    for seg=1:nth
        a1=th(seg); a2=th(seg+1);
        ye  = ly + [-wx_edge wx_edge wx_edge -wx_edge];
        xe  = lx*ones(1,4);
        ze  = cz+WR + [WR*sin(a1) WR*sin(a1) WR*sin(a2) WR*sin(a2)];
        col = [0.08 0.08 0.08];
        if mod(seg,3)==0, col=[0.2 0.2 0.2]; end
        p = Rz*[xe; ye];
        patch(ax, p(1,:)+cx, p(2,:)+cy, ze, col,'EdgeColor','none');
    end
    % Hub (silver)
    hub_r = WR*0.38;
    for side=[-1 1]
        xe = lx*ones(1,nth+1);
        ye = ly + side*(wx_edge+0.01)*ones(1,nth+1);
        ze = cz + WR + hub_r*sin(th);
        p  = Rz*[xe; ye-cy];
        patch(ax, p(1,:)+cx, p(2,:)+cy, ze, ...
              [0.72 0.72 0.78],'EdgeColor','none');
    end
end

function [bxF,byF,bzF] = boxPatch(L,W,H,ox,oy,oz)
% Returns 6 faces of a box as column arrays
    x0=-L/2+ox; x1=L/2+ox;
    y0=-W/2+oy; y1=W/2+oy;
    z0=oz;       z1=oz+H;
    faces = {[x0 x1 x1 x0],[y0 y0 y1 y1],[z0 z0 z0 z0]; % bottom
             [x0 x1 x1 x0],[y0 y0 y1 y1],[z1 z1 z1 z1]; % top
             [x0 x0 x1 x1],[y0 y1 y1 y0],[z0 z1 z1 z0]; % front-ish
             [x0 x0 x1 x1],[y0 y1 y1 y0],[z1 z0 z0 z1]; % back
             [x0 x0 x0 x0],[y0 y1 y1 y0],[z0 z0 z1 z1]; % left
             [x1 x1 x1 x1],[y0 y1 y1 y0],[z0 z0 z1 z1]};% right
    bxF = cell2mat(cellfun(@(c)c(:), faces(:,1),'uni',0))';
    byF = cell2mat(cellfun(@(c)c(:), faces(:,2),'uni',0))';
    bzF = cell2mat(cellfun(@(c)c(:), faces(:,3),'uni',0))';
    % Reshape to 4 x nFaces
    bxF = reshape(bxF,4,[]);
    byF = reshape(byF,4,[]);
    bzF = reshape(bzF,4,[]);
end

function drawTree(ax, tx, ty, tz, th, tr_r, cr, nlayers, gc)
% Realistic pine tree: bark trunk + layered conical canopy
    nth = 10;
    ang = linspace(0,2*pi,nth+1);

    % Trunk (cylinder approximation: two end-caps + side quads)
    trunk_h = th*0.32;
    bark_col = [0.32+rand*0.08, 0.20+rand*0.05, 0.10+rand*0.05];
    for seg=1:nth
        a1=ang(seg); a2=ang(seg+1);
        xq = tx + tr_r*[cos(a1) cos(a2) cos(a2) cos(a1)];
        yq = ty + tr_r*[sin(a1) sin(a2) sin(a2) sin(a1)];
        zq = tz + [0 0 trunk_h trunk_h];
        patch(ax, xq,yq,zq, bark_col,'EdgeColor','none','FaceAlpha',0.95);
    end

    % Canopy layers (stacked cones, bottom-largest)
    for lyr=1:nlayers
        frac  = (nlayers-lyr+1)/nlayers;
        l_cr  = cr * frac * 1.05;
        l_bot = tz + trunk_h + (lyr-1)*(th-trunk_h)/nlayers*0.72;
        l_tip = l_bot + (th-trunk_h)/nlayers*1.1;
        dark  = 0.75 + 0.25*(lyr/nlayers);
        col   = gc * dark;
        col   = min(col,1);
        for seg=1:nth
            a1=ang(seg); a2=ang(seg+1);
            xc = [tx+l_cr*cos(a1), tx+l_cr*cos(a2), tx];
            yc = [ty+l_cr*sin(a1), ty+l_cr*sin(a2), ty];
            zc = [l_bot, l_bot, l_tip];
            patch(ax, xc,yc,zc, col,'EdgeColor','none','FaceAlpha',0.95);
        end
        % Bottom disc of canopy
        xd = tx + l_cr*cos(ang(1:nth));
        yd = ty + l_cr*sin(ang(1:nth));
        zd = l_bot*ones(1,nth);
        patch(ax, xd,yd,zd, col*0.65,'EdgeColor','none','FaceAlpha',0.9);
    end
end

function drawRock(ax, rx, ry, rz, rs, rc)
% Random-faceted rock using irregular polygon
    nth = 7 + round(rand*5);
    ang = sort(rand(1,nth)*2*pi);
    radii = rs*(0.55 + rand(1,nth)*0.55);
    xr = rx + radii.*cos(ang);
    yr = ry + radii.*sin(ang);
    zr = rz*ones(1,nth);
    patch(ax, xr,yr,zr, rc*0.65,'EdgeColor','none');
    % Top face (brighter)
    xr2 = rx + radii*0.65.*cos(ang);
    yr2 = ry + radii*0.65.*sin(ang);
    zr2 = rz + rs*0.35*ones(1,nth);
    patch(ax, xr2,yr2,zr2, rc,'EdgeColor','none');
end