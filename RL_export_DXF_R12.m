% RLpolygon_to_DXF_onefile.m
% Creates a robust, HFSS-friendly DXF from RLpolygon tables with extra debug entities.
% Output: RotmanLens_outline_debug.dxf
% Place this script beside:
%   RL_XY_coordinates_in_mm.tab   (columns: X Y [optional Z], usually mm)
%   RL_parameters.tab             (optional; row3=N, row4=Nb for mirroring rule)

clear; clc;

outfile = 'RotmanLens_outline_debug.dxf';

% ---------- Load RLpolygon XY ----------
if exist('RL_XY_coordinates_in_mm.tab','file')~=2
    error('Missing RL_XY_coordinates_in_mm.tab in current folder.');
end
XY = dlmread('RL_XY_coordinates_in_mm.tab');
if size(XY,2) < 2, error('XY table needs at least 2 columns (X Y).'); end
X = XY(:,1); Y = XY(:,2);
X = X(:); Y = Y(:);

% ---------- Optional: N & Nb for mirroring ----------
N = []; Nb = [];
if exist('RL_parameters.tab','file')==2
    P = dlmread('RL_parameters.tab'); P = P(:);
    if numel(P) >= 4
        N  = round(P(3));
        Nb = round(P(4));
    end
end

% ---------- Build full closed boundary ----------
if ~isempty(N) && numel(X)==N
    drop_middle = (mod(Nb,2)==0);        % even Nb => drop middle on mirror
    idx_lower = (N - drop_middle):-1:1;  % [N-1..1] if even, [N..1] if odd
    Xf = [X;  X(idx_lower)];
    Yf = [Y; -Y(idx_lower)];
else
    Xf = X;  Yf = Y;                      % assume already full loop
end

% Remove duplicate last point if already closed
if numel(Xf)>1 && Xf(1)==Xf(end) && Yf(1)==Yf(end)
    Xf(end)=[]; Yf(end)=[];
end

% Remove consecutive duplicates
tol = 1e-12;
dX = [Inf; abs(diff(Xf))]; dY = [Inf; abs(diff(Yf))];
keep = ~(dX<tol & dY<tol);
Xf = Xf(keep); Yf = Yf(keep);

if numel(Xf) < 3
    error('Not enough unique points to form a polygon after cleanup.');
end

% ---------- Auto-scale to mm if values look like meters ----------
maxabs = max(abs([Xf;Yf]));
scaled = false;
if maxabs < 1.0
    Xf = 1000*Xf; Yf = 1000*Yf; scaled = true; % m -> mm
end

% ---------- Report stats ----------
xmin=min(Xf); xmax=max(Xf); ymin=min(Yf); ymax=max(Yf);
fprintf('Vertices: %d   Bounding box (mm): [%.6g..%.6g] x [%.6g..%.6g]\n', numel(Xf), xmin, xmax, ymin, ymax);
if scaled, fprintf('Auto-scaled from meters to millimeters.\n'); end

% ---------- Quick visual preview ----------
figure(10); clf; plot(Xf, Yf, '-o'); axis equal; grid on;
title('Preview of RL outline to export (mm)'); drawnow;

% ---------- Write DXF (HEADER + TABLES) ----------
fid = fopen(outfile,'w'); if fid<0, error('Cannot open %s for writing.', outfile); end

% HEADER (declare mm & metric)
fprintf(fid,'  0\nSECTION\n  2\nHEADER\n');
fprintf(fid,'  9\n$INSUNITS\n 70\n4\n');   % 4 = mm
fprintf(fid,'  9\n$MEASUREMENT\n 70\n1\n'); % 1 = metric
fprintf(fid,'  0\nENDSEC\n');

