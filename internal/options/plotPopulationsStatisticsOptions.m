classdef plotPopulationsStatisticsOptions < plotStatisticsOptions & baseOptions
% PLOTSPIKESTATISTICSOPTIONS # Plot Population Statistics
%   Produces a boxplot for a given population statistic
%   It can show a single box for each experimetn and group, or merge them together into a joint statistic. Change the groupingOrder for that.
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also plotPopulationsStatistics, plotBaseOptions, baseOptions, optionsWindow

  properties
    
  end
  methods 
    function obj = setExperimentDefaults(obj, experiment)
      obj.statistic = {'absolute count', 'relative count'};
      obj = setExperimentDefaults@plotStatisticsOptions(obj, experiment);
    end
     function obj = setProjectDefaults(obj, project)
      obj = setProjectDefaults@plotStatisticsOptions(obj, project);
    end
  end
end
