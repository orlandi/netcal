function experiment = spikeInferenceSchmitt(experiment, varargin)
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
%   gui - handle of the external GUI
%
%   subset - only get spikes for a particular subset of traces (idx list)
%
% OUTPUT arguments:
%   experiment - structure containing an experiment
%
% EXAMPLE:
%   experiment = spikeInferenceSchmitt(experiment, schmittOptions)
%
% Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also schmittOptions

% Pass class options
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(schmittOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.training = false;
params.subset = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Performing schmitt inference');
%--------------------------------------------------------------------------

experiment = loadTraces(experiment, 'smoothed');
traces = experiment.traces;

if(isempty(params.subset))
  subset = size(traces, 2);
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

    hold on;

    burstDuration = zeros(length(validSplit), 1);
    burstAmplitude = zeros(length(validSplit), 1);
    burstArea = zeros(length(validSplit), 1);
    burstStart = zeros(length(validSplit), 1);
    burstFrames = cell(length(validSplit), 1);
    for i = 1:length(validSplit)
        burstFrames{i} = split(validSplit(i)):(split(validSplit(i))+length(splitVals{validSplit(i)})-1);
        burstT = t(burstFrames{i});
        burstF = avgTraceAbove(burstFrames{i});
        burstDuration(i) = burstT(end)-burstT(1);
        burstStart(i) = burstT(1);
        burstAmplitude(i) = max(burstF);
        if(length(burstT) < 2)
          burstArea(i) = 0;
        else
          burstArea(i) = trapz(burstT, abs(burstF));
        end
    end
    IBI = diff(burstStart);
    burstStructure = struct;
    burstStructure.duration = burstDuration;
    burstStructure.amplitude = burstAmplitude;
    burstStructure.area = burstArea;
    burstStructure.start = burstStart;
    burstStructure.IBI = IBI;
    burstStructure.frames = burstFrames;
    burstStructure.thresholds = [lowerThreshold upperThreshold];
  end

end