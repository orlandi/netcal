function [members, name, idx] = getExperimentGroupMembers(experiment, name)
% GETEXPERIMENTGROUPMEMBERS Returns the members of a given group
%
% USAGE:
%    members = getExperimentGroupMembers(experiment, name)
%
% INPUT arguments:
%    experiment - structure
%
%    name - group name (as returned by getExperimentGroupsNames)
%
% OUTPUT arguments:
%    members - list of members
%
% EXAMPLE:
%     members = getExperimentGroupMembers(experiment, 'everything')
%
% Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>

members = [];
% Fix
if(strcmpi(name, 'none'))
  name = 'everything';
end
nameComponents = strsplit(name, ':');
% Hack in case the user defined name has the delimiter
if(length(nameComponents) > 2)
  nameComponents = {nameComponents{1} strjoin(nameComponents(2:end))};
end
if(isfield(experiment, 'traceGroups') && ~isempty(experiment.traceGroups) && isfield(experiment, 'traceGroupsNames'))
  if(length(nameComponents) == 1)
    members = experiment.traceGroups.(nameComponents{1}){1};
    name = nameComponents{1};
    idx = 1;
  else
    groupNames = experiment.traceGroupsNames.(nameComponents{1});
    validCategory = find(strcmpi(groupNames, strtrim(nameComponents{2})));
    if(isempty(validCategory))
      members = [];
      name = '';
      idx = [];
      logMsg(sprintf('Could not find group %s on experiment %s', name, experiment.name), 'e');
    else
      members = experiment.traceGroups.(nameComponents{1}){validCategory};
      name = nameComponents{1};
      idx = validCategory;
    end
  end
end