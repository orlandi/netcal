function experiment = spikeDetectConflicts(experiment, varargin)
% SPIKEDETECTCONFLICTS detects conflicts in spike trains
%
% USAGE:
%    experiment = spikeDetectConflicts(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: spikeDetectConflictsOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = spikeDetectConflicts(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% EXPERIMENT PIPELINE
% name: detect spike conflicts (pattern based)
% parentGroups: spikes
% optionsClass: spikeDetectConflictsOptions
% requiredFields: spikes, validPatterns, folder, name, fps
% producedFields: conflictingSpikes

[params, var] = processFunctionStartup(spikeDetectConflictsOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Detecting conflicts (pattern based)', true);
%--------------------------------------------------------------------------

% Load previous patterns
experiment = loadTraces(experiment, 'validPatterns');


% Fix in case for some reason the group is a cell
if(iscell(params.group))
  mainGroup = params.group{1};
else
  mainGroup = params.group;
end

% These groups should be cells
if(iscell(params.conflictingGroups))
  conflictingGroups = params.conflictingGroups;
else
  conflictingGroups = {params.conflictingGroups};
end
if(iscell(params.exclusionGroups))
  exclusionGroups = params.exclusionGroups;
else
  exclusionGroups = {params.exclusionGroups};
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
  
  conflictingSpikes(members) = detectConflicts(experiment.spikes(members), experiment.validPatterns(members), conflictingGroups, params.conflictingGroupExpansion, exclusionGroups, experiment.fps);
  %[patterns, ~] = generatePatternList(experiment);
  
  %traces(:, members)
  
  
  logMsg(sprintf('Found %d conflicts',  sum(cellfun(@length, conflictingSpikes))));
end

experiment.conflictingSpikes = conflictingSpikes;

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

  %------------------------------------------------------------------------
  function conflicts = detectConflicts(spikes, validPatterns, conflictingGroups, conflictingGroupsExpansion, exclusionGroups, fps)
    expansionFrames = round(conflictingGroupsExpansion*fps);
    conflicts = cell(size(spikes));
    %conflictsFrames = cell(size(spikes));
    % Iterate from each cell
    for i = 1:length(spikes)
      curSpikes = spikes{i};
      curPatterns = validPatterns{i};
      % And from each conflicting group
      for j = 1:length(conflictingGroups)
        curGroup = conflictingGroups{j};
        % Now from the valid patterns
        for k = 1:length(curPatterns)
          % If the pattern is not in the conflicting group, skip
          if(~strcmp(curPatterns{k}.basePattern, curGroup))
            continue;
          end
          % And finally for each spikes
          for l = 1:length(curSpikes)
            curFrame = round(curSpikes(l)*fps);
            if(expansionFrames == 0)
              framesToCheck = curPatterns{k}.frames;
            else
              framesToCheck = (curPatterns{k}.frames(1)-expansionFrames):(curPatterns{k}.frames(end)+expansionFrames);
            end
            if(any(framesToCheck == curFrame))
              % There's a conflict - check with the other group
              realConflict = true;
              for m = 1:length(exclusionGroups)
                curExclusionGroup = exclusionGroups{m};
                for n = 1:length(curPatterns)
                  if(~strcmp(curPatterns{n}.basePattern, curExclusionGroup))
                    continue;
                  else
                    % It is a pattern from an exclusion group, let's check
                    if(any(curPatterns{n}.frames == curFrame))
                      realConflict = false;
                      break;
                    end
                  end
                end
              end
              if(realConflict)
                conflicts{i} = [conflicts{i}; l]; % Store the index of the spike that is a conflict
                %conflictsFrames{i} = [conflictsFrames{i}; curFrame]; % Store also the frame for easy elimination later on
              end
            end
          end
        end
      end
    end
  end
end
