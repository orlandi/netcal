function bursts = getExperimentGroupBursts(experiment, name, varargin)
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
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

if(nargin < 3)
  type = 'fluorescence';
else
  type = varargin{1};
end
bursts = [];
nameComponents = strsplit(name, ':');
% Hack in case the user defined name has the delimiter
if(length(nameComponents) > 2)
  nameComponents = {nameComponents{1} strjoin(nameComponents(2:end))};
end
if(isfield(experiment, 'traceGroups') && ~isempty(experiment.traceGroups) && isfield(experiment, 'traceGroupsNames'))
  if(length(nameComponents) == 1)
    switch type
      case 'fluorescence'
        bursts = experiment.traceBursts.(nameComponents{1}){1};
      case 'spikes'
        bursts = experiment.spikeBursts.(nameComponents{1}){1};
    end
  else
    switch type
      case 'fluorescence'
        groupNames = experiment.traceGroupsNames.(nameComponents{1});
        validCategory = find(strcmpi(groupNames, strtrim(nameComponents{2})));
        bursts = experiment.traceBursts.(nameComponents{1}){validCategory};
      case 'spikes'
        groupNames = experiment.traceGroupsNames.(nameComponents{1});
        validCategory = find(strcmpi(groupNames, strtrim(nameComponents{2})));
        bursts = experiment.spikeBursts.(nameComponents{1}){validCategory};
    end
  end
end