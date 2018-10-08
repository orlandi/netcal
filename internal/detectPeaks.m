function experiment = detectPeaks(experiment, varargin)
% DETECTPEAKS Uses MATLAB function findpeaks to detect peaks int races
%
% USAGE:
%    experiment = detectPeaks(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: detectPeaksOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = detectPeaksOptions(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% EXPERIMENT PIPELINE
% name: detect peaks
% parentGroups: fluorescence: group classification: pattern-based
% optionsClass: detectPeaksOptions
% requiredFields: t, traces, ROI, folder, name

[params, var] = processFunctionStartup(detectPeaksOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Detecting peaks');
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
nPeaks = 0;
for git = 1:length(groupList)
  if(params.pbar > 0)
    ncbar.setBarTitle(sprintf('Detecting peaks from group: %s', groupList{git}));
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
  
  % We will get the members later
  switch params.tracesType
    case 'smoothed'
      experiment = loadTraces(experiment, 'normal');
      t = experiment.t;
      traces = experiment.traces;
    case 'raw'
      experiment = loadTraces(experiment, 'raw');
      t = experiment.rawT;
      traces = experiment.rawTraces;
    case 'denoised'
      experiment = loadTraces(experiment, 'rawTracesDenoised');
      t = experiment.rawTDenoised;
      traces = experiment.rawTraces;
  end
  
  % The actual detection
  subTraces = traces(:, members);
  subPks = cell(length(members), 1);
  for it = 1:length(members)
    data = subTraces(:, it);
    [~, b] = sort(data);
    skList = zeros(size(b));
    for it2 = 100:1000:length(skList)
      skList = skewness(data(b(1:it2)));
      if(skList > 0)
        break;
      end
    end
    newStd = std(data(b(1:it2)));
    data = (data-mean(data))/newStd;
    [pks, locs, w, p] = findpeaks(data, experiment.fps, 'MinPeakHeight', params.minPeakHeight, 'MinPeakProminence', params.minPeakProminence);
    if(~isempty(peaks))
      subPks{it} = struct;
      for it2 = 1:length(pks)
        nPeaks = nPeaks +1;
        subPks{it}(it2).F = pks(it2);
        subPks{it}(it2).frame = round(locs(it2)*experiment.fps);
        subPks{it}(it2).width = w(it2)*experiment.fps;
        subPks{it}(it2).prominence = p(it2);
      end
    else
      subPks{it} = [];
    end
    ncbar.update(it/length(members));
  end
  
  if(~isfield(experiment, 'peaks'))
    experiment.peaks = cell(size(traces, 2), 1);
    experiment.peaks(members) = subPks;
  else
    try
      experiment.peaks(members) = subPks;
    catch ME
      experiment.peaks = cell(size(traces, 2), 1);
      experiment.peaks(members) = subPks;
      logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
    end
  end
  %if(params.verbose)
  logMsg(sprintf('Found %d peaks',  nPeaks));

end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

end