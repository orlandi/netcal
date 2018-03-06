classdef burstDetectionXoptions < plotFigureOptions & baseOptions
% BURSTDETECTIONXOPTIONS Options for the X-based burst detection
%   Class containing the options for the X-based burst detection
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also burstDetectionX, baseOptions, optionsWindow

  properties
    % Group to perform burst detection on:
    % - none: will export all traces
    % - all: will recursively export throughout all defined groups
    % - group parent: will iterate through all its members
    % - group member: will only return the traces from this group member
    group = {'none', ''};
      
    % Size of the window (in secs) to compute averages with
    windowSize = 1;
    
    % Thresholds to use to detect global bursts (see globalThresholdType)
    globalThresholds = [90 10];
    
    % How to compute the global suprirse threshold:
    % percentile: based on the hitted percentile (in %)
    % relative: fraction of channels within the group
    % absolute: total number of channels
    globalThresholdType = {'percentile', 'relative', 'absolute'};
    
    % Minimum time (in seconds) between bursts. Any bursts with a smaller IBI than that will be merged together
    minBurstSeparation = 0.5;
    
    % Minimum number of cells that should fire within a burst. Any burst with less participators than that will be discarded
    minParticipators = 10;
    
    % To show a plot after the detection
    plotResults = true;
    
    % If true, will reorder ROI before plotting based on their activity (from high to low, only if plotResults = true)
    reorderChannels = false;
    
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
