function projexp = plotFluorescenceBurstStatistics(projexp, varargin)
% PLOTFLUORESCENCEBURSTSTATISTICS # Plot fluorescence burst statistics
% Plots statistics associated to fluorescence (global) bursts: amplitude, duration, IBI
%
% USAGE:
%    projexp = plotFluorescenceBurstStatistics(projexp, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see plotFluorescenceBurstStatisticsOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = plotFluorescenceBurstStatistics(experiment)
%    project = plotFluorescenceBurstStatistics(project)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% PIPELINE
% name: plot burst statistics
% parentGroups: fluorescence: bursts: plots, statistics: fluorescence
% optionsClass: plotFluorescenceBurstStatisticsOptions
% requiredFields: traceBursts

obj = plotStatistics;
obj.init(projexp, plotFluorescenceBurstStatisticsOptions, 'Plotting burst statistics', varargin{:}, 'gui', gcbf);
if(obj.getData(@getData, projexp, obj.params.statistic))
  obj.createFigure();
end
obj.cleanup();

  %------------------------------------------------------------------------
  function data = getData(experiment, groupName, stat)
    bursts = getExperimentGroupBursts(experiment, groupName);
    if(~isempty(bursts))
      % Only a single burstRate
      if(strcmpi(stat, 'bursting rate'))
        data = length(bursts.amplitude)/experiment.totalTime;
      else
        data = bursts.(stat);
      end
      data = data(:); % Always as a column, just to be sure
    else
      data = [];
    end
  end

end