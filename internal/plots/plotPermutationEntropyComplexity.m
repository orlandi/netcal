function projexp = plotPermutationEntropyComplexity(projexp, varargin)
% PLOTPERMUTATIONENTROPYCOMPLEXITY Plot permutation complexity/entropy
% Plots the permutation entropy or the permnutation complexity. See;
% [http://dx.doi.org/10.1103/PhysRevE.95.062106](http://dx.doi.org/10.1103/PhysRevE.95.062106)
%
% USAGE:
%    experiment = plotPermutationEntropyComplexity(experiment, varargin)
%    project = plotPermutationEntropyComplexity(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see plotPermutationEntropyComplexityOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = plotPermutationEntropyComplexity(experiment)
%    project = plotPermutationEntropyComplexity(project)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% PIPELINE
% name: plot permutation entropy/complexity
% parentGroups: fluorescence: basic: plots
% optionsClass: plotPermutationEntropyComplexityOptions
% requiredFields: qCEC

obj = plotStatistics;
obj.init(projexp, plotPermutationEntropyComplexityOptions, 'Plotting permutation entropy/complexity statistics', varargin{:}, 'gui', gcbf);
if(obj.getData(@getData, projexp, obj.params.statistic, obj.params.qValue))
  obj.createFigure();
end

obj.cleanup();

  %------------------------------------------------------------------------
  function data = getData(experiment, groupName, stat, qValue)
    members = getExperimentGroupMembers(experiment, groupName);
    if(~isempty(members))
      [~, qValueIdx] = min(abs(experiment.qCEC.qList-qValue));
      switch stat
        case 'complexity'
          data = experiment.qCEC.C(members, qValueIdx);
        case 'entropy'
          data = experiment.qCEC.H(members, qValueIdx);
      end
    else
      data = [];
    end
  end

end