function projexp = plotSpikesBurstStatistics(projexp, varargin)
% plotSpikesBurstStatistics # Plot spikes burst statistics
% Plots statistics associated to spikes (global) bursts: amplitude, duration, IBI
%
% USAGE:
%    projexp = plotSpikesBurstStatistics(projexp, varargin)
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
%    experiment = plotSpikesBurstStatistics(experiment)
%    project = plotSpikesBurstStatistics(project)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% PIPELINE
% name: plot burst statistics
% parentGroups: spikes: bursts: plots
% optionsClass: plotSpikesBurstStatisticsOptions
% requiredFields: traceBursts

obj = plotStatistics;
obj.init(projexp, plotSpikesBurstStatisticsOptions, 'Plotting burst statistics', varargin{:}, 'gui', gcbf);
if(obj.getData(@getData, projexp, obj.params.statistic))
  obj.createFigure();
end
obj.cleanup();

  %------------------------------------------------------------------------
  function data = getData(experiment, groupName, stat)
    bursts = getExperimentGroupBursts(experiment, groupName, 'spikes');
    if(~isempty(bursts))
      % Only a single burstRate
      if(strcmpi(stat, 'bursting rate'))
        data = length(bursts.amplitude)/experiment.totalTime;
      elseif(strcmpi(stat, 'num spikes'))
        data = bursts.amplitude;
      elseif(strcmpi(stat, 'num spikes per group member'))
        [members, ~, ~] = getExperimentGroupMembers(experiment, groupName);
        data = bursts.amplitude/length(members);
      else
        data = bursts.(stat);
      end
      data = data(:); % Always as a column, just to be sure
    else
      data = [];
    end
  end

end