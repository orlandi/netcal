classdef traceUnsupervisedEventDetectionOptions < baseOptions
% TRACEUNSUPERVISEDEVENTDETECTIONOPTIONS Options for unsupervised event detection
%   Class containing the options for pattern detrection
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also traceUnsupervisedEventDetection, baseOptions, optionsWindow

  properties
    % Group to perform function on:
    % - none: will use all traces
    % - all: will recursively go through all defined groups
    % - group parent: will iterate through all the group submembers
    % - group member: will only use the members of this group
    group = {'none', ''};
    
    % Type of traces to use
    tracesType = {'smoothed', 'raw', 'denoised'};
    
    % Minimum event length for detection (in seconds)
    minimumEventLength = 1;
    
    % Type of threshold to use for event detection
    thresholdType = {'relative', 'absolute'};
    
    % Thresholds to use for the event detection (using a Schmitt trigger). First number is the upper threshold, second the lower threshold
    threshold = [1 0];
    
    % Number of groups to use for the unsupervised classification (through Kmeans). Always allow one group for noise
    numberGroups = 3;
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
