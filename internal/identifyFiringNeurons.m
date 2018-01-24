function experiment = identifyFiringNeurons(experiment, varargin)
% IDENTIFYFIRINGNEURONS creates a new group with those cells with more than 1 spike
%
% USAGE:
%    experiment = identifyHCGidentifyFiringNeuronsexperiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: identifyFiringNeuronsOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = identifyFiringNeurons(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also extractTraces

% EXPERIMENT PIPELINE
% name: identify firing neurons
% parentGroups: spikes
% optionsClass: identifyFiringNeuronsOptions
% requiredFields: spikes

% Pass class options
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(identifyFiringNeuronsOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Identifying Firing Neurons');
%--------------------------------------------------------------------------

% Fix in case for some reason the group is a cell
if(iscell(params.group))
  mainGroup = params.group{1};
else
  mainGroup = params.group;
end

members = getAllMembers(experiment, mainGroup);


experiment.traceGroups.activity = cell(2, 1);
experiment.traceGroupsNames.activity = cell(2, 1);
experiment.traceGroupsOrder.ROI.activity = cell(2, 1);
experiment.traceGroupsOrder.similarity.activity = cell(2, 1);


valid = cellfun(@(x)length(x), experiment.spikes(members), 'UniformOutput', true) >= params.minimumSpikes;
active = members(valid);
notActive = members(~valid);

experiment.traceGroups.activity{1} = active;
experiment.traceGroupsNames.activity{1} = 'firing';
experiment.traceGroupsOrder.ROI.activity{1} = sort(active);
experiment.traceGroups.activity{2} = notActive;
experiment.traceGroupsNames.activity{2} = 'not firing';
experiment.traceGroupsOrder.ROI.activity{2} = sort(notActive);

logMsg(sprintf('Found (%d/%d) firing neurons on experiment %s', length(experiment.traceGroups.activity{1}), length(members), experiment.name), 'w');

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
