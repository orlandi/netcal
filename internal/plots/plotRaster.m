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
% Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>

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


% Get ALL subgroups in case of parents
if(strcmpi(params.group, 'all') || strcmpi(params.group, 'ask'))
  groupList = getExperimentGroupsNames(experiment);
else
  groupList = getExperimentGroupsNames(experiment, params.group);
end
% If ask, open the popup
if(strcmpi(params.group, 'ask'))
  [selection, ok] = listdlg('PromptString', 'Select groups to use', 'ListString', groupList, 'SelectionMode', 'multiple');
  if(~ok)
    success = false;
    return;
  end
  groupList = groupList(selection);
end
fullMembers = [];
for git = 1:length(groupList)
  % Again, for compatibility reasons
  if(strcmpi(groupList{git}, 'none'))
    groupList{git} = 'everything';
  end
  members = getExperimentGroupMembers(experiment, groupList{git});
  fullMembers = [fullMembers; members(:)];
  
  if(isempty(members))
    logMsg(sprintf('Group %s is empty', groupList{git}), 'w');
    continue;
  end
  if(length(groupList) > 1)
    cmap = eval(sprintf('%s (%d)', params.styleOptions.colormap, length(groupList)));
    %cmap = lines(length(groupList));
  else
    cmap = params.lineColor;
  end
end

% Consistency checks
if(params.saveOptions.onlySaveFigure)
  params.saveOptions.saveFigure = true;
end
if(ischar(params.styleOptions.figureSize))
  params.styleOptions.figureSize = eval(params.styleOptions.figureSize);
elseif(numel(params.styleOptions.figureSize) == 1)
  params.styleOptions.figureSize = [1 1]*params.styleOptions.figureSize;
end

% Create necessary folders
if(params.saveOptions.saveFigure)
  switch params.saveOptions.saveBaseFolder
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

if(params.saveOptions.onlySaveFigure)  
  visible = 'off';
else
  visible = 'on';
end

hFig = figure('Name', [experiment.name ' Raster plot'], 'NumberTitle', 'off', 'Visible', visible, 'Tag', 'netcalPlot');
hFig.Position = setFigurePosition(gcbf, 'width', params.styleOptions.figureSize(1), 'height', params.styleOptions.figureSize(2));
hold on;
% Here the plot
Nspikes = 0;
LineFormat = [];
LineFormat.Color = params.lineColor;
LineFormat.LineWidth = params.lineWidth;
LineFormat.LineStyle = params.lineStyle;

currentOrder = fullMembers;
for it = 1:length(currentOrder)
    Nspikes = Nspikes+sum(~isnan(experiment.spikes{currentOrder(it)}(:)));
end
experiment.spikes = cellfun(@(x)x(:)', experiment.spikes, 'UniformOutput', false);
maxY = length(fullMembers);
if(Nspikes > 0)
  if(params.plotAverageActivity)
    if(isempty(params.averageActivityBinning))
      params.averageActivityBinning = 1/experiment.fps;
    end
    subplot(4, 1, 1);
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
    %fprintf('%d\n', sum(a)/length(members))
    xlim([min(experiment.t) max(experiment.t)]);
    if(~isempty(params.averageActivityScale))
      ylim(params.averageActivityScale);
    end
    title([experiment.name ' Firing rate'], 'interpreter', 'none');
    %ylim([0 0.3]);
    subplot(4, 1, 2:4);
    hold on;
  end
  % Now the multiple raster
  curOffset = 0;
  for git = 1:length(groupList)
    % Again, for compatibility reasons
    if(strcmpi(groupList{git}, 'none'))
      groupList{git} = 'everything';
    end
    % Skip the group with all members
    if(strfind(groupList{git}, 'all members'))
      continue;
    end
    % Skip the group with all members
    if(strfind(groupList{git}, 'all members'))
      continue;
    end
    if(strfind(groupList{git}, 'not on largest HCG'))
      continue;
    end
    members = getExperimentGroupMembers(experiment, groupList{git});
    if(~isempty(members))
      subSpikes = experiment.spikes(members);
      LineFormat.Color = cmap(git, :);
      [~, ~, h] = plotSpikeRaster(subSpikes, 'TrialOffset', curOffset, 'PlotType', 'vertLine', 'LineFormat', LineFormat);
      h.DisplayName = groupList{git};
      curOffset = curOffset + length(members);
    end
  end
  maxY = curOffset;
  if(length(groupList) > 1)
    legend;
  end
  %[~,~] = plotSpikeRaster(experiment.spikes(currentOrder), 'PlotType', 'vertLine', 'LineFormat', LineFormat);
end
hFig.Visible = visible;

xlabel('time (s)');
ylabel('ordered ROI index');
ylim([0.5, (maxY + 0.5)]);
xlim([min(experiment.t) max(experiment.t)]);
box on;
title([experiment.name ' Raster plot'], 'interpreter', 'none');
set(gcf,'Color','w');
%pos = get(hFig, 'Position');
%pos(4) = pos(3)/((1+sqrt(5))/2);
%set(hFig, 'Position', pos);

ui = uimenu(hFig, 'Label', 'Export');
     uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf';'*.eps'; '*.tiff'; '*.png'}, [experiment.folder experiment.name '_raster']});

if(params.saveOptions.saveFigure)
  %[figFolder, baseFigName, '_raster', params.saveFigureTag, '.', params.saveFigureType]
  export_fig([figFolder, baseFigName, '_raster', params.saveOptions.saveFigureTag, '.', params.saveOptions.saveFigureType], ...
              sprintf('-r%d', params.saveOptions.saveFigureResolution), ...
              sprintf('-q%d', params.saveOptions.saveFigureQuality), hFig);
end

% Execute additional figure commands
if(~isempty(params.additionalFigureOptions) && ischar(params.additionalFigureOptions))
  params.additionalFigureOptions = java.io.File(params.additionalFigureOptions);
end
if(~isempty(params.additionalFigureOptions) && params.additionalFigureOptions.isFile)
  run(char(params.additionalFigureOptions.getAbsoluteFile));
end

if(params.saveOptions.onlySaveFigure)
  close(hFig);
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

