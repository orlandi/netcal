function experiment = burstDetectionSpikes(experiment, varargin)
% BURSTDETECTIONSPIKES detects bursts using spike data for a given group
%
% USAGE:
%    experiment = burstDetectionSpikes(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: burstDetectionSpikesOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = burstDetectionSpikesOptions(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% EXPERIMENT PIPELINE
% name: burst detection
% parentGroups: spikes
% optionsClass: burstDetectionSpikesOptions
% requiredFields: spikes, ROI, folder, name

[params, var] = processFunctionStartup(burstDetectionSpikesOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Detecting bursts', true);
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
    ncbar.setBarTitle(sprintf('Detecting bursts from group: %s', groupList{git}));
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
  
  experiment.spikes = cellfun(@(x)x(:)', experiment.spikes, 'UniformOutput', false);
  if(isempty(params.averageActivityBinning))
    params.averageActivityBinning = 1/experiment.fps;
  end
  dt = params.averageActivityBinning;
  binnedSpikes = [experiment.spikes{members}];
  binnedSpikes = floor(binnedSpikes/dt);
  [avgT, t] = hist(binnedSpikes, 0:max(experiment.t/dt));
  t = t*dt;
  %avgT = mean(traces(:, members), 2);
  % The actual detection
  burstList = detectBurstsSchmitt(t, avgT, params.schmittThresholdType, params.schmittThresholds(1), params.schmittThresholds(2));
  
  figure;
  %h1 = bar(t, avgT/length(members));
  h1 = bar(t, avgT);
  hold on;
  validFrames = [];
  for it = 1:length(burstList.duration)
    validFrames = [validFrames, floor(burstList.start(it)/dt):floor((burstList.start(it)+burstList.duration(it))/dt)];
  end
  
  if(~isempty(validFrames))
    validFrames = validFrames + 1; 
    %h = bar(t(validFrames), avgT(validFrames)/length(members));
    h = bar(t(validFrames), avgT(validFrames));
    h.FaceColor = h1.FaceColor;
    h.EdgeColor = 'r';
  end
  xlim([min(experiment.t) max(experiment.t)]);
  xl = xlim;
  %plot(xl, [1 1]*burstList.thresholds(3)/length(members));
  %plot(xl, [1 1]*burstList.thresholds(4)/length(members));
  plot(xl, [1 1]*burstList.thresholds(3));
  plot(xl, [1 1]*burstList.thresholds(4));
  ylabel('Num spikes per bin');
  title(sprintf('%s - N: %d <IBI>: %.2g', experiment.name, length(burstList.start), mean(burstList.IBI)));
  
  experiment.spikeBursts.(groupName){groupIdx} = burstList;
  %if(params.verbose)
    logMsg(sprintf('%d bursts detected on group %s', length(burstList.start), groupList{git}));
    logMsg(sprintf('%.2f s mean duration', mean(burstList.duration)));
    logMsg(sprintf('%.2f mean maximum amplitude', mean(burstList.amplitude)));
    logMsg(sprintf('%.2f s mean IBI', mean(burstList.IBI)));
  %end
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

  %------------------------------------------------------------------------
  function burstStructure = detectBurstsSchmitt(t, avgTrace, thresholdType, upperThreshold, lowerThreshold)
    
    switch thresholdType
      case 'relative'
        avgMean = mean(avgTrace);
        avgStd = std(avgTrace);
        y = schmitt_trigger(avgTrace, avgMean+lowerThreshold*avgStd, avgMean+upperThreshold*avgStd);
      case 'absolute'
        y = schmitt_trigger(avgTrace, lowerThreshold, upperThreshold);
    end
    avgTraceAbove = nan(size(avgTrace));
    avgTraceAbove(find(y)) = avgTrace(find(y));

    split = SplitVec(y, 'equal', 'first');
    splitVals = SplitVec(y, 'equal');
    validSplit = find(y(split) == 1);

    %out = SplitVec(aboveThreshold, 'consecutive');
    %hold on;
    %plot(selectedT, avgTraceAbove);

    burstDuration = zeros(length(validSplit), 1);
    burstAmplitude = zeros(length(validSplit), 1);
    burstStart = zeros(length(validSplit), 1);
    burstFrames = cell(length(validSplit), 1);
    for i = 1:length(validSplit)
      burstFrames{i} = split(validSplit(i)):(split(validSplit(i))+length(splitVals{validSplit(i)})-1);
      burstT = t(burstFrames{i});
      burstF = avgTraceAbove(burstFrames{i});
      burstDuration(i) = burstT(end)-burstT(1);
      burstStart(i) = burstT(1);
      burstAmplitude(i) = max(burstF);
      %plot(burstT, burstF, 'LineWidth', 2);
    end
    IBI = diff(burstStart);
    burstStructure = struct;
    burstStructure.duration = burstDuration;
    burstStructure.amplitude = burstAmplitude;
    burstStructure.start = burstStart;
    burstStructure.IBI = IBI;
    burstStructure.frames = burstFrames;
    switch thresholdType
      case 'relative'
        burstStructure.thresholds = [lowerThreshold upperThreshold avgMean+lowerThreshold*avgStd avgMean+upperThreshold*avgStd];
      case 'absolute'
        burstStructure.thresholds = [lowerThreshold upperThreshold lowerThreshold upperThreshold];
    end
  end
end
