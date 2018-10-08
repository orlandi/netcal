classdef plotSpikesBurstStatisticsTreatmentOptions < plotStatisticsTreatmentOptions & baseOptions
% plotSpikesBurstStatisticsTreatmentOptions # Plot spikes burst statistics for treatments
% Plots statistics associated to fluorescence (global) bursts: amplitude, duration, IBI
%   It can show a single box for each experimetn and group, or merge them together into a joint statistic. Change the groupingOrder for that.
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also plotFluorescenceBurstStatistics, plotStatisticsTreatmentOptions, baseOptions, optionsWindow

  methods 
    function obj = setExperimentDefaults(obj, experiment)
      obj.statistic = {'IBI', 'bursting rate', 'duration', 'num spikes', 'num spikes per group member', 'ratio participating cells', 'num participating cells', 'all'};
      obj = setExperimentDefaults@plotStatisticsTreatmentOptions(obj, experiment);
    end
  end
end
