classdef spikeStatisticsOptions < baseOptions
% SPIKESTATISTICSOPTIONS # Options for computing statistics related to spike counts
%
%   Copyright (C) 2016-2026, Javier G. Orlandi <javier.orlandi@ucalgary.ca>
%
%   See also baseOptions, optionsWindow

  properties
    % Spike statistic to compute (all within the defined time range (see range below):
    % - Number of Spikes: total count of spikes found for each cell
    % - Firing Rate (Hz): number of spikes per unit time (number of spikes divide by temporal range length)
    % - ISI average (s): average InterSpike Interval
    % - ISI std (s): standard deviation of the InterSpike Interval
    % - ISI CV: Coefficient of Variation of the InterSpike Interval
    % - Number of Spikes per Burst: average number of spikes found inside each single-cell burst
    % - Number of Bursts: total number of bursts found
    % - Bursting Rate: number of bursts per unit time 
    % - Intraburst ISI average:  average InterSpike Interval within a burst (first does the ISI average for each burst, and then averages between all bursts)
    % - IBI average: average InterBurst Interval (single-cell)
    % - Burst length (s): average burst length
    % - Number of Spikes in Bursts: total number of spikes found in bursts
    % - Fraction of Spikes in Bursts: from all the spikes, the fraction that happens inside single-cell bursts
    % - Global Firing Rate (Hz): total firing rate in the group (the sum across all group member)
    % - Number of non-spiking cells: number of cells in the group with 0 spikes
    % - Fraction of non-spiking cells: fraction of cells in the group with 0 spikes
    %statistic = {'statistic 1', 'statistic 2'}; % The real list is pulled on setExperimentDefaults
    statistic = computeSpikeStatistic([], 'list')';
    
    % Minimum number of consecutive spikes to define a single cell burst
    burstMinSpikes = 2;
    
    % Maximum separation (in s) between consecutive spikes to define a single cell burst
    burstMaxTime = 1;
    
    % Temporal range (in s) to use to compute the statistic
    range = [0 inf];
  end
  
  properties (Constant = true, Hidden = true)
    loadFields = {'spikes', 't', 'rawT', 'totalTime'};
  end
  
  methods
    function fullData = getData(obj, experiment, groupName, stat)
      curRange = obj.range;
      if(isempty(curRange))
        curRange = [0 experiment.totalTime];
      end
      if(curRange(1) == 0 && isinf(curRange(2)))
        curRange = [0 experiment.totalTime];
      end
      if(~iscell(stat))
        stat = {stat};
      end
      fullData = cell(size(stat));
      members = getExperimentGroupMembers(experiment, groupName);
      for it_stat = 1:length(stat)
        data = computeSpikeStatistic(experiment.spikes(members), stat{it_stat}, obj.burstMinSpikes, obj.burstMaxTime, curRange);
        fullData{it_stat} = data;
      end
      if(length(fullData) == 1)
        fullData = fullData{1};
      end
    end
    function obj = setExperimentDefaults(obj, experiment)
      obj.statistic = computeSpikeStatistic([], 'list');
      
      if(~isempty(experiment) && isstruct(experiment))
        try
          obj.range = [0 experiment.totalTime];
        catch ME
          logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e'); %#ok<SPRINTFN>
        end
      elseif(~isempty(experiment) && exist(experiment, 'file'))
        exp = load(experiment, '-mat', 'totalTime');
        if(isfield(exp, 'totalTime'))
          obj.range = [0 exp.totalTime];
        end
      end
    end
  end
end
