classdef exportSchmittSpikeStatisticsOptions < schmittSpikeStatisticsOptions & exportStatisticsOptions & baseOptions
% EXPORTSCHMITTSPIKESTATISTICSOPTIONS # Exports schmittSpike Statistics
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also exportSchmittSpikeStatistics, exportStatistics, baseOptions, optionsWindow

  methods 
    function obj = setExperimentDefaults(obj, experiment)
      obj = setExperimentDefaults@schmittSpikeStatisticsOptions(obj, experiment);
      obj = setExperimentDefaults@exportStatisticsOptions(obj, experiment);
    end
  end
end
