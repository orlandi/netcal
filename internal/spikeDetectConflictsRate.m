function experiment = spikeDetectConflictsRate(experiment, varargin)
% SPIKEDETECTCONFLICTSRATE detects conflicts in spike trains based on rates
%
% USAGE:
%    experiment = spikeDetectConflictsRate(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: spikeDetectConflictsRateOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = spikeDetectConflictsRate(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% EXPERIMENT PIPELINE
% name: detect spike conflicts (rate based)
% parentGroups: spikes
% optionsClass: spikeDetectConflictsRateOptions
% requiredFields: spikes, validPatterns, folder, name, fps
% producedFields: conflictingSpikes

[params, var] = processFunctionStartup(spikeDetectConflictsRateOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Detecting conflicts (rate-based)', true);
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

conflictingSpikes = cell(size(experiment.spikes));

% Time to iterate through all the groups
for git = 1:length(groupList)
  if(params.pbar > 0)
    ncbar.setBarTitle(sprintf('Detecting conflicts from group: %s', groupList{git}));
  end
  if(strcmpi(groupList{git}, 'none'))
    members = 1:length(experiment.ROI);
    %groupName = 'everything';
    %groupIdx = 1;
  else
    [members, ~, ~] = getExperimentGroupMembers(experiment, groupList{git});
  end
  
  % Check for empty group
  if(isempty(members) && params.verbose)
    logMsg(sprintf('Found empty group: %s', groupList{git}), 'w');
    continue;
  end
  
  conflictingSpikes(members) = detectConflicts(experiment.spikes(members), params.maxBurstLength, params.maxBurstISI);
  %[patterns, ~] = generatePatternList(experiment);
  
  %traces(:, members)
  
  
  logMsg(sprintf('Found %d conflicts',  sum(cellfun(@length, conflictingSpikes))));
end

experiment.conflictingSpikes = conflictingSpikes;

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

  %------------------------------------------------------------------------
  function conflicts = detectConflicts(spikes, maxBurstLength, maxBurstISI)
  
    conflicts = cell(size(spikes));
    % Iterate from each cell
    for i = 1:length(spikes)
      validSpikes = spikes{i};
      % Fist detect the bursts
      clusterdiff = diff(validSpikes);
      insideCluster = false;
      bursts = nan(size(validSpikes));
      currCluster = 0;
      for it = 1:length(clusterdiff)
        % Check if two spikes are within the maximum time
        if(clusterdiff(it) <= maxBurstISI)
          % Check if we are already inside a cluster
          if(insideCluster)
            % Just add the new spike to the previous cluster
            bursts(it+1) = bursts(it-1);
          else
            insideCluster = true;
            currCluster = currCluster + 1;
            bursts(it) = currCluster;
            bursts(it+1) = currCluster;
          end
        else
          % If we were in a cluster, drop it
          insideCluster = false;
        end
      end

      [~, I] = unique(bursts);
      uniqueBursts = bursts(sort(I));
      % Here we iterate through the valid bursts
      for it = 1:length(uniqueBursts)
        valid = find(bursts == uniqueBursts(it));
        totalT = max(validSpikes(valid))-min(validSpikes(valid));
        if(totalT > maxBurstLength)
          conflicts{i} = [conflicts{i}; valid(:)]; % Store the index of the spike that is a conflict
        end
      end
    end
  end
end
