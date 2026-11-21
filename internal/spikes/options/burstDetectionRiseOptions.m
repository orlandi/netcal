classdef burstDetectionRiseOptions < plotFigureOptions & baseOptions
% BURSTDETECTIONXOPTIONS Options for the X-based burst detection
%   Class containing the options for the X-based burst detection
%
%   Copyright (C) 2020, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also burstDetectionRise, baseOptions, optionsWindow

  properties
    % Group to perform burst detection on:
    % - none: will export all traces
    % - all: will recursively export throughout all defined groups
    % - group parent: will iterate through all its members
    % - group member: will only return the traces from this group member
    group = {'none', ''};
   
    % Activity threshold
    activityThreshold = 2;
    
    % Rise Threshold
    riseThreshold = 5;
    
    % Minimum time (in seconds) between bursts. Any bursts with a smaller IBI than that will be merged together
    minBurstSeparation = 3;
    
    % Minimum burst duration (in seconds)
    minBurstDuration = 3;
    
    % Time interval in which to detect bursts (in seconds)
    timeRange = [0 inf];

    % minimum number of spikes a neuron needs to do (during the whole recording) to be included in the burst calculation
    minSpikes = 0;

    % To show a plot after the detection
    plotResults = true;
  end
  methods
    function obj = setExperimentDefaults(obj, experiment)
      if(~isempty(experiment) && isstruct(experiment))
        try
          obj.group = getExperimentGroupsNamesFull(experiment);
          obj.timeRange = [0 experiment.totalTime];
        catch ME
          logMsg(strrep(getReport(ME), newline, '<br/>'), 'e');
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
