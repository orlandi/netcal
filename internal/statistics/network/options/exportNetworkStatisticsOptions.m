classdef exportNetworkStatisticsOptions < networkStatisticsOptions & exportStatisticsOptions & baseOptions
% EXPORTNETWORKSTATISTICSOPTIONS # Exports network Statistics
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also exportNetworkStatistics, exportStatistics, baseOptions, optionsWindow

  methods 
    function obj = setExperimentDefaults(obj, experiment)
      obj = setExperimentDefaults@networkStatisticsOptions(obj, experiment);
      obj = setExperimentDefaults@exportStatisticsOptions(obj, experiment);
    end
  end
end
