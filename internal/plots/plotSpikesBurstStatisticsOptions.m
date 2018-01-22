classdef plotSpikesBurstStatisticsOptions < plotStatisticsOptions & baseOptions
% plotSpikesBurstStatisticsOptions # Plot fluorescence burst statistics
% Plots statistics associated to fluorescence (global) bursts: amplitude, duration, IBI
%   It can show a single box for each experimetn and group, or merge them together into a joint statistic. Change the groupingOrder for that.
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also plotSpikesBurstStatisticsOptions, plotStatisticsOptions, baseOptions, optionsWindow

  methods 
    function obj = setExperimentDefaults(obj, experiment)
      obj.statistic = {'IBI', 'bursting rate', 'duration', 'amplitude'};
      obj = setExperimentDefaults@plotStatisticsOptions(obj, experiment);
    end
  end
end
