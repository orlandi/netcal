classdef plotAcuteKClStatisticsOptions < acuteKClStatisticsOptions & plotStatisticsOptions & baseOptions
% PLOTACUTEKCLSTATISTICSOPTIONS # Plot acuteKCl Statistics
%   It can show single experiment distributions, aggregated experiments boxplots, etc
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also plotAcuteKClStatistics, acuteKClStatisticsOptions, plotBaseOptions, baseOptions, optionsWindow

  properties
  end
  methods 
    function obj = setExperimentDefaults(obj, experiment)
      obj = setExperimentDefaults@acuteKClStatisticsOptions(obj, experiment);
      obj = setExperimentDefaults@plotStatisticsOptions(obj, experiment);
    end
  end
end
