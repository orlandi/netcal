function names = getExperimentGroupsNames(experiment, varargin)
% GETEXPERIMENTGROUPSNAMES Returns the (combined) names of all possible
% defined groups in a given experiment
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
    categories = varargin(1);
    if(strcmpi(categories{1}, 'none') || strcmpi(categories{1}, 'everything'))
      categories{1} = 'everything';
    end
  end
  for i = 1:length(categories)
    if(~isfield(experiment.traceGroupsNames, categories{i}))
      % Check if it's a composite nane (to check on itself)
      nameComponents = strsplit(categories{i}, ':');
      % Hack in case the user defined name has the delimiter
      if(length(nameComponents) > 2)
        nameComponents = {nameComponents{1} strjoin(nameComponents(2:end))};
      end
      if(isfield(experiment, 'traceGroups') && ~isempty(experiment.traceGroups) && isfield(experiment, 'traceGroupsNames') && isfield(experiment.traceGroupsNames, nameComponents{1}))
        groupNames = experiment.traceGroupsNames.(nameComponents{1});
        if(any(strcmpi(groupNames, strtrim(nameComponents{2}))))
          names{end+1} = categories{i};
          continue;
        end
      end
    else
      if(nargin < 3)
        categoriesNames = experiment.traceGroupsNames.(categories{i});
      else
        categoriesNames = {experiment.traceGroupsNames.(categories{i}){varargin{2}}};
      end
      for j = 1:length(categoriesNames)
        % Fix everything name
        if(strcmpi(categories{i}, categoriesNames{j}))
          compositeName = [categories{i}];
        else
          compositeName = [categories{i} ': ' categoriesNames{j}];
        end
        names{end+1} = compositeName;
      end
    end
  end
end