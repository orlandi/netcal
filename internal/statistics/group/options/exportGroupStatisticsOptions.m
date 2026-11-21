classdef exportGroupStatisticsOptions < groupStatisticsOptions & exportStatisticsOptions & baseOptions
% EXPORTGROUPSTATISTICSOPTIONS # Exports group Statistics
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also exportGroupStatistics, exportStatistics, baseOptions, optionsWindow

  methods 
    function obj = setExperimentDefaults(obj, experiment)
      obj = setExperimentDefaults@groupStatisticsOptions(obj, experiment);
      obj = setExperimentDefaults@exportStatisticsOptions(obj, experiment);
    end
  end
end
