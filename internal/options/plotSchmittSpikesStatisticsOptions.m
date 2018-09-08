classdef plotSchmittSpikesStatisticsOptions < plotStatisticsOptions & baseOptions
% PLOTSCHMITTSPIKESSTATISTICSOPTIONS # Plot schmitt-inference additional spike statistics
% Plots statistics associated to schmitt inference
%   It can show a single box for each experimetn and group, or merge them together into a joint statistic. Change the groupingOrder for that.
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also plotSchmittSpikesStatistics, plotStatisticsOptions, baseOptions, optionsWindow
   
  properties
    % Type of events to use (leave empty if you don't know what this is)
    type = [];
  end
  methods 
    function obj = setExperimentDefaults(obj, experiment)
      obj.statistic = {'duration', 'amplitude', 'area', ...
                       'all'};
      obj = setExperimentDefaults@plotStatisticsOptions(obj, experiment);
    end
  end
end
