classdef plotKClStatisticsOptions < plotStatisticsOptions & baseOptions
% PLOTKCLSTATISTICSOPTIONS # Plot KCl Statistics
%   Produces a boxplot for a given KCl statistic
%   It can show a single box for each experiment and group, or merge them together into a joint statistic. Change the groupingOrder for that.
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also plotKClStatistics, plotBaseOptions, baseOptions, optionsWindow

  methods 
    function obj = setExperimentDefaults(obj, experiment)
      %labels = {'baseLine', 'reactionTime', 'maxResponse', 'maxResponseTime', 'decay', 'decayTime', 'responseDuration', 'recoveryTime', 'recovered', 'endValue', 'lastResponseValue'};
      obj.statistic = {'baseLine', 'reactionTime', 'maxResponse', 'maxResponseTime', ...
                       'responseFitSegments', 'responseFitFirstSegmentDuration', ...
                       'responseFitSegmentsMaxFluorescenceIncrease', 'responseFitSegmentsMaxSlope', ...
                       'responseFitFirstSegmentFluorescenceIncrease', 'responseFitFirstSegmentSlope', ...
                       'decay', 'decayTime', 'responseDuration', 'recoveryTime', 'recovered', ...
                       'protocolEndValue', 'lastResponseValue', 'ask'};
      obj = setExperimentDefaults@plotStatisticsOptions(obj, experiment);
    end
  end
end
