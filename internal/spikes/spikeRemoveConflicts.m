function experiment = spikeRemoveConflicts(experiment, varargin)
% SPIKEREMOVECONFLICTS removes conflicts in spike trains
%
% USAGE:
%    experiment = spikeRemoveConflicts(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: spikeRemoveConflictsOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = spikeRemoveConflicts(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% EXPERIMENT PIPELINE
% name: remove spike conflicts
% parentGroups: spikes
% optionsClass: spikeRemoveConflictsOptions
% requiredFields: spikes, conflictingSpikes, folder, name

[params, var] = processFunctionStartup(spikeRemoveConflictsOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Removing conflicts', true);
%--------------------------------------------------------------------------


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

% Time to iterate through all the groups
for git = 1:length(groupList)
  if(params.pbar > 0)
    ncbar.setBarTitle(sprintf('Removing conflicts from group: %s', groupList{git}));
  end
  if(strcmpi(groupList{git}, 'none'))
    members = 1:length(experiment.ROI);
  else
    [members, ~, ~] = getExperimentGroupMembers(experiment, groupList{git});
  end
  
  % Check for empty group
  if(isempty(members) && params.verbose)
    logMsg(sprintf('Found empty group: %s', groupList{git}), 'w');
    continue;
  end
  
  % Do the actual removing
  %conflictingSpikes(members) = detectConflicts(experiment.spikes(members), experiment.validPatterns(members), conflictingGroups, exclusionGroups, experiment.fps);
  cSpikes = experiment.spikes(members);
  oldCount = sum(cellfun(@length, cSpikes));
  for i = 1:length(cSpikes)
    cSpikes{i} = cSpikes{i}(setdiff(1:length(cSpikes{i}), experiment.conflictingSpikes{members(i)}));
  end
  cSpikes = cellfun(@(x)x(:)', cSpikes, 'UniformOutput', false);
  
  experiment.spikes(members) = cSpikes;
  experiment.conflictingSpikes(members) = cell(length(members), 1);
  logMsg(sprintf('Removed %d spikes',  oldCount-sum(cellfun(@length, cSpikes))));
end


%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

end