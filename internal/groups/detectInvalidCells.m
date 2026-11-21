function experiment = detectInvalidCells(experiment, varargin)
% DETECTINVALIDCELLS Detects invalid cells (nans) and create a new group
% without them
%
% USAGE:
%    experiment = detectInvalidCells(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see:
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = detectInvalidCells(experiment)
%
% Copyright (C) 2016-2025, Javier G. Orlandi <javier.orlandi@ucalgary.ca>

% EXPERIMENT PIPELINE
% name: detect invalid cells
% parentGroups: fluorescence: group classification
% optionsClass: detectInvalidCellsOptions
% requiredFields: traces, ROI, folder, name

[params, var] = processFunctionStartup(detectInvalidCellsOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Detecting invalid cells');
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
    ncbar.setBarTitle(sprintf('Detecting invalid cells from group: %s', groupList{git}));
  end
  if(strcmpi(groupList{git}, 'none'))
    members = 1:length(experiment.ROI);
    groupName = 'everything';
    groupIdx = 1;
  else
    [members, groupName, groupIdx] = getExperimentGroupMembers(experiment, groupList{git});
  end
  
  % Check for empty group
  if(isempty(members) && params.verbose)
    logMsg(sprintf('Found empty group: %s', groupList{git}), 'w');
    continue;
  end
  
  
  experiment = loadTraces(experiment, params.traces);
  switch params.traces
    case 'raw'
      t = experiment.rawT;
      traces = experiment.rawTraces;
    case 'smoothed'
      t = experiment.t;
      traces = experiment.traces;
  end


  % Do the detection
  
  currentTraces = traces(:, members);
  validCells = find(~isnan(sum(currentTraces)));

  
  experiment.traceGroupsNames.validCells = cell(1);
  experiment.traceGroupsNames.validCells{1} ='Valid cells';
  experiment.traceGroups.validCells = cell(1);
  experiment.traceGroups.validCells{1} = validCells;
  experiment.traceGroupsOrder.ROI.validCells = cell(1);
  experiment.traceGroupsOrder.ROI.validCells{1} = 1:length(validCells);
  %if(params.verbose)
  logMsg(sprintf('Found %d valid cells out of %d',  length(validCells), length(members)));
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

end
