function projexp = plotSpikesBurstStatisticsTreatment(projexp, varargin)
% PLOTSPIKESBURSTSTATISTICSTREATMENT Plot spikes burst statistics
% Plots statistics associated to spikes
%
% USAGE:
%    projexp = plotFluorescenceBurstStatisticsTreatment(projexp, varargin)
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
%    experiment = plotFluorescenceBurstStatisticsTreatment(experiment)
%    project = plotFluorescenceBurstStatisticsTreatment(project)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% PIPELINE
% name: plot spikes burst statistics for treatments
% parentGroups: spikes: bursts: plots, treatments, statistics: spikes
% optionsClass: plotSpikesBurstStatisticsTreatmentOptions
% requiredFields: spikes, spikeBursts

obj = plotStatisticsTreatment;
obj.init(projexp, plotSpikesBurstStatisticsTreatmentOptions, 'Plotting spike burst statistics for treatments', varargin{:}, 'gui', gcbf);
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
      elseif(strcmpi(stat, 'num participating cells'))
        data = cellfun(@length, bursts.participators);
      elseif(strcmpi(stat, 'ratio participating cells'))
        [members, ~, ~] = getExperimentGroupMembers(experiment, groupName);
        data = cellfun(@length, bursts.participators)/length(members);
        %data = bursts.participators/length(members);
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