function experiment = detectDyingCells(experiment, varargin)
% DETECTDYINGCELLS Detects dying cells
%
% USAGE:
%    experiment = detectDyingCells(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: detectDyingCellsOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = detectDyingCells(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% EXPERIMENT PIPELINE
% name: detect dying cells
% parentGroups: fluorescence: group classification
% optionsClass: detectDyingCellsOptions
% requiredFields: validPatterns, ROI, folder, name

[params, var] = processFunctionStartup(detectDyingCellsOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Detecting dying cells');
%--------------------------------------------------------------------------

% Load previous patterns NOT HERE
%experiment = loadTraces(experiment, 'validPatterns');

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
    ncbar.setBarTitle(sprintf('Detecting dying cells from group: %s', groupList{git}));
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
  
  
  experiment = loadTraces(experiment, 'raw');
  t = experiment.rawT;
  traces = experiment.rawTraces;
  
  stdThreshold = params.stdThreshold;

  peekFrames = round(params.peekLength*experiment.fps);
  pastFrames = round(params.pastLength*experiment.fps);

  % Do the detection
  
  currentTraces = traces(:, members);
  dyingCells = zeros(length(members), 1);
  dyingCellsData = cell(length(members), 1);
  for it = 1:length(dyingCells)
    signal = currentTraces(:, it);
    newSignal = nan(size(signal));
    pastStart = 1;
    for it2 = 1:params.frameJump:length(signal)
      pastPoint = max(pastStart, it2-pastFrames);
      futurePoint = min(length(signal), it2+peekFrames);
      prevStd = std(signal(pastPoint:it2));
      prevMean = mean(signal(pastPoint:it2));
      %futureMean = mean(signal(it:futurePoint));
      if(all(abs(signal(it2:futurePoint)-prevMean) > stdThreshold*prevStd))
        newSignal(it2) = 1;
      else
        newSignal(it2) = NaN;
      end
    end
    if(any(newSignal == 1))
      dyingCells(it) = 1;
      dyingCellsData{it} = find(newSignal == 1);
    end
    ncbar.update(it/length(dyingCells));
  end
  
  if(~isfield(experiment, 'dyingCellsData'))
    experiment.dyingCellsData = cell(size(traces, 2), 1);
    experiment.dyingCellsData(members) = dyingCellsData;
    experiment.dyingCells = zeros(size(traces, 2), 1);
    experiment.dyingCells(members) = dyingCells;
  else
    try
      experiment.dyingCellsData(members) = dyingCellsData;
      experiment.dyingCells(members) = dyingCells;
    catch ME
      experiment.dyingCellsData = cell(size(traces, 2), 1);
      experiment.dyingCellsData(members) = dyingCellsData;
      experiment.dyingCells = zeros(size(traces, 2), 1);
      experiment.dyingCells(members) = dyingCells;
      logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
    end
  end
  experiment.traceGroupsNames.dyingCells = cell(1);
  experiment.traceGroupsNames.dyingCells{1} ='Dying cells';
  experiment.traceGroups.dyingCells = cell(1);
  experiment.traceGroups.dyingCells{1} = find(experiment.dyingCells);
  experiment.traceGroupsOrder.ROI.dyingCells = cell(1);
  experiment.traceGroupsOrder.ROI.dyingCells{1} = 1:length(experiment.traceGroups.dyingCells{1});
  %if(params.verbose)
  logMsg(sprintf('Found %d dying cells',  sum(dyingCells)));
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

end
