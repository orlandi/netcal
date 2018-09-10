function [field, idx] = getExperimentGroupCoordinates(experiment, name)
% GETEXPERIMENTGROUPCOORDINATES Returns the coordinates of a given group
% (within the structure)
%
% USAGE:
%    [field idx] = getExperimentGroupCoordinates(experiment, name)
%
% INPUT arguments:
%    experiment - structure
%
%    name - group name (as returned by getExperimentGroupsNames)
%
% OUTPUT arguments:
%    field - field name
%
%    idx - numeric idx
%
% EXAMPLE:
%     [field, idx] = getExperimentGroupCoordinates(experiment, 'everything')
%     members = experiment.traceGroups.(field){idx}
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

field = [];
idx = [];
nameComponents = strsplit(name, ':');
% Hack in case the user defined name has the delimiter
if(length(nameComponents) > 2)
  nameComponents = {nameComponents{1} strjoin(nameComponents(2:end))};
end
if(isfield(experiment, 'traceGroups') && ~isempty(experiment.traceGroups) && isfield(experiment, 'traceGroupsNames') && isfield(experiment.traceGroupsNames, nameComponents{1}))
  if(length(nameComponents) == 1 && (strcmp(nameComponents, 'everything') || strcmp(nameComponents, 'all')))
    field = nameComponents{1};
    idx = 1;
  elseif(length(nameComponents) == 1)
    field = nameComponents{1};
    idx = 0;
  else
    groupNames = experiment.traceGroupsNames.(nameComponents{1});
    validCategory = find(strcmpi(groupNames, strtrim(nameComponents{2})));
    field = nameComponents{1};
    idx = validCategory;
  end
end