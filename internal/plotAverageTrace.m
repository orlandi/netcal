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
%    none
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = plotAverageTrace(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% EXPERIMENT PIPELINE
% name: plot average trace
% parentGroups: fluorescence: basic: plots
% optionsClass: plotBaseOptions
% requiredFields: avgT, avgTrace, folder, name

% Pass class options
optionsClass = plotBaseOptions;
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

trace = experiment.avgTrace;

type = 'average';
if(params.showFigure)
  visible = 'on';
else
  visible = 'off';
end
hFig = figure('Name', [type 'fluorescence trace'], 'NumberTitle', 'off', 'Visible', visible);
plot(experiment.avgT, trace);
xlabel('time (s)');
ylabel('avg fluorescence (a.u.)');
x_range = max(experiment.avgT)-min(experiment.avgT);
y_range = max(trace)-min(trace);
xlim([min(experiment.avgT)-x_range*0.01 max(experiment.avgT)+x_range*0.01]);
ylim([min(trace)-y_range*0.01 max(trace)+y_range*0.01]);
box on;
title([type ' fluorescence trace']);
set(gcf,'Color','w');
pos = get(hFig, 'Position');
pos(4) = pos(3)/((1+sqrt(5))/2);
set(hFig, 'Position', pos);

ui = uimenu(hFig, 'Label', 'Export');
uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf';'*.eps'; '*.tiff'; '*.png'}, [experiment.folder experiment.name '_' type 'Trace']});

if(params.saveFigure)
  if(~exist(experiment.folder, 'dir'))
    mkdir(experiment.folder);
  end
  figFolder = [experiment.folder 'figures' filesep];
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
