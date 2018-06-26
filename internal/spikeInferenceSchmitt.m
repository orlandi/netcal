function [experiment, trainingData] = spikeInferenceSchmitt(experiment, varargin)
% SPIKEINFERENCESCHMITT Does spike detection using a schmitt trigger
%
% USAGE:
%   experiment = spikeInferenceSchmitt(experiment, options)
%
% INPUT arguments:
%   experiment - structure containing an experiment
%
% INPUT optional arguments:
%   options - object from class peelingOptions
%
% INPUT optional arguments ('key' followed by its value):
%
%   subset - only get spikes for a particular subset of traces (idx list)
%
%   training - (true/false) if we are traning on a single trace
%
% OUTPUT arguments:
%   experiment - structure containing an experiment
%
%   trainingData - structure containing the training data
%
% EXAMPLE:
%   experiment = spikeInferenceSchmitt(experiment, schmittOptions)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also schmittOptions

% EXPERIMENT PIPELINE
% name: schmitt inference
% parentGroups: spikes: inference
% optionsClass: schmittOptions
% requiredFields: traces, rawTraces, t, fps
% producedFields: spikes

% Pass class options
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(schmittOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.subset = [];
params.training = false;
% Parse them
params = parse_pv_pairs(params, var);
if(params.training)
  params.pbar = 0;
end
params = barStartup(params, 'Running schmitt');
%--------------------------------------------------------------------------

% Fix in case for some reason the group is a cell
if(iscell(params.group))
  mainGroup = params.group{1};
else
  mainGroup = params.group;
end
% Fix chars
if(ischar(params.minimumEventAmplitude))
  params.minimumEventAmplitude = str2double(params.minimumEventAmplitude);
end
if(ischar(params.minimumEventDuration))
  params.minimumEventDuration = str2double(params.minimumEventDuration);
end

members = getAllMembers(experiment, mainGroup);

switch params.tracesType
  case 'smoothed'
    experiment = loadTraces(experiment, 'normal');
    traces = experiment.traces;
  case 'raw'
    experiment = loadTraces(experiment, 'raw');
    traces = experiment.rawTraces;
  case 'denoised'
    experiment = loadTraces(experiment, 'rawTracesDenoised');
    traces = experiment.rawTracesDenoised;
end

if(isempty(params.subset))
  subset = members;
else
  subset = params.subset;
end

if(~isfield(experiment, 'spikes') || length(experiment.spikes) ~= size(traces, 2) && ~params.training)
  experiment.spikes = cell(size(traces,2), 1);
  for it = 1:length(experiment.spikes)
    experiment.spikes{it} = nan(1, 1);
  end
end  

if(~isfield(experiment, 'schmittSpikesData') || length(experiment.schmittSpikesData) ~= size(experiment.rawTraces, 2) && ~params.training)
  experiment.schmittSpikesData = cell(size(traces,2), 1);
  for it = 1:length(experiment.schmittSpikesData)
    experiment.schmittSpikesData{it} = [];
  end
end    

schmittSpikes = cell(length(subset), 1);
schmittSpikesData = cell(length(subset), 1);

% Do the actual inference
for it = 1:length(subset)
  selectedTrace = subset(it);
  schmittSpikesData{it} = detectBurstsSchmitt(experiment.t, traces(:, selectedTrace)', params.lowerThreshold, params.upperThreshold, params.thresholdType);
  %
  schmittSpikes{it} = schmittSpikesData{it}.start';

  if(params.verbose && params.pbar > 0 && ~params.training)
    ncbar.update(it/length(subset));
  end
end

if(params.training)
  trainingData = schmittSpikesData{it};
  trainingData.spikes = schmittSpikes{it};
end

for it = 1:length(subset)
  experiment.spikes{subset(it)} = schmittSpikes{it};
  experiment.schmittSpikesData{subset(it)} = schmittSpikesData{it};
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

  %--------------------------------------------------------------------------
  function burstStructure = detectBurstsSchmitt(t, avgTrace, lowerThreshold, upperThreshold, thresholdType)
    avgMean = mean(avgTrace);
    avgStd = std(avgTrace);
    switch thresholdType
      case 'relative'
        y = schmitt_trigger(avgTrace, avgMean+lowerThreshold*avgStd, avgMean+upperThreshold*avgStd);
      case 'absolute'
        y = schmitt_trigger(avgTrace, lowerThreshold, upperThreshold);
    end
    avgTraceAbove = nan(size(avgTrace));
    avgTraceAbove(find(y)) = avgTrace(find(y));

    split = SplitVec(y, 'equal', 'first');
    splitVals = SplitVec(y, 'equal');
    validSplit = find(y(split) == 1);

    burstDuration = zeros(length(validSplit), 1);
    burstAmplitude = zeros(length(validSplit), 1);
    burstArea = zeros(length(validSplit), 1);
    burstMean = zeros(length(validSplit), 1);
    burstStd = zeros(length(validSplit), 1);
    burstSke = zeros(length(validSplit), 1);
    burstMeanF = zeros(length(validSplit), 1);
    burstStdF = zeros(length(validSplit), 1);
    burstSkeF = zeros(length(validSplit), 1);
    burstStart = zeros(length(validSplit), 1);
    burstTimeToMax = zeros(length(validSplit), 1);
    burstSlopeUp = zeros(length(validSplit), 1);
    burstSlopeDown = zeros(length(validSplit), 1);
    burstFrames = cell(length(validSplit), 1);
    validBursts = zeros(length(validSplit), 1);
    for i = 1:length(validSplit)
      burstFrames{i} = split(validSplit(i)):(split(validSplit(i))+length(splitVals{validSplit(i)})-1);
      burstT = t(burstFrames{i});
      burstF = avgTraceAbove(burstFrames{i});
      burstDuration(i) = burstT(end)-burstT(1);
      burstStart(i) = burstT(1);
      [burstAmplitude(i), maxFrame] = max(burstF);
      if(length(burstT) < 2)
        burstArea(i) = 0;
      else
        burstArea(i) = trapz(burstT, abs(burstF));
        burstMean(i) = trapz(burstT, burstT'.*abs(burstF))/burstArea(i);
        burstStd(i) = sqrt(trapz(burstT, (burstT'-burstMean(i)).^2.*abs(burstF))/burstArea(i));
        burstSke(i) = trapz(burstT, (burstT'-burstMean(i)).^3.*abs(burstF))/burstArea(i)/burstStd(i)^3;
        burstMeanF(i) = mean(burstF);
        burstStdF(i) = std(burstF);
        burstSkeF(i) = skewness(burstF);
        burstTimeToMax(i) = t(burstFrames{i}(maxFrame))-t(burstFrames{i}(1));
        burstSlopeUp(i) = (burstAmplitude(i)-burstF(1))/burstTimeToMax(i);
        burstSlopeDown(i) = (burstF(end)-burstAmplitude(i))/(t(burstFrames{i}(end))-t(burstFrames{i}(maxFrame)));
      end
      invalid = false;
      if(~isempty(params.minimumEventAmplitude) && max(burstF) < params.minimumEventAmplitude)
        invalid = true;
      elseif(~isempty(params.minimumEventDuration) && burstDuration(i) < params.minimumEventDuration)
        invalid = true;
      end
      if(~invalid)
        validBursts(i) = 1;
      end
    end
    validBurstsList = find(validBursts);
    IBI = diff(burstStart(validBurstsList));
    burstStructure = struct;
    burstStructure.duration = burstDuration(validBurstsList);
    burstStructure.amplitude = burstAmplitude(validBurstsList);
    burstStructure.area = burstArea(validBurstsList);
    burstStructure.mean = burstMean(validBurstsList);
    burstStructure.std = burstStd(validBurstsList);
    burstStructure.ske = burstSke(validBurstsList);
    burstStructure.meanF = burstMeanF(validBurstsList);
    burstStructure.stdF = burstStdF(validBurstsList);
    burstStructure.skeF = burstSkeF(validBurstsList);
    burstStructure.start = burstStart(validBurstsList);
    burstStructure.timeToMax = burstTimeToMax(validBurstsList);
    burstStructure.slopeUp = burstSlopeUp(validBurstsList);
    burstStructure.slopeDown = burstSlopeDown(validBurstsList);
    burstStructure.IBI = IBI;
    burstStructure.frames = burstFrames(validBurstsList);
    burstStructure.thresholds = [lowerThreshold upperThreshold];
    burstStructure.minimumEventDuration = params.minimumEventDuration;
    burstStructure.minimumEventAmplitude = params.minimumEventAmplitude;
  end

end