function names = getExperimentGroupsNamesFull(experiment, varargin)
% GETEXPERIMENTGROUPSNAMES Returns the (combined) names of all possible
% defined groups in a given experiment and their parent groups
%
% USAGE:
%    names = getExperimentGroups(experiment)
%
% INPUT arguments:
%    experiment - structure
%
% OUTPUT arguments:
%    names - the actual names
%
% EXAMPLE:
%     names = getExperimentGroups(experiment)
%
% Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
  
names = {};
if(isfield(experiment, 'traceGroups') && ~isempty(experiment.traceGroups) && isfield(experiment, 'traceGroupsNames'))
  if(nargin < 2)
    categories = fieldnames(experiment.traceGroups);
  else
    categories = {varargin{1}};
  end
  for i = 1:length(categories)
    % Skip everything here - since it's a special class - and also adding a new entry
    if(strcmpi(categories{i}, 'everything'))
      names{end+1} = 'none';
      names{end+1} = 'all';
      continue;
    end
    names{end+1} = categories{i};
    categoriesNames = experiment.traceGroupsNames.(categories{i});
    for j = 1:length(categoriesNames)
      compositeName = [categories{i} ': ' categoriesNames{j}];
      names{end+1} = compositeName;
    end
  end
end