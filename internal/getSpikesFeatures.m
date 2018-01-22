function experiment = getSpikesFeatures(experiment, varargin)
% GETSPIKESFEATURES computes several features from spike trains
%
% USAGE:
%    experiment = getSpikesFeatures(experiment)
%
% INPUT arguments:
%    experiment - structure obtained from loadExperiment()
%
% INPUT optional arguments ('key' followed by its value):
%    see: spikeFeaturesOptions
%
% OUTPUT arguments:
%    experiment - structure obtained from loadExperiment()
%
% EXAMPLE:
%    experiment = getSpikesFeatures(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also spikeFeaturesOptions

% EXPERIMENT PIPELINE
% name: compute spike features
% parentGroups: spikes
% optionsClass: spikeFeaturesOptions
% requiredFields: spikes
% producedFields: spikeFeatures, spikeFeaturesNames

%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(spikeFeaturesOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];

% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Obtaining spike features');
%--------------------------------------------------------------------------

% Fix in case for some reason the group is a cell
if(iscell(params.group))
  mainGroup = params.group{1};
else
  mainGroup = params.group;
end

members = getAllMembers(experiment, mainGroup);

if(isempty(params.timeRange))
  params.timeRange = [-inf inf];
end
burstMaxTime = params.burstMaxTime;
minSpikes = params.minSpikes;

if(params.fBurstLengthFluorescence)
    experiment = loadTraces(experiment, 'normal');
end

Nfeatures = sum(params.fNumSpikes + params.fAverageISI + params.fStdISI + ...
                params.fBurstNum + params.fMeanBurstISI + params.fMeanIBI + ...
                params.fEntropy + params.fDisequilibrium + params.fComplexity + ...
                params.fFanoFactorISI + params.fCoefficientVariationISI + ...
                params.fBurstNumSpikes + params.fBurstLength + ...
                params.fBurstLengthFluorescence + params.fSchmittAmplitude + ...
                params.fNumSpikesInBursts + params.fNumSpikesInBurstsRatio + ...
                params.fSchmittArea + params.fSchmittDuration + params.fFiringRate + params.fBurstingRate);

% To not overwrite other groups
if(isfield(experiment, 'spikeFeatures'))
  features = experiment.spikeFeatures;
  if(size(features, 1) ~= length(experiment.spikes) || size(features, 2) ~= Nfeatures)
    logMsg('Found inconsitent feature length. Resetting...', 'w');
    features = nan(length(experiment.spikes), Nfeatures);
  else
    features(members, :) = nan;
  end
else
  features = nan(length(experiment.spikes), Nfeatures);  
end

featuresNames = cell(Nfeatures, 1);

currFeature = 1;
if(params.fNumSpikes)
    featuresNames{currFeature} = 'Num of spikes';
    currFeature = currFeature+1;
end
if(params.fFiringRate)
    featuresNames{currFeature} = 'Firing rate (Hz)';
    currFeature = currFeature + 1;
end
if(params.fAverageISI)
    featuresNames{currFeature} = 'Avg ISI (s)';
    currFeature = currFeature+1;
end
if(params.fStdISI)
    featuresNames{currFeature} = 'Std ISI (s)';
    currFeature = currFeature + 1;
end
if(params.fBurstNum)
    featuresNames{currFeature} = 'Num of bursts';
    currFeature = currFeature + 1;
end
if(params.fBurstingRate)
    featuresNames{currFeature} = 'Bursting rate (Hz)';
    currFeature = currFeature + 1;
end
if(params.fMeanBurstISI)
    featuresNames{currFeature} = 'Avg ISI inside bursts (s)';
    currFeature = currFeature + 1;
end
if(params.fMeanIBI)
  featuresNames{currFeature} = 'Avg IBI (s)';
  currFeature = currFeature + 1;
end
if(params.fEntropy)
  featuresNames{currFeature} = 'Shannon entropy (bits)';
  currFeature = currFeature + 1;
end
if(params.fDisequilibrium)
  featuresNames{currFeature} = 'Disequilibrium';
  currFeature = currFeature + 1;
end
if(params.fComplexity)
  featuresNames{currFeature} = 'Statistical Complexity';
  currFeature = currFeature + 1;
end
if(params.fFanoFactorISI)
  featuresNames{currFeature} = 'Fano Factor ISI';
  currFeature = currFeature + 1;
end
if(params.fCoefficientVariationISI)
  featuresNames{currFeature} = 'Coefficient of Variation ISI';
  currFeature = currFeature + 1;
end
if(params.fBurstNumSpikes)
  featuresNames{currFeature} = 'Avg Num spikes per burst';
  currFeature = currFeature + 1;
end
if(params.fBurstLength)
  featuresNames{currFeature} = 'Avg Burst length (s)';
  currFeature = currFeature + 1;
end
if(params.fBurstLengthFluorescence)
  featuresNames{currFeature} = 'Avg Burst length (s) (fluorescence)';
  currFeature = currFeature + 1;
end
if(params.fNumSpikesInBursts)
  featuresNames{currFeature} = 'Num Spikes in bursts';
  currFeature = currFeature + 1;
end
if(params.fNumSpikesInBurstsRatio)
  featuresNames{currFeature} = 'Ratio num Spikes in bursts';
  currFeature = currFeature + 1;
end
if(params.fSchmittAmplitude)
  featuresNames{currFeature} = 'Avg event amplitude (schmitt)';
  currFeature = currFeature + 1;
end
if(params.fSchmittArea)
  featuresNames{currFeature} = 'Avg event area (schmitt)';
  currFeature = currFeature + 1;
end
if(params.fSchmittDuration)
  featuresNames{currFeature} = 'Avg event duration (s) (schmitt)';
  currFeature = currFeature + 1;
end


if(isinf(diff(params.timeRange)))
	validT = experiment.t(end)-experiment.t(1);
else
  validT = diff(params.timeRange);
end
validFrames = round(validT*experiment.fps);

spikesBurstsTimes = cell(length(experiment.spikes), 1);
burstSpikes = cell(length(experiment.spikes), 1);
schmittWarning = false;
for ii = 1:length(members)
  i = members(ii); % Easy compatibility hack
  currFeature = 1;
  if(length(experiment.spikes{i}) < 2)
      continue;
  end
  % Valid spikes are the actual used spike times
  validSpikesIdx = find(experiment.spikes{i} > params.timeRange(1) & experiment.spikes{i} <= params.timeRange(2));
  validSpikesIdx = validSpikesIdx(:);
  validSpikes = experiment.spikes{i}(validSpikesIdx);
  validSpikes = validSpikes(:);
  Nspikes = length(validSpikes);
  if(length(validSpikes) < 2)
      continue;
  end
  % Number of spikes 1
  if(params.fNumSpikes)
      features(i, currFeature) = Nspikes;
      currFeature = currFeature + 1;
  end
  if(params.fFiringRate)
    features(i, currFeature) = Nspikes/validT;
    currFeature = currFeature + 1;
  end
  % Avg ISI 2
  if(params.fAverageISI)
      features(i, currFeature) = mean(diff(validSpikes));
      currFeature = currFeature + 1;
  end

  % Std ISI 3
  if(params.fStdISI)
      features(i, currFeature) = std(diff(validSpikes));
      currFeature = currFeature + 1;
  end

  % Getting the bursts
  %bursts = clusterdata(validSpikes', 'criterion', 'distance', 'cutoff', burstMaxTime);
  % New burst definition to avoid memory leaks for very large datasets
  clusterdiff = diff(validSpikes);
  insideCluster = false;
  bursts = nan(size(validSpikes));
  currCluster = 0;
  for it = 1:length(clusterdiff)
    % Check if two spikes are within the maximum time
    if(clusterdiff(it) <= burstMaxTime)
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
  Nbursts = 0;
  NspikesPerBurst = 0;
  avgISI = [];
  burstTime = [];
  burstLength = [];
  % Here we iterate through the valid bursts
  for it = 1:length(uniqueBursts)
    valid = find(bursts == uniqueBursts(it));
    % If it's a burst
    if(length(valid) >= minSpikes)
      % validSpikes(valid) are the spike times for each burst
      Nbursts = Nbursts + 1;
      NspikesPerBurst = NspikesPerBurst + length(valid);
      avgISI = [avgISI; nanmean(diff(validSpikes(valid)))];
      burstSpikes{i} = [burstSpikes{i}; [validSpikesIdx(valid), ones(size(valid))*it]];
      burstTime = [burstTime; mean(validSpikes(valid))];

      if(params.fBurstLengthFluorescence)
        firstSpike = min(validSpikes(valid));
        firstSpikeBin = floor(firstSpike*experiment.fps);
        lastSpike = max(validSpikes(valid));
        lastSpikeBin = floor(lastSpike*experiment.fps);
        if(firstSpikeBin <1 || firstSpikeBin > (length(experiment.t)-1) || lastSpikeBin < 1 || lastSpikeBin > (length(experiment.t)-1))
            continue;
        end
        %burstFvalues = experiment.traces(firstSpikeBin:lastSpikeBin, i);
        rangeStart = max([firstSpikeBin-5, 1]);
        rangeFinish = min([firstSpikeBin+5, size(experiment.traces,1)]);
        meanBurstF = median(experiment.traces(rangeStart:rangeFinish));
        dropFpos = find(experiment.traces((lastSpikeBin+1):end, i) < meanBurstF, 10, 'first');
        dropFpos = round(lastSpikeBin + median(dropFpos));
        if(isempty(dropFpos))
          continue;
        end
        burstLength = [burstLength; (dropFpos-firstSpikeBin)/experiment.fps];
        %[firstSpikeBin, dropFpos]
        %dropFpos
        spikesBurstsTimes{i} = [spikesBurstsTimes{i}; [firstSpikeBin, dropFpos]];
      end
    end
  end
  burstTime = sort(burstTime);
  % N spikes per burst
  NspikesPerBurst = NspikesPerBurst/Nbursts;
  if(~isempty(burstSpikes{i}))
    burstSpikes{i} = sortrows(burstSpikes{i}, 1);
  end

  % Number of bursts
  if(params.fBurstNum)
      features(i, currFeature) = Nbursts;
      currFeature = currFeature + 1;
  end
  
  % Bursting rate
  if(params.fBurstingRate)
    features(i, currFeature) = Nbursts/validT;
    currFeature = currFeature + 1;
  end
  
  % Mean ISI inside bursts 5
  if(params.fMeanBurstISI)
      features(i, currFeature) = nanmean(avgISI);
      currFeature = currFeature + 1;
  end

  % Mean IBI 6
  if(params.fMeanIBI)
    features(i, currFeature) = nanmean(diff(burstTime));
    currFeature = currFeature + 1;
  end

  % Shannon Entropy (-\sum plog2p)
  if(params.fEntropy)
    features(i, currFeature) = -Nspikes/validT*log2(Nspikes/validT) - (validT-Nspikes)/validT*log2(1-Nspikes/validT);
    currFeature = currFeature + 1;
  end
  
  % Jenson-Shannon divergence
  if(params.fDisequilibrium)
    p1 = Nspikes/validT;
    features(i, currFeature) = -0.5*(p1+0.5)*log2(0.5*(p1+0.5)) - 0.5*(1-p1+0.5)*log2(0.5*(1-p1+0.5)) -0.5*(-p1*log2(p1)-(1-p1)*log2(1-p1)+1);
    currFeature = currFeature + 1;
  end
  % Statistical complexity
  if(params.fComplexity)
    if(params.fEntropy && params.fDisequilibrium)
      features(i, currFeature) = features(i, currFeature-1).*features(i, currFeature-2);
    else
      p1 = Nspikes/validT;
      features(i, currFeature) = (-0.5*(p1+0.5)*log2(0.5*(p1+0.5)) - 0.5*(1-p1+0.5)*log2(0.5*(1-p1+0.5)) -0.5*(-p1*log2(p1)-(1-p1)*log2(1-p1)+1))*(-p1*log2(p1) - (1-p1)*log2(1-p1));
    end
    currFeature = currFeature + 1;
  end
  
  ISIlist = diff(validSpikes);
  % Fano Factor
  if(params.fFanoFactorISI)
    features(i, currFeature) = nanvar(ISIlist)/nanmean(ISIlist);
    currFeature = currFeature + 1;
  end
  
  % Coefficient of Variation
  if(params.fCoefficientVariationISI)
    features(i, currFeature) = nanstd(ISIlist)/nanmean(ISIlist);
    currFeature = currFeature + 1;
  end

  % Number of spikes per burst 7
  if(params.fBurstNumSpikes)
    features(i, currFeature) = NspikesPerBurst;
    currFeature = currFeature + 1;
  end
  
  
  % Burst length 8
  burstLengthS = [];
  for j = unique(bursts)'
      valid = find(bursts == j);
      if(length(valid) > 1)
          burstLengthS = [burstLengthS; max(validSpikes(valid))-min(validSpikes(valid))];
      end
  end
  if(params.fBurstLength)
      features(i, currFeature) = nanmean(burstLengthS);
      currFeature = currFeature + 1;
  end

  % Burst length fluorescence 9
  if(params.fBurstLengthFluorescence)
    if(~isempty(spikesBurstsTimes{i}))
      spikesBurstsTimes{i} = sortrows(spikesBurstsTimes{i}, 1);
      % Now remove any possible burst overlaps
      for j = 1:size(spikesBurstsTimes{i},1)-1
        if(spikesBurstsTimes{i}(j, 2) >= spikesBurstsTimes{i}(j+1, 1))
          spikesBurstsTimes{i}(j, 2) = spikesBurstsTimes{i}(j+1, 1)-1;
          % Consistency check
          if(spikesBurstsTimes{i}(j, 2) < spikesBurstsTimes{i}(j, 1))
            spikesBurstsTimes{i}(j, 2) = spikesBurstsTimes{i}(j, 1);
          end
        end
      end
    end
    features(i, currFeature) = nanmean(burstLength);
    currFeature = currFeature + 1;
  end
  if(params.fNumSpikesInBursts)
    features(i, currFeature) = NspikesPerBurst*Nbursts;
    currFeature = currFeature + 1;
  end
  
  if(params.fNumSpikesInBurstsRatio)
    features(i, currFeature) = NspikesPerBurst*Nbursts/length(validSpikes);
    currFeature = currFeature + 1;
  end
  % Following features depend on the Schmitt trigger options, skip if not found
  if(~isfield(experiment, 'schmittSpikesData') || ~isstruct(experiment.schmittSpikesData{i}))
    schmittWarning = true;
  else
    if(params.fSchmittAmplitude)
      features(i, currFeature) = nanmean(experiment.schmittSpikesData{i}.amplitude);
      currFeature = currFeature + 1;
    end
    if(params.fSchmittArea)
      features(i, currFeature) = nanmean(experiment.schmittSpikesData{i}.area);
      currFeature = currFeature + 1;
    end
    if(params.fSchmittDuration)
      features(i, currFeature) = nanmean(experiment.schmittSpikesData{i}.duration);
      currFeature = currFeature + 1;
    end
  end
  if(params.pbar > 0)
    ncbar.update(i/length(experiment.spikes));  
  end
end

if(schmittWarning && (params.fSchmittAmplitude || params.fSchmittArea || params.fSchmittDuration))
  logMsg('Schmitt inference data not found on some (or all) ROI', 'w');
end

experiment.spikeFeatures = features;
experiment.spikeFeaturesNames = featuresNames;
if(params.fBurstLengthFluorescence)
  experiment.spikesBurstsTimes = spikesBurstsTimes;
end
experiment.burstSpikes = burstSpikes;

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
