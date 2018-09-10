function projexp = plotPopulationsStatisticsTreatment(projexp, varargin)
% PLOTPOPULATIONSSTATISTICSTREATMENT plots population statistics for treatments
%
% USAGE:
%    experiment = plotPopulationsStatisticsTreatment(experiment, varargin)
%    project = plotPopulationsStatisticsTreatment(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see plotPopulationsStatisticsTreatmentOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = plotPopulationsStatisticsTreatment(experiment)
%    project = plotPopulationsStatisticsTreatment(project)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% PIPELINE
% name: plot populations statistics for treatments
% parentGroups: populations: plots, treatments, statistics: populations
% optionsClass: plotPopulationsStatisticsTreatmentOptions
% requiredFields: spikes

obj = plotStatisticsTreatment;
obj.init(projexp, plotPopulationsStatisticsTreatmentOptions, 'Plotting population statistics for treatments', varargin{:}, 'gui', gcbf);
if(obj.getData(@getData, projexp, obj.params.statistic))
  obj.createFigure();
end
obj.cleanup();

  %------------------------------------------------------------------------
  function data = getData(experiment, groupName, stat)
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
