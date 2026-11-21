function data = computeSpikeStatistic(spikes, stat, burstMinSpikes, burstMaxTime, range)
% COMPUTESPIKESTATISTIC Computes a single spike statistic
%
% USAGE:
%    data = computeSpikeStatistic(RS, varargin)
%
% INPUT arguments:
%    spikes - cell containing the spike times of each member
%    stat - statistic to compute
%    range - only use spikes within this time range (in s) to compute the statistic
%
% OUTPUT arguments:
%    data - measured statistic for each member
%
% EXAMPLE:
%    data = computeSpikeStatistic(RS)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>

if(nargin < 5)
  range = [0 inf];
end
if(~isempty(range))
  validT = diff(range);
else
  validT = 0;
end

% Valid spikes are the actual used spike times
if(~isempty(spikes))
  validSpikes = cellfun(@(x)x(x >= range(1) & x <= range(2)), spikes,'UniformOutput', false);
else
  validSpikes = [];
end

switch stat
  case 'Number of Spikes'
    data = cellfun(@length, validSpikes);
  case 'Firing Rate (Hz)'
    data = cellfun(@length, validSpikes)/validT;
  case 'ISI average (s)'
    data = cellfun(@(x)mean(diff(x)), validSpikes);
  case 'ISI std (s)'
    data = cellfun(@(x)std(diff(x)), validSpikes);
    % Coefficient of Variation
  case 'ISI CV'
    data = cellfun(@(x)std(diff(x)), validSpikes)./cellfun(@(x)mean(diff(x)), validSpikes);
  % The following statistics need the definition of a burst. Done in the next function
  case 'Number of Spikes per Burst'
    data = getBurstStatistic(validSpikes, stat, burstMinSpikes, burstMaxTime, validT);
  case 'Number of Bursts'
    data = getBurstStatistic(validSpikes, stat, burstMinSpikes, burstMaxTime, validT);
  case 'Bursting Rate'
    data = getBurstStatistic(validSpikes, stat, burstMinSpikes, burstMaxTime, validT);
  case 'Intraburst ISI average'
    data = getBurstStatistic(validSpikes, stat, burstMinSpikes, burstMaxTime, validT);
  case 'IBI average'
    data = getBurstStatistic(validSpikes, stat, burstMinSpikes, burstMaxTime, validT);
  case 'Burst length (s)'
    data = getBurstStatistic(validSpikes, stat, burstMinSpikes, burstMaxTime, validT);
  case 'Number of Spikes in Bursts'
    data = getBurstStatistic(validSpikes, stat, burstMinSpikes, burstMaxTime, validT);
  case 'Fraction of Spikes in Bursts'
    data = getBurstStatistic(validSpikes, stat, burstMinSpikes, burstMaxTime, validT);
  case 'Global Firing Rate (Hz)'
    data = nansum(cellfun(@length, validSpikes)/validT);
  case 'Number of non-spiking cells'
    data = sum(cellfun(@(x)isempty(x)||all(isnan(x)), validSpikes));
  case 'Fraction of non-spiking cells '
    data = sum(cellfun(@(x)isempty(x)||all(isnan(x)), validSpikes))/length(validSpikes);
  otherwise
    data = getCases('eval');
end
if(~ischar(data) && ~iscell(data))
  data = double(data(:)); % Always as a column, just to be sure
end

  % New burst definition to avoid memory leaks for very large datasets
  function burstStatistic = getBurstStatistic(validSpikes, stat, minSpikes, maxTime, validT)
    burstStatistic = zeros(size(validSpikes));
    
    for it0 = 1:length(validSpikes)
      spikeList = validSpikes{it0};
      clusterdiff = diff(spikeList);
      insideCluster = false;
      bursts = nan(size(spikeList));
      currCluster = 0;
      for it = 1:length(clusterdiff)
        % Check if two spikes are within the maximum time
        if(clusterdiff(it) <= maxTime)
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
      burstSpikes = [];
      burstLengthS = [];
      % Here we iterate through the valid bursts
      for it = 1:length(uniqueBursts)
        valid = find(bursts == uniqueBursts(it));
        % If it's a burst
        if(length(valid) >= minSpikes)
          % validSpikes(valid) are the spike times for each burst
          Nbursts = Nbursts + 1;
          NspikesPerBurst = NspikesPerBurst + length(valid);
          avgISI = [avgISI; nanmean(diff(spikeList(valid)))];
          burstSpikes = [burstSpikes; [valid(:), ones(length(valid), 1)*it]];
          burstTime = [burstTime; mean(spikeList(valid))];
          burstLengthS = [burstLengthS; max(spikeList(valid))-min(spikeList(valid))];
        end
      end
      burstTime = sort(burstTime);

      switch stat
        case 'Number of Spikes per Burst'
          burstStatistic(it0) = NspikesPerBurst/Nbursts;
        case 'Number of Bursts'
          burstStatistic(it0) = Nbursts;
        case 'Bursting Rate'
          burstStatistic(it0) = Nbursts/validT;
        case 'Intraburst ISI average'
          burstStatistic(it0) = mean(avgISI);
        case 'IBI average'
          burstStatistic(it0) = mean(diff(burstTime));
        case 'Burst length (s)'
          burstStatistic(it0) = mean(burstLengthS);
        case 'Number of Spikes in Bursts'
          burstStatistic(it0) = NspikesPerBurst;
        case 'Fraction of Spikes in Bursts'
          burstStatistic(it0) =  NspikesPerBurst/length(spikeList);
      end
    end
  end
end