function experiment = plotAverageTrace(experiment, varargin)
% PLOTAVERAGETRACE plots the avearge trace
%
% USAGE:
%    experiment = plotAverageTrace(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see plotBaseOptioions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = plotAverageTrace(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% EXPERIMENT PIPELINE
% name: plot average trace
% parentGroups: fluorescence: basic: plots
% optionsClass: plotAverageTraceOptions
% requiredFields: avgT, avgTrace, folder, name

% Pass class options
optionsClass = plotAverageTraceOptions;
params = optionsClass().get;
if(length(varargin) >= 1 && isa(varargin{1}, class(optionsClass)))
  params = varargin{1}.get;
  if(length(varargin) > 1)
    varargin = varargin(2:end);
  else
    varargin = [];
  end
end 
% Define additional optional argument pairs
params.pbar = [];
params = parse_pv_pairs(params, varargin);

% Fix in case for some reason the group is a cell
if(iscell(params.group))
  mainGroup = params.group{1};
else
  mainGroup = params.group;
end

% Get ALL subgroups in case of parents
if(strcmpi(mainGroup, 'all'))
  groupList = getExperimentGroupsNames(experiment);
else
  groupList = getExperimentGroupsNames(experiment, mainGroup);
end

% Empty check
if(isempty(groupList))
  logMsg(sprintf('Group %s not found on experiment %s', mainGroup, experiment.name), 'w');
  return;
end

% Create the exports folder
switch params.exportFolder
  case 'experiment'
    mainFolder = experiment.folder;
  case 'project'
    mainFolder = [experiment.folder '..' filesep];
end
if(~exist(mainFolder, 'dir'))
  mkdir(mainFolder);
end
dataFolder = [mainFolder 'exports' filesep];
if(~exist(dataFolder, 'dir'))
  mkdir(dataFolder);
end


trace = experiment.avgTrace;

type = 'average';
if(params.showFigure)
  visible = 'on';
else
  visible = 'off';
end
hFig = figure('Name', [experiment.name type 'fluorescence trace'], 'NumberTitle', 'off', 'Visible', visible);
plot(experiment.avgT, trace);
xlabel('time (s)');
ylabel('avg fluorescence (a.u.)');
x_range = max(experiment.avgT)-min(experiment.avgT);
y_range = max(trace)-min(trace);
xlim([min(experiment.avgT)-x_range*0.01 max(experiment.avgT)+x_range*0.01]);
ylim([min(trace)-y_range*0.01 max(trace)+y_range*0.01]);
box on;
title([experiment.name type ' fluorescence trace']);
set(gcf,'Color','w');
pos = get(hFig, 'Position');
pos(4) = pos(3)/((1+sqrt(5))/2);
set(hFig, 'Position', pos);

ui = uimenu(hFig, 'Label', 'Export');
uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf';'*.eps'; '*.tiff'; '*.png'}, [experiment.folder experiment.name '_' type 'Trace']});

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
  export_fig([figFolder, experiment.name, '_averageTrace', params.saveFigureTag, '.', params.saveFigureType], ...
             sprintf('-r%d', params.saveFigureResolution), ...
             sprintf('-q%d', params.saveFigureQuality));
end

if(~params.showFigure)
  close(hFig);
end
