classdef exportAcuteKClStatisticsOptions < acuteKClStatisticsOptions & exportStatisticsOptions & baseOptions
% EXPORTACUTEKCLSTATISTICSOPTIONS # Exports acuteKCl Statistics
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also exportAcuteKClStatistics, exportStatistics, baseOptions, optionsWindow

  methods 
    function obj = setExperimentDefaults(obj, experiment)
      obj = setExperimentDefaults@acuteKClStatisticsOptions(obj, experiment);
      obj = setExperimentDefaults@exportStatisticsOptions(obj, experiment);
    end
  end
end
