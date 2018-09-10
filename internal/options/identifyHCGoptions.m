classdef identifyHCGoptions < baseOptions
% IDENTIFYHCGOPTIONS Base options for identifying the HCG
%   Class containing the options for identifying the HCG
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also identifyHCG, baseOptions, optionsWindow

  properties
    % Group to perform function on:
    % - none: will use all traces
    % - all: will recursively go through all defined groups
    % - group parent: will iterate through all the group submembers
    % - group member: will only use the members of this group
    group = {'none', ''};
    
    % Type of traces to use
    tracesType = {'smoothed', 'raw', 'denoised'};
    
    % If true, will automatically detect the correlation level
    automaticCorrelationLevel@logical = true;
    
    % Correlation threshold to use to separate the groups (between 0 and 1). Only applies if automaticCorrelationLevel is set to false.
    correlationLevel = 0.7;
    
    % If true, will plot the results of the automatic exploration (only if automatic exploration is set to true)
    plotAutomaticCorrelationLevel@logical = true;
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
