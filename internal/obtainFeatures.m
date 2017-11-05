function experiment = obtainFeatures(experiment, varargin)
% OBTAINFEATURES obtain features from fluorescence traces
%
% USAGE:
%    experiment = obtainFeatures(experiment)
%
% INPUT arguments:
%    experiment - structure obtained from loadExperiment()
%
% INPUT optional arguments ('key' followed by its value):
%
%    See obtainFeaturesOptions
%
% EXAMPLE:
%    experiment = obtainFeatures(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% EXPERIMENT PIPELINE
% name: compute features
% parentGroups: fluorescence: group classification: feature-based
% optionsClass: obtainFeaturesOptions
% requiredFields: traces, t
% producedFields: features

%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(obtainFeaturesOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Obtaining trace features');
%--------------------------------------------------------------------------

experiment = loadTraces(experiment, 'normal');
traces = experiment.traces;
t = experiment.t;
stdThresholdList = params.stdThresholdList;
Nepochs = params.Nepochs;
if(isempty(Nepochs))
  Nepochs = 1;
end
if(numel(Nepochs) == 1)
  epochsSplit = round(linspace(0, length(t), Nepochs+1));
else
  epochsSplit = Nepochs;
  Nepochs = numel(Nepochs)-1;
end

featuresNames = {};
for i = 1:Nepochs
  for j = 1:length(stdThresholdList)
  featuresNames{end+1} = sprintf('freq data above threshold (Hz) - ep: %d - thr: %d', i, j);
  featuresNames{end+1} = sprintf('avg interval clusters above threshold (IBI) (s) - ep: %d - thr: %d', i, j);
  featuresNames{end+1} = sprintf('std clusters interval above threshold (s) - ep: %d - thr: %d', i, j);
  featuresNames{end+1} = sprintf('freq clusters above threshold (Hz) - ep: %d - thr: %d', i, j);
  featuresNames{end+1} = sprintf('avg cluster duration (s) - ep: %d - thr: %d', i, j);
  featuresNames{end+1} = sprintf('std cluster duration (s) - ep: %d - thr: %d', i, j);
  featuresNames{end+1} = sprintf('avg time between clusters (s) - ep: %d - thr: %d', i, j);
  featuresNames{end+1} = sprintf('std time between clusters (s) - ep: %d - thr: %d', i, j);
  featuresNames{end+1} = sprintf('avg cluster area (s*F) - ep: %d - thr: %d', i, j);
  featuresNames{end+1} = sprintf('freq cluster area (F) - ep: %d - thr: %d', i, j);
  end
end
featuresNames{end+1} = sprintf('avg fluorescence');
featuresNames{end+1} = sprintf('std fluorescence');
featuresNames{end+1} = sprintf('skewness fluorescence');
featuresNames{end+1} = sprintf('mean lower 5%% fluorescence');
featuresNames{end+1} = sprintf('mean higher 5%% fluorescence');


features = zeros(size(traces, 2), length(featuresNames)); % Wrong dimensions


avgStd = mean(std(traces));

for i = 1:size(traces, 2)
  currFeature = 1;
  % Epochs
  for ep = 1:Nepochs
    data = traces((epochsSplit(ep)+1):epochsSplit(ep+1), i);
    % weird Z norm the data
    data = smooth((data-mean(data))/avgStd);

    % Generate features for various threshold levels
    for j = 1:length(stdThresholdList)

      aboveThreshold = find(data >= mean(data) + stdThresholdList(j));

      % Number of points above threshold (per unit time)
      features(i, currFeature) = length(aboveThreshold)/(max(t)-min(t));
      currFeature = currFeature + 1;

      % Mean frames between points above threshold (equivalent to IBI)
       %IEI=diff(t(aboveThreshold));
       IEI=diff((aboveThreshold));
       if(~isempty(IEI))
           features(i, currFeature) = mean(IEI(IEI>1))*experiment.fps;
       end
       currFeature = currFeature + 1;

       % Std time between groups
       if(~isempty(IEI))
           features(i, currFeature) = std(IEI(IEI>1))*experiment.fps;
       end
       currFeature = currFeature + 1;

      % Create consecutive groups above threshold
      out = SplitVec(aboveThreshold, 'consecutive');

      % Number of contiguous groups above threshold per unit time
      features(i,currFeature) = length(out)/(max(t)-min(t));
      currFeature = currFeature + 1;

      % For each contiguous group do the rest
      pertSize = zeros(length(out), 1);
      pertTime = zeros(length(out), 1);
      pertArea = zeros(length(out), 1);
      for k = 1:length(out)
        pertSize(k) = length(out{k});
        %pertTime(k) = mean(t(out{k}));
        pertTime(k) = mean((out{k}));
        if(length(out{k}) > 1)
          pertArea(k) = trapz(t(out{k}), data(out{k}));
        else
          pertArea(k) = data(out{k})/experiment.fps;
        end
      end
      % Mean of contiguous group length
      features(i, currFeature) = mean(pertSize)/experiment.fps;
      currFeature = currFeature + 1;

      % Std of contiguous group length
      features(i, currFeature) = std(pertSize)/experiment.fps;
      currFeature = currFeature + 1;

      % Mean Time between groups
      if(length(pertTime) > 1)
          IGI=diff(pertTime);
          features(i, currFeature) = mean(IGI(IGI>1))*experiment.fps;
      end
      currFeature = currFeature + 1;

      % Std time between groups
      if(length(pertTime) > 1)
          features(i, currFeature) = std(IGI(IGI>1))*experiment.fps;
      end
      currFeature = currFeature + 1;

      % Mean area per group
      features(i, currFeature) = mean(pertArea);
      currFeature = currFeature + 1;

      % Total area per unit time
      features(i, currFeature) = sum(pertArea)/(max(t)-min(t));
      currFeature = currFeature + 1;
    end
  end
  % Now some general features
  data = traces(:, i);
  sortedData = sort(data);
  features(i, currFeature) = mean(data); % 1st moment
  currFeature = currFeature + 1;
  
  features(i, currFeature) = std(data); % 2nd moment
  currFeature = currFeature + 1;
  
  features(i, currFeature) = skewness(data); % 3rd moment
  currFeature = currFeature + 1;
  
  features(i, currFeature) = mean(sortedData(1:ceil(length(sortedData)*0.05))); % mean lower quantile
  currFeature = currFeature + 1;
  
  features(i, currFeature) = mean(sortedData(ceil(length(sortedData)*0.95):end)); % mean upper quantile
  currFeature = currFeature + 1;
  
  if(params.pbar > 0)
    ncbar.update(i/size(traces, 2));
  end
end

% Now Z-norm all the features
if(params.zNorm)
  for i = 1:size(features,2)
    features(:, i) = (features(:, i)-nanmean(features(:, i)))/nanstd(features(:,i));
  end
end

% For compatibility
experiment.features = features;

experiment.traceFeatures = features;
experiment.traceFeaturesNames = featuresNames;

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
