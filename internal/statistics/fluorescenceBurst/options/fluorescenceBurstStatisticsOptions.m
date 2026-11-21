classdef fluorescenceBurstStatisticsOptions < baseOptions
% FLUORESCENCEBURSTSTATISTICSOPTIONS # Options for computing statistics related to fluorescence-based bursts
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also baseOptions, optionsWindow

  properties
    % fluorescence-based bursts statistic to compute:
    % - Bursting rate: Number of bursts per unit time
    % - IBI: InterBurst Interval (in s)
    % - Duration: Burst duration (in s)
    % - Amplitude: Burst amplitude (in Fluorescence units)
    statistic = {'Main statistic'}; % The real list is pulled on setExperimentDefaults
    
    % Additional options should go here
  end
  
  properties (Constant = true, Hidden = true)
    % Required fields should go here
    loadFields = {'traceBursts'};
  end
  
  methods
    function fullData = getData(obj, experiment, groupName, stat) %#ok<INUSL>
      % Add required preprocessing
      if(~iscell(stat))
        stat = {stat};
      end
      fullData = cell(size(stat));
      %members = getExperimentGroupMembers(experiment, groupName);
      bursts = getExperimentGroupBursts(experiment, groupName);
      % The definition of range for rates
      try 
        totalTime = experiment.t(end)-experiment.t(1);
      catch
        totalTime = experiment.totalTime;
      end
      for it_stat = 1:length(stat)
        %%% NEEDS CHANGING
        data = computeFluorescenceBurstStatistic(bursts, stat{it_stat}, totalTime);
        fullData{it_stat} = data;
      end
      if(length(fullData) == 1)
        fullData = fullData{1};
      end
    end
    
    function data = computeFluorescenceBurstStatistic(bursts, stat, totalTime)
      switch stat
        case 'Bursting rate (Hz)'
          data = length(bursts.amplitude)/totalTime;
        case 'IBI (s)'
          data = bursts.IBI;
        case 'Duration (s)'
          data = bursts.duration;
        case 'Amplitude (a.u.)'
          data = bursts.amplitude;
        otherwise
          data = getCases('eval');
      end
      if(~ischar(data) && ~iscell(data))
        data = double(data(:)); % Always as a column, just to be sure
      end
    end
    
    function obj = setExperimentDefaults(obj, experiment) %#ok<INUSD>
      obj.statistic = computeFluorescenceBurstStatistic([], 'list');
    end
  end
end
