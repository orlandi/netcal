classdef exportFluorescenceBurstStatisticsOptions < fluorescenceBurstStatisticsOptions & exportStatisticsOptions & baseOptions
% EXPORTFLUORESCENCEBURSTSTATISTICSOPTIONS # Exports fluorescence-based burst Statistics
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also exportFluorescenceBurstStatistics, exportStatistics, baseOptions, optionsWindow

  methods 
    function obj = setExperimentDefaults(obj, experiment)
      obj = setExperimentDefaults@fluorescenceBurstStatisticsOptions(obj, experiment);
      obj = setExperimentDefaults@exportStatisticsOptions(obj, experiment);
    end
  end
end
