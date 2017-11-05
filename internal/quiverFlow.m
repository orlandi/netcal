function h = quiverFlow(ax, u, v, gap, scaling, colors, varargin)
% QUIVERFLOW plots the u,v field as a quiver plot on the current axes
%
% USAGE:
%    h = quiverFlow(u, v, norm, gap, scaling)
%
% INPUT arguments:
%    ax - figure axes
%
%    u - X component of the field
%
%    v - Y component of the field
%
%    gap - will only plot one arrow every 'gap' units
%
%    scaling - scaling parameter
%
% OUTPUT arguments:
%    h - quiver plot handle
%
% EXAMPLE:
%    h = quiverFlow(u, v, 5, 3)
%
% Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also gliaAverageMovie, gliaOpticFlow, quiver

params.cmap = 'parula';
params.LineWidth = '0.5';
params.LineStyle = '-';
params.minMod = 0;
params = parse_pv_pairs(params, varargin);


% Get the x,y coordinates for the quiver plot
[x,y] = meshgrid(1:gap:size(u, 2), 1:gap:size(u,1));
h = [];
mag = sqrt(u.^2+v.^2);
cmap = eval([params.cmap '(' num2str(colors) ')']);
magList = linspace(params.minMod, 1, size(cmap,1)+1);
magList(end) = inf;
for i = 1:size(cmap, 1)
    currColor = cmap(i, :);
    
    valid = (mag > magList(i) & mag <= magList(i+1));
    newU = u;
    newV = v;
    newU(~valid) = NaN;
    newV(~valid) = NaN;
    h = [h; quiver(ax, x, y, newU(1:gap:end, 1:gap:end)*scaling, newV(1:gap:end, 1:gap:end)*scaling, 0, 'Color', currColor, 'LineWidth', params.LineWidth, 'LineStyle', params.LineStyle)];
end


