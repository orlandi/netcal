function projexp = plotSpikeStatistics(projexp, varargin)
% PLOTSPIKESTATISTICS plots spike statistics
%
% USAGE:
%    experiment = plotSpikeStatistics(experiment, varargin)
%    project = plotSpikeStatistics(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see plotQCECOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = plotQCEC(experiment)
%    project = plotQCEC(project)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% PIPELINE
% name: plot spike statistics
% parentGroups: spikes: plots
% optionsClass: plotSpikeStatisticsOptions
% requiredFields: spikes

obj = plotStatistics;
obj.init(projexp, plotSpikeStatisticsOptions, 'Plotting spike statistics', varargin{:}, 'gui', gcbf);
if(obj.getData(@getData, projexp, obj.params.statistic))
  obj.createFigure();
end
obj.cleanup();

  %------------------------------------------------------------------------
  function data = getData(experiment, groupName, stat)
    members = getExperimentGroupMembers(experiment, groupName);
    if(~isempty(members))
      selectedStatistic = strcmp(experiment.spikeFeaturesNames, stat);
      data = experiment.spikeFeatures(members, selectedStatistic);
      data = data(:); % Always as a column, just to be sure
    else
      data = [];
    end
  end

end