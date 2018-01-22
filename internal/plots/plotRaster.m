function experiment = plotRaster(experiment, varargin)
% PLOTRASTER plots the spike raster plot
%
% USAGE:
%    experiment = plotRaster(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    none
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = plotRaster(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% EXPERIMENT PIPELINE
% name: plot raster
% parentGroups: spikes: plots
% optionsClass: plotRasterOptions
% requiredFields: spikes, folder, name


% Pass class options
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(plotRasterOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Plotting raster');
%--------------------------------------------------------------------------
% Fix in case for some reason the group is a cell
if(iscell(params.group))
  mainGroup = params.group{1};
else
  mainGroup = params.group;
end
members = getAllMembers(experiment, mainGroup);

if(params.saveFigure)
  switch params.saveBaseFolder
    case 'experiment'
      baseFolder = experiment.folder;
    case 'project'
      baseFolder = [experiment.folder '..' filesep];
  end
  if(~exist(baseFolder, 'dir'))
    mkdir(baseFolder);
  end
    figFolder = [baseFolder 'figures' filesep];
  if(~exist(figFolder, 'dir'))
    mkdir(figFolder);
  end
end
baseFigName = experiment.name;
  
if(params.showFigure)
  visible = 'on';
else
  visible = 'off';
end
hFig = figure('Name', 'raster plot', 'NumberTitle', 'off', 'Visible', visible);

% Here the plot
Nspikes = 0;
LineFormat = [];
LineFormat.Color = params.lineColor;
LineFormat.LineWidth = params.lineWidth;
LineFormat.LineStyle = params.lineStyle;

currentOrder = members;
for it = 1:length(currentOrder)
    Nspikes = Nspikes+sum(~isnan(experiment.spikes{currentOrder(it)}(:)));
end
experiment.spikes = cellfun(@(x)x(:)', experiment.spikes, 'UniformOutput', false);
if(Nspikes > 0)
  if(params.plotAverageActivity)
    if(isempty(params.averageActivityBinning))
      params.averageActivityBinning = 1/experiment.fps;
    end
    subplot(2, 1, 1);
    dt = params.averageActivityBinning;
    binnedSpikes = [experiment.spikes{currentOrder}];
    binnedSpikes = floor(binnedSpikes/dt);
    [a,b] = hist(binnedSpikes, 0:max(experiment.t/dt));
    switch params.averageActivityNormalization
      case 'none'
        bar(b*dt, a);
        ylabel('Num spikes');
      case 'ROI'
        bar(b*dt, a/length(members));
        ylabel('Num spikes per cell');
      case 'bin'
        bar(b*dt, a/params.averageActivityBinning);
        ylabel('Total firing rate (Hz)');
      case 'binAndROI'
        bar(b*dt, a/length(members)/params.averageActivityBinning);
        ylabel('Firing rate per cell (Hz)');
    end
    fprintf('%d\n', sum(a)/length(members))
    xlim([min(experiment.t) max(experiment.t)]);
    if(~isempty(params.averageActivityScale))
      ylim(params.averageActivityScale);
    end
    %ylim([0 0.3]);
    subplot(2, 1, 2);
  end
  [~,~] = plotSpikeRaster(experiment.spikes(currentOrder), 'PlotType', 'vertLine', 'LineFormat', LineFormat);
end
hFig.Visible = visible;

xlabel('time (s)');
ylabel('ordered ROI subset');
ylim([0.5 length(currentOrder)+0.5]);
xlim([min(experiment.t) max(experiment.t)]);
title([experiment.name ' Raster plot']);
box on;
hold on;

set(gcf,'Color','w');
pos = get(hFig, 'Position');
pos(4) = pos(3)/((1+sqrt(5))/2);
set(hFig, 'Position', pos);

ui = uimenu(hFig, 'Label', 'Export');
     uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf';'*.eps'; '*.tiff'; '*.png'}, [experiment.folder experiment.name '_raster']});

if(params.saveFigure)
  [figFolder, baseFigName, '_raster', params.saveFigureTag, '.', params.saveFigureType]
  export_fig([figFolder, baseFigName, '_raster', params.saveFigureTag, '.', params.saveFigureType], ...
              sprintf('-r%d', params.saveFigureResolution), ...
              sprintf('-q%d', params.saveFigureQuality), hFig);
end

if(~params.showFigure)
  close(hFig);
end


%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

