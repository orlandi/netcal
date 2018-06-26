classdef schmittOptions < baseOptions
% SCHMITTGOPTIONS Schmitt trigger options
%   Class containing the parameters to perform spike inference with a
%   schmitt trigger. It will identify a spike whenever the signal goes
%   above the upperThreshold and doesn't go below the lower threshold. It
%   will associate the spike with the average time between the rise and the
%   local maxima, and also store the duration and ampltiude in separated
%   variables.
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also Peeling, baseOptions, optionsWindow

  properties
    % Group to perform function on:
    % - none: will use all traces
    % - all: will recursively go through all defined groups
    % - group parent: will iterate through all the group submembers
    % - group member: will only use the members of this group
    group = {'none', ''};
    
    % Type of traces to use
    tracesType = {'smoothed', 'raw', 'denoised'};
    
    % ROI index used to check inference results with a single trace (only used in training mode)
    trainingROI = 1;
    
    % First threshold for spike detection (signal has to go above this
    % value, see also threshold type)
    upperThreshold = 3;

    % Second threshold for spike detection (signal has to go below this
    % value, see also threshold type)
    lowerThreshold = 0.9;
    
    % Type of threshold measure. Relative, means it will look for
    % multipliers of the standard deviation of the signal (above the mean).
    % Absolute will look for values directly above whatever the threshold
    % is.
    thresholdType = {'relative', 'absolute'};
    
    % If not empty, will discard all events whoe amplitude does not reach this value
    minimumEventAmplitude = [];
    
    % If not empty, will discard all events whose duration is less than this (in seconds)
    minimumEventDuration = [];
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