% TABLES: Layers
fprintf(fid,'  0\nSECTION\n  2\nTABLES\n');
% Layer OUTLINE (LWPOLYLINE)
fprintf(fid,'  0\nTABLE\n  2\nLAYER\n 70\n3\n'); % declare 3 layers total
fprintf(fid,'  0\nLAYER\n  2\nOUTLINE\n 70\n0\n 62\n7\n  6\nCONTINUOUS\n');
% Layer OUTLINE_R12 (POLYLINE)
fprintf(fid,'  0\nLAYER\n  2\nOUTLINE_R12\n 70\n0\n 62\n3\n  6\nCONTINUOUS\n');
% Layer TEST (debug helpers)
fprintf(fid,'  0\nLAYER\n  2\nTEST\n 70\n0\n 62\n1\n  6\nCONTINUOUS\n');
fprintf(fid,'  0\nENDTAB\n');
fprintf(fid,'  0\nENDSEC\n');

% ---------- ENTITIES ----------
fprintf(fid,'  0\nSECTION\n  2\nENTITIES\n');

% (A) Debug: small crosshair at origin (two lines) on TEST
L = 5; % mm half-length
% X-axis line
fprintf(fid,'  0\nLINE\n  8\nTEST\n 10\n%.6f\n 20\n%.6f\n 30\n0\n 11\n%.6f\n 21\n%.6f\n 31\n0\n', -L, 0.0, L, 0.0);
% Y-axis line
fprintf(fid,'  0\nLINE\n  8\nTEST\n 10\n%.6f\n 20\n%.6f\n 30\n0\n 11\n%.6f\n 21\n%.6f\n 31\n0\n', 0.0, -L, 0.0, L);
% Debug: small rectangle near origin (10x5 mm) on TEST
rx=0; ry=0; w=10; h=5;
fprintf(fid,'  0\nLWPOLYLINE\n100\nAcDbEntity\n  8\nTEST\n100\nAcDbPolyline\n 90\n4\n 70\n1\n');
fprintf(fid,' 10\n%.6f\n 20\n%.6f\n', rx,     ry);
fprintf(fid,' 10\n%.6f\n 20\n%.6f\n', rx+w,   ry);
fprintf(fid,' 10\n%.6f\n 20\n%.6f\n', rx+w,   ry+h);
fprintf(fid,' 10\n%.6f\n 20\n%.6f\n', rx,     ry+h);

% (B) Your outline as LWPOLYLINE (closed) on OUTLINE
fprintf(fid,'  0\nLWPOLYLINE\n100\nAcDbEntity\n  8\nOUTLINE\n100\nAcDbPolyline\n');
fprintf(fid,' 90\n%d\n', numel(Xf));
fprintf(fid,' 70\n1\n'); % closed
for i=1:numel(Xf)
    fprintf(fid,' 10\n%.12g\n 20\n%.12g\n', Xf(i), Yf(i));
end

% (C) Your outline again as classic POLYLINE/ VERTEX/ SEQEND (closed) on OUTLINE_R12
fprintf(fid,'  0\nPOLYLINE\n  8\nOUTLINE_R12\n 66\n1\n 70\n1\n'); % 66=vertices follow, 70 closed
for i=1:numel(Xf)
    fprintf(fid,'  0\nVERTEX\n  8\nOUTLINE_R12\n 10\n%.12g\n 20\n%.12g\n 30\n0.0\n', Xf(i), Yf(i));
end
% Repeat first vertex to reinforce closure intent
fprintf(fid,'  0\nVERTEX\n  8\nOUTLINE_R12\n 10\n%.12g\n 20\n%.12g\n 30\n0.0\n', Xf(1), Yf(1));
fprintf(fid,'  0\nSEQEND\n');

% End ENTITIES/FILE
fprintf(fid,'  0\nENDSEC\n  0\nEOF\n');
fclose(fid);

fprintf('\n[OK] Wrote %s\n', outfile);
fprintf('HFSS import tip: Units=mm, check "Create 2D sheet from closed polylines".\n');
fprintf('If you only see the small TEST rectangle/crosshair, your outline may be far away or not interpreted as a closed sheet.\n');
