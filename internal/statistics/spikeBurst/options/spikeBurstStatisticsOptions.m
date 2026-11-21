classdef spikeBurstStatisticsOptions < baseOptions
% SPIKEBURSTSTATISTICSOPTIONS # Options for computing statistics related to spikeBurst
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also baseOptions, optionsWindow

  properties
    % spikeBurst statistic to compute:
    % - bursting rate: Number of bursts per unit time (in Hz)
    % - bursting rate high: Bursting rate for bursts with a high participating fraction (see fraction below)
    % - bursting rate high: Bursting rate for bursts with a low participating fraction (see fraction below)
    % - IBI: InterBurst Interval
    % - duration: Burst duration
    % - IBI CV: Coefficient of Variaton of the IBI
    % - num spikes: number of spikes per burst
    % - num participating cells: number of cells that participate in a burst
    % - ratio participaing cells: fraction of cells that participate in a burst
    % - num spikes per group member: average number of spikes per burst and cell
    % - burstiness: 1 if there are bursts, 0 otherwise
    statistic = {'Main statistic'}; % The real list is pulled on setExperimentDefaults
    
    % Additional options should go here
    % Fraction of participating group members in a burst used to separate between high and low bursts
    fraction = 0.2;
  end
  
  properties (Constant = true, Hidden = true)
    % Required fields should go here
    loadFields = {'spikeBursts','t','totalTime', 'spikes'};
  end
  
  methods
    function fullData = getData(obj, experiment, groupName, stat) %#ok<INUSL>
      % Add required preprocessing
      if(~iscell(stat))
        stat = {stat};
      end
      fullData = cell(size(stat));
      members = getExperimentGroupMembers(experiment, groupName);
      % The definition of range for rates
      try 
        totalTime = experiment.t(end)-experiment.t(1);
      catch
        totalTime = experiment.totalTime;
      end
      bursts = getExperimentGroupBursts(experiment, groupName, 'spikes');
      for it_stat = 1:length(stat)
        data = obj.computeSpikeBurstStatistic(bursts, stat{it_stat}, members, experiment.spikes, totalTime, obj.fraction);
        fullData{it_stat} = data;
      end
      if(length(fullData) == 1)
        fullData = fullData{1};
      end
    end
    
    function data = computeSpikeBurstStatistic(obj, bursts, stat, members, spikes, totalTime, frac)
      if(~isempty(bursts) || strcmpi(stat, 'list'))
        switch stat
          case 'bursting rate'
            data = length(bursts.amplitude)/totalTime;
          case 'bursting rate high'
            data = cellfun(@length, bursts.participators)/length(members);
            valid = find(data >= frac);
            data = length(valid)/totalTime;
            if(isempty(data))
              data = 0;
            end
          case 'bursting rate low'
            data = cellfun(@length, bursts.participators)/length(members);
            valid = find(data < frac);
            data = length(valid)/totalTime;
            if(isempty(data))
              data = 0;
            end
          case 'IBI'
            data = bursts.IBI;
          case 'IBI2'
            data = diff(bursts.start);
          case 'duration'
            data = bursts.duration;
          case 'IBI CV'
            data = nanstd(bursts.IBI)/nanmean(bursts.IBI);
          case 'IBI2 CV'
            data = nanstd(diff(bursts.start))/nanmean(diff(bursts.start));
          case 'num spikes'
            data = bursts.amplitude;
          case 'num participating cells'
            data = cellfun(@length, bursts.participators);
          case 'ratio participating cells'
            data = cellfun(@length, bursts.participators)/length(members);
            %data = bursts.participators/length(members);
          case 'ratio participating spiking cells'
            validN = sum(cellfun(@(x)numel(x)>1, spikes(members)));
            data = cellfun(@length, bursts.participators)/validN;
            %data = bursts.participators/length(members);
          case 'num spikes per group member'
            data = bursts.amplitude/length(members);
          case 'num spikes per spiking cell'
            validN = sum(~cellfun(@isempty, spikes(members)));
            data = bursts.amplitude/validN;
          case 'num spikes per participator'
            data = bursts.amplitude./cellfun(@length, bursts.participators);
          case 'burstiness'
            %if(~isempty(bursts.amplitude) && length(bursts.amplitude) > 1)
            if(~isempty(bursts.IBI) && nanmean(bursts.IBI) < 45)
              data = 1;
            else
              data = 0;
            end
          otherwise
            data = getCases('eval');
        end
      else
        % Allow burstiness measure even if there are no bursts
        if(strcmpi(stat, 'burstiness'))
          data = 0;
        end
      end
      if(~ischar(data) && ~iscell(data))
        data = double(data(:)); % Always as a column, just to be sure
      end
    end
    
    function obj = setExperimentDefaults(obj, experiment) %#ok<INUSD>
      obj.statistic = obj.computeSpikeBurstStatistic([], 'list');
    end
  end
end
