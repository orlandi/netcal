classdef KClProtocolOptions < baseOptions
% KCLPROTOCOLOPTIONS Options for defining a protocol of acute KCl application
%   Class containing the parameters for defining a protocol of acute KCl application
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also viewTraces, baseOptions, optionsWindow

  properties
    % Group to perform function on:
    % - everything: will use all traces
    % - all: will recursively go through all defined groups
    % - group parent: will iterate through all the group submembers
    % - group member: will only use the members of this group
    group = {'everything', ''};
    
    % Type of traces to use
    tracesType = {'smoothed', 'raw', 'denoised'};
    
    % Time at which the protocol began (in seconds)
    startTime = 0;
    
    % Time at which the protocol finished (in seconds)
    endTime = inf;
    
    % Time (since the protocol began) to check for an effect after the protocol began (in seconds)
    windowOfInterest = inf;
    
    % Method used to detect the onset time:
    % - baseLine: estimate the baseline (using a percentile) before the estimulation and find
    % abrupt changes afterwards (see baseLineDefinitionTime and
    % baselineThreshold)
    % - valleyDetection: use the findPeaks function to estimate the
    % position of the onset time
    onsetDetectionMethod = {'baseLine', 'valleyDetection', 'both'};
    
    % Number of seconds to take before the protocol to define the baseline
    baseLineDefinitionTime = 5;
    
    % Percentile level to use to define the baseline (between 0 and 1)
    baseLineThreshold = 0.1;
    
    % Drift multiplier added to the original line to maximize valley detection
    valleyDetectionTilt = 10;
    
    % Prominence value to detect the peaks (see findPeaks function)
    valleyProminence = 15;
    
    % protocolType: If you expect the protocol to increase (positive) or decrease (negative)  the signal
    protocolType = {'positive'; 'negative'}';
    
    % Type of threshold to use for the reaction time. The reaction time is the time interval since the protocol began until it starts to increase/decrease significantly
    reactionTimeThresholdType = {'relative'; 'absolute'}';
    
    % Value of the threshold for the reaction time:
    % - relative: mean +- effectThreshold times standard deviation
    % - absolute: absolute increase of the fluorescence value
    reactionTimeThreshold = 5;
    
    % Type of threshold to use to detect the maximum response (measured since the reaction time)
    maxResponseThresholdType = {'relative'; 'absolute'}';
    
    % Value of the threshold for the max response:
    % - relative: times the global maximum
    % - absolute: absolute increase of the fluorescence value
    maxResponseThreshold = 0.99;
 
    % If true, will try to fit the response (from the reaction time to the maximum response) by partioning the signal into various linear fits
    responseFit = true;
    
    % Minimum separation (in time) to detect slope changes
    responseFitMinimumTime = 0.5;
    
    % Penalty parameter to define when the fitting should stop (the higher the number the faster it will stop (less partitions))
    responseFitResidual = 800;
    
    % Maximum number of slopes to try to fit
    responseFitMaximumSlopes = 5;
    
    % Window size (in sec) for the linear fits used to determine when the
    % signal starts to decay
    decayWindowSize = 10;
    
    % Type of threshold to use for the recovery time  (measured since the start time)
    recoveryTimeThresholdType = {'relative'; 'absolute'}';
    
    % Value of the threshold for the recovery time:
    % - relative: mean +- effectThreshold times standard deviation
    % - absolute: absolute increase of the fluorescence value
    recoveryTimeThreshold = 5;
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
