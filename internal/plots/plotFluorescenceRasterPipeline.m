function experiment = plotFluoresenceRasterPipeline(experiment, varargin)
% PLOTFLUORESENCERASTERPIPELINE plots the fluorescence raster plot
%
% USAGE:
%    experiment = plotFluoresenceRasterPipeline(experiment, varargin)
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
%    experiment = plotFluoresenceRasterPipeline(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% EXPERIMENT PIPELINE
% name: plot fluorescence raster
% parentGroups: fluorescence: basic: plots
% optionsClass: plotFluorescenceRasterOptions
% requiredFields: traces


% Pass class options
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(plotFluorescenceRasterOptions, varargin{:});

% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Plotting fluorescence raster');
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
end
cmap = eval(sprintf('%s (256)', params.styleOptions.colormap));

switch params.tracesType
  case 'raw'
    experiment = loadTraces(experiment, 'raw', 'pbar', params.pbar);
    traces = experiment.rawTraces;
    t = experiment.rawT;
  case 'smoothed'
    experiment = loadTraces(experiment, 'smoothed', 'pbar', params.pbar);
    traces = experiment.traces;
    t = experiment.t;
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

% Normalization
normTraces = traces(:, fullMembers);
switch params.normalization
  case 'none'
  case 'global'
    normTraces = (normTraces-min(normTraces(:)))/(max(normTraces(:))-min(normTraces(:)));
  case 'per trace'
    for j = 1:size(normTraces,2)
      normTraces(:, j) = (normTraces(:, j)-min(normTraces(:, j)))/(max(normTraces(:, j))-min(normTraces(:, j)));
    end
end
%normTraces = normTraces-min(normTraces(:))+1;
%normTraces = log10(normTraces);


%pos = hFig.Position;
%pos(4) = pos(3)/((1+sqrt(5))/2);
%hFig.Position = pos;


cmap = eval(sprintf('%s (256)', params.styleOptions.colormap));
%normTraces
%pcolor(t, 1:size(normTraces,2), normTraces');shading flat;

if(params.plotAverageActivity)
  ax1 = subplot(4, 1, 1);
  avgTrace = mean(traces, 2);
  plot(t, avgTrace);
  ylabel('Avg F');
  %fprintf('%d\n', sum(a)/length(members))
  xlim([min(t) max(t)]);
  title([experiment.name ' Average fluorescence'], 'interpreter', 'none');
  set(ax1, 'XTickLabel', []);
  subplot(4, 1, 2:4);
  hold on;
end

imagesc([t(1) t(end)], [1, size(normTraces,2)], normTraces');shading flat;
ax2 = gca;
xlim([t(1) t(end)]);
ylim([1 size(normTraces, 2)]);
colormap(cmap);
colorbar('location','EastOutside');

axis ij;
box on;
xlabel('time (s)');
ylabel('ordered ROI index');
if(params.normalization)
  title(sprintf('%s - %s: Raster-like F intensity (normalized)', experiment.name, params.group), 'interpreter', 'none');
else
  title(sprintf('%s - %s: Raster-like F intensity (non-normalized)', experiment.name, params.group), 'interpreter', 'none');
end
set(hFig,'Color','w');
if(params.plotAverageActivity)
  ax1.Position(1) = ax2.Position(1);
  ax1.Position(3) = ax2.Position(3);
end

ui = uimenu(hFig, 'Label', 'Export');
     uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf';'*.eps'; '*.tiff'; '*.png'}, [experiment.folder experiment.name '_raster']});

if(params.saveOptions.saveFigure)
  %[figFolder, baseFigName, '_raster', params.saveFigureTag, '.', params.saveFigureType]
  export_fig([figFolder, 'fluorescenceraster_', baseFigName, params.saveOptions.saveFigureTag, '.', params.saveOptions.saveFigureType], ...
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


