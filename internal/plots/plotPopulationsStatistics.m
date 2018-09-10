function projexp = plotPopulationsStatistics(projexp, varargin)
% PLOTPOPULATIONSSTATISTICS plots population statistics
%
% USAGE:
%    experiment = plotPopulationsStatistics(experiment, varargin)
%    project = plotPopulationsStatistics(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see plotPopulationsStatisticsOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = plotPopulationsStatistics(experiment)
%    project = plotPopulationsStatistics(project)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% PIPELINE
% name: plot populations statistics
% parentGroups: populations: plots, statistics: populations
% optionsClass: plotPopulationsStatisticsOptions
% requiredFields: spikes

obj = plotStatistics;
obj.init(projexp, plotPopulationsStatisticsOptions, 'Plotting population statistics', varargin{:}, 'gui', gcbf, 'loadFields', {'ROI'});
if(obj.getData(@getData, projexp, obj.params.statistic))
  obj.createFigure();
end
obj.cleanup();

  %------------------------------------------------------------------------
  function data = getData(experiment, groupName, stat)
    data = [];
    members = getExperimentGroupMembers(experiment, groupName);
    if(~isempty(members))
      switch stat
        case 'absolute count'
          data = length(members);
        case 'relative count'
          data = length(members)/length(experiment.ROI);
      end
    else
      data = [];
    end
  end
end
