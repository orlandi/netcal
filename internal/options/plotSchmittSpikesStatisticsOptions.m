classdef plotSchmittSpikesStatisticsOptions < plotStatisticsOptions & baseOptions
% PLOTSCHMITTSPIKESSTATISTICSOPTIONS # Plot schmitt-inference additional spike statistics
% Plots statistics associated to schmitt inference
%   It can show a single box for each experimetn and group, or merge them together into a joint statistic. Change the groupingOrder for that.
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also plotSchmittSpikesStatistics, plotStatisticsOptions, baseOptions, optionsWindow
  
  methods 
    function obj = setExperimentDefaults(obj, experiment)
      obj.statistic = {'duration', 'amplitude', 'area', ...
                       'all'};
      obj = setExperimentDefaults@plotStatisticsOptions(obj, experiment);
    end
  end
end
