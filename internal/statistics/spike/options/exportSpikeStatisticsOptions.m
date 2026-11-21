classdef exportSpikeStatisticsOptions < spikeStatisticsOptions & exportStatisticsOptions & baseOptions
% EXPORTSPIKESTATISTICSOPTIONS # Exports spike Statistics
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also exportSpikeStatistics, exportStatistics, baseOptions, optionsWindow

  methods 
    function obj = setExperimentDefaults(obj, experiment)
      obj = setExperimentDefaults@spikeStatisticsOptions(obj, experiment);
      obj = setExperimentDefaults@exportStatisticsOptions(obj, experiment);
    end
  end
end
