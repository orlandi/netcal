classdef exportSpikeBurstStatisticsOptions < spikeBurstStatisticsOptions & exportStatisticsOptions & baseOptions
% EXPORTSPIKEBURSTSTATISTICSOPTIONS # Exports spikeBurst Statistics
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also exportSpikeBurstStatistics, exportStatistics, baseOptions, optionsWindow

  methods 
    function obj = setExperimentDefaults(obj, experiment)
      obj = setExperimentDefaults@spikeBurstStatisticsOptions(obj, experiment);
      obj = setExperimentDefaults@exportStatisticsOptions(obj, experiment);
    end
  end
end
