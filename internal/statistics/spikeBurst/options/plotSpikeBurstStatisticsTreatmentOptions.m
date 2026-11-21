classdef plotSpikeBurstStatisticsTreatmentOptions < spikeBurstStatisticsOptions & plotStatisticsTreatmentOptions & baseOptions
% PLOTSPIKEBURSTSTATISTICSTREATMENTOPTIONS # Plot spikeBurst Statistics for treatments
%   It can show single experiment distributions, aggregated experiments boxplots, etc
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also plotSpikeBurstStatisticsTreatment, spikeBurstStatisticsOptions, plotBaseOptions, baseOptions, optionsWindow

  properties
  end
  methods 
    function obj = setExperimentDefaults(obj, experiment)
      obj = setExperimentDefaults@spikeBurstStatisticsOptions(obj, experiment);
      obj = setExperimentDefaults@plotStatisticsTreatmentOptions(obj, experiment);
    end
  end
end
