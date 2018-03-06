classdef identifyISIoptions < baseOptions
% IDENTIFYISIOPTIONS Base options for identify ISI
%   Finds groups of spiking cells with similar ISI distributions
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also identifyISI, baseOptions, optionsWindow

  properties
    % Group to perform function on:
    % - none: will use all traces
    % - all: will recursively go through all defined groups
    % - group parent: will iterate through all the group submembers
    % - group member: will only use the members of this group
    group = {'none', ''};
    
    % Significance level between group members (leave at 0 or empty for automatic detection)
    significanceLevel = 0.05;
    
    % How to compute the overall significance across group members:
    % - average: average p value across all entries (recommended) (uses cityblock distance)
    % - max: maximum p value alowed between all group members (uses Chebychev distance)
    significanceMeasure = {'average', 'max'}
    
    % If significanceLevel is 0 or empty: set of p values to use when looking for the optimal significance (will be eval'd). Optimal value will be the one that maximizes the skewness on the number of groups found (resulting in maximal number of groups)
    automaticSignificanceRange = 'linspace(0+eps, 0.1, 50)';
    
    % Variable to maximize when looking for optimial significance level:
    % - largestGroup: will maximize the size of the largest group relative to the size of all the other groups
    % - numGroups: will maximize the number of resulting groups
    % - skewness: will maximize the skewness of the distribution of groups sizes
    automaticSignificanceMeasure = {'largestGroup', 'numGroups', 'skewness'};
    
    % Minimum number of members per group (any group with less than those members will be ungrouped)
    minimumGroupSize = 3;
    
    % How to sort the resulting groups;
    % size: sorts them by size
    % firing rate: sorts them by average firing rate
    groupOrder = {'size', 'firing rate'};
    
    % If true, will plot the results of the automatic exploration (only if significanceLevel is 0 or empty)
    plotAutomaticSignificanceLevel@logical = true;
  end
  methods 
    function obj = setExperimentDefaults(obj, experiment)
      if(~isempty(experiment) && isstruct(experiment))
        try
          obj.group = getExperimentGroupsNamesFull(experiment);
        catch ME
          logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
        end
      elseif(~isempty(experiment) && exist(experiment, 'file'))
        exp = load(experiment, '-mat', 'folder', 'name', 'traceGroups', 'traceGroupsNames');
        groups = getExperimentGroupsNamesFull(exp);
        if(~isempty(groups))
          obj.group = groups;
        end
        if(length(obj.group) == 1)
          obj.group{end+1} = '';
        end
      end
    end
  end
end
