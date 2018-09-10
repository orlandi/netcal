function experiment = exportDataAverageTrace(experiment, varargin)
% EXPORTDATAAVERAGETRACE exports the avearge trace data
%
% USAGE:
%    experiment = exportDataAverageTrace(experiment, varargin)
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
%    experiment = exportDataAverageTrace(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% EXPERIMENT PIPELINE
% name: export average trace
% parentGroups: fluorescence: basic: exports
% optionsClass: exportBaseOptions
% requiredFields: avgT, avgTrace, folder, name

% Pass class options
optionsClass = exportBaseOptions;
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

if(~exist(experiment.folder, 'dir'))
  mkdir(experiment.folder);
end
dataFolder = [experiment.folder 'data' filesep];
if(~exist(dataFolder, 'dir'))
  mkdir(dataFolder);
end

exportDataCallback([], [], [], [], ...
                   [experiment.avgT(:), experiment.avgTrace(:)], ...
                   {'time (s)', 'fluorescence (a.u.)'}, ...
                   params.sheetName, [], ...
                   [dataFolder, experiment.name, '_averageTrace', params.exportFileTag, '.', params.exportType]);
