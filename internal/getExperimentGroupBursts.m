function bursts = getExperimentGroupBursts(experiment, name)
% GETEXPERIMENTGROUPBURSTS Returns the bursts of a given group
%
% USAGE:
%    members = getExperimentGroupBursts(experiment, name)
%
% INPUT arguments:
%    experiment - structure
%
%    name - group name (as returned by getExperimentGroupsNames)
%
% OUTPUT arguments:
%    bursts - burst structure
%
% EXAMPLE:
%     members = getExperimentGroupBursts(experiment, 'everything')
%
% Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>

bursts = [];
nameComponents = strsplit(name, ':');
% Hack in case the user defined name has the delimiter
if(length(nameComponents) > 2)
  nameComponents = {nameComponents{1} strjoin(nameComponents(2:end))};
end
if(isfield(experiment, 'traceGroups') && ~isempty(experiment.traceGroups) && isfield(experiment, 'traceGroupsNames'))
  if(length(nameComponents) == 1)
    bursts = experiment.traceBursts.(nameComponents{1}){1};
  else
    groupNames = experiment.traceGroupsNames.(nameComponents{1});
    validCategory = find(strcmpi(groupNames, strtrim(nameComponents{2})));
    bursts = experiment.traceBursts.(nameComponents{1}){validCategory};
  end
end