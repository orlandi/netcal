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
    
    % Number of seconds to take before the protocol to define the baseline
    baseLineDefinitionTime = 5;
    
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
    
    % Type of threshold to use to detect when the signal starts to decay  (measured since the reaction time)
    decayThresholdType = {'relative'; 'absolute'}';
    
    % Value of the threshold for the decay:
    % - relative: times the global maximum
    % - absolute: absolute increase of the fluorescence value
    decayThreshold = 0.7;
    
    % Type of threshold to use for the recovery time  (measured since the start time)
    recoveryTimeThresholdType = {'relative'; 'absolute'}';
    
    % Value of the threshold for the recovery time:
    % - relative: mean +- effectThreshold times standard deviation
    % - absolute: absolute increase of the fluorescence value
    recoveryTimeThreshold = 5;
    
    % Type of fit to perform to compute the rise time:
    % - none: don't fit
    % - linear: p1*x+p2
    % - single exponential: a*exp(b*x)
    % - double exponential: a*exp(b*x) + c*exp(d*x)
    riseFitType = {'none', 'linear', 'single exponential', 'double exponential'};
    
    % Type of fit to perform to compute the decay time:
    % - none: don't fit
    % - linear: p1*x+p2
    % - single exponential: a*exp(b*x)
    % - double exponential: a*exp(b*x) + c*exp(d*x)
    decayFitType = {'none', 'linear', 'single exponential', 'double exponential'};
    
    % True to show the protocol effect on the viewTraces menu
    showProtocol = true;
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
