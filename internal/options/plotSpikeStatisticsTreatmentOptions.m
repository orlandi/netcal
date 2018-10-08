classdef plotSpikeStatisticsTreatmentOptions < plotStatisticsTreatmentOptions & baseOptions
% PLOTSPIKESTATISTICSTREATMENTOPTIONS # Plot Spike Statistics for treatments
%   Produces a boxplot for a given spike statistic, e.g., ISI, IBI, ...
%   It can show a single box for each experimetn and group, or merge them together into a joint statistic. Change the groupingOrder for that.
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also plotSpikeStatisticsTreatment, plotBaseOptions, baseOptions, optionsWindow

  methods 
    function obj = setExperimentDefaults(obj, experiment)
      if(~isempty(experiment) && isstruct(experiment))
        try
          obj.statistic = experiment.spikeFeaturesNames;
        catch ME
          logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
        end
      elseif(~isempty(experiment) && exist(experiment, 'file'))
        exp = load(experiment, '-mat', 'spikeFeaturesNames');
        if(isfield(exp, 'spikeFeaturesNames'))
          obj.statistic = exp.spikeFeaturesNames(:)';
          obj.statistic{end+1} = '';
        else
          obj.statistic = '';
        end
      end
      obj = setExperimentDefaults@plotStatisticsTreatmentOptions(obj, experiment);
    end
  end
end
