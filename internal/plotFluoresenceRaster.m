function h = plotFluoresenceRaster(experiment, traces, t, varargin)
% IDENTIFYSIMILARITIESINTRACES identify similarities based on correlation
%
% USAGE:
%    TODO
%
% INPUT arguments:
%
%    experiment - structure obtained from loadExperiment()
%
%    traces - obtained from extractTraces() or somewhere else
%
%    t - time associated to each frame
%
% INPUT optional arguments ('key' followed by its value):
%
%    'verbose' - true/false. If true, outputs verbose information. Default:
%    true
%
%    'tag'
%
%   'showPlot'
%
%   'savePlot'
%
%   'cmap'
%
% OUTPUT arguments:
%
%    h - figure handle
%
% EXAMPLE:
%    h = plotFluoresenceRaster(experiment, traces)
%
% Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>

params.verbose = true;
params.tag = '_raster_all';
params.savePlot = true;
params.showPlot = true;
params.normalization = true;
params.cmap = morgenstemning(256);
params = parse_pv_pairs(params, varargin);

if(params.verbose)
    logMsgHeader('Generating raster-like plot', 'start');
end

% Normalization
normTraces = traces;
if(params.normalization)
    for j = 1:size(normTraces,2)
        normTraces(:, j) = (normTraces(:, j)-min(normTraces(:, j)))/(max(normTraces(:, j))-min(normTraces(:, j)));
    end
else
    %normTraces = normTraces-min(normTraces(:))+1;
    %normTraces = log10(normTraces);
end

h = figure;
pos = get(h, 'Position');
pos(4) = pos(3)/((1+sqrt(5))/2);
set(h, 'Position', pos);

if(~params.showPlot)
    set(h, 'Visible' ,'off');
end

cmap = params.cmap;
%normTraces
%pcolor(t, 1:size(normTraces,2), normTraces');shading flat;
imagesc([t(1) t(end)], [1, size(normTraces,2)], normTraces');shading flat;
colormap(cmap);
colorbar('location','EastOutside');

axis ij;
box on;
xlabel('time (s)');
ylabel('ordered ROI count');
if(params.normalization)
    title('Raster-like F intensity (normalized)');
else
    title('Raster-like F intensity (non-normalized)');
end


% Export
if(params.savePlot)
    fpa = [experiment.folder filesep 'figures'];
    if(~exist(fpa, 'dir'))
        mkdir(fpa);
    end
    outputfilename = [experiment.folder filesep 'figures' filesep experiment.name params.tag '.png'];
    set(gcf, 'Color', 'w');
    set(gca, 'Color', 'w');
    export_fig(outputfilename, '-nocrop', '-r300');
end

if(~params.showPlot)
    close(hfig);
end

if(params.verbose)
    logMsgHeader('Done!', 'finish');
end
