classdef tracePatternDetectionOptions < baseOptions
% TRACEPATTERNDETECTIONOPTIONS Options for pattern detection
%   Class containing the options for pattern detrection
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
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
    
    % If larger than 0 (has to be an integer), traces will first be downsampled by this factor to speed up calculations and avoid low SNR effects
    downsamplingFactor = 0;
    
    % To what signals apply the downsampling factor:
    % - all: to all signals
    % - traces: only to the traces (useful if the patterns were selected with downsampled traces or on low framerate experiments)
    % - patterns: only to the patterns
    downsamplingTarget = {'all', 'traces', 'patterns'};
    
    % If true, will only try to detect events where a peak has been detected (see detectPeaks)
    usePeakInformation = false;
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
