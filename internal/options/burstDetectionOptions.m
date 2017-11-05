classdef burstDetectionOptions < baseOptions
% BURSTDETECTIONOPTIONS Options for burst detection
%   Class containing the options for burst detrection
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also burstDetection, baseOptions, optionsWindow

  properties
    % Group to perform burst detection on:
    % - none: will export all traces
    % - all: will recursively export throughout all defined groups
    % - group parent: will iterate through all its members
    % - group member: will only return the traces from this group member
    group = {'none', ''};
    
    % Type of traces to use
    tracesType = {'smoothed', 'raw', 'denoised'};
    
    % Detection method:
    % - schmitt: will use a schmitt trigger (based on thresholds)
    % - pattern: will use a pattern library (within the pattern group called bursts), the pattern library has to exist on the experiment
    detectionMethod = {'schmitt', 'pattern'};
    
    % If true, it will try and automatically detect the length of the
    % burst. Otherwise, it will just use the pattern length
    overridePatternLength = false;
    
    % Type of threshold (only for the schmitt trigger):
    % - relative: thresholds are defined as mean + X times the standard deviation of the signal
    % - absolute: in absolute units (this usually means dF/F)
    schmittThresholdType = {'relative', 'absolute'};
    
    % Schmitt thresholds (first the upper and then the lower). The way the schmitt trigger works is that the beginning of a burst is defined whenever the signal goes above the upper threshold, and it finishes whenever it goes below the second threshold). Set them equal for a normal threshold
    schmittThresholds = [1, 0.1];
    
    % Any number between 0 and 1 will use that value as the pattern-detection correlation threshold (only valid for pattern detection method).
    overridePatternThreshold = 0;
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
