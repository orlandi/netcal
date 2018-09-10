function [selectedPopulations, aggregatedOptionsCurrent, success] = selectExperimentGroups(experiment, populationSelectionType)
% SELECTEXPERIMENTGROUPS PENDING
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
  if(nargin < 2)
    populationSelectionType = 'single';
  end

  [~, aggregatedOptionsCurrent] = preloadOptions([], aggregatedOptions, gcbf, false, false);
  groupNames = getExperimentGroupsNames(experiment);

  % Select the population
  [selectedPopulations, success] = listdlg('PromptString', 'Select groups', 'SelectionMode', populationSelectionType, 'ListString', groupNames);
  if(~success)
      return;
  end
  selectedPopulations = groupNames(selectedPopulations);
end