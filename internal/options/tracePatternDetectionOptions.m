classdef tracePatternDetectionOptions < baseOptions
% TRACEPATTERNDETECTIONOPTIONS Options for pattern detection
%   Class containing the options for pattern detrection
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also tracePatternDetection, baseOptions, optionsWindow

  properties
    % Group to perform function on:
    % - none: will use all traces
    % - all: will recursively go through all defined groups
    % - group parent: will iterate through all the group submembers
    % - group member: will only use the members of this group
    group = {'none', ''};
    
    % Type of traces to use
    tracesType = {'smoothed', 'raw', 'denoised'};
    
    % What to do with overlapping events:
    % - correlation: only the event with the highest correlation will be kept
    % - length: only longest event will be kept
    % - none: allows overlapping
    overlappingDiscriminationMethod = {'correlation', 'length', 'none'};
    
    % What kind of discrimination to apply
    % - independent: will try to resolve any kind of overlapping
    % - groupBased: will only resolve overlapping between members of the same group
    overlappingDiscriminationType = {'independent', 'groupBased'};
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
