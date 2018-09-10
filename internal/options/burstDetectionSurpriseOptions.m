classdef burstDetectionSurpriseOptions < plotFigureOptions & baseOptions
% BURSTDETECTIONSURPRISEOPTIONS Options for the surprise-based burst detection
%   Class containing the options for the surprise-based burst detection. See: https://doi.org/10.1016/j.jneumeth.2006.09.024
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also burstDetectionSurprise, baseOptions, optionsWindow

  properties
    % Group to perform burst detection on:
    % - none: will export all traces
    % - all: will recursively export throughout all defined groups
    % - group parent: will iterate through all its members
    % - group member: will only return the traces from this group member
    group = {'none', ''};
    
    % How to compute the surpsie:
    % - single: individually for each group member
    % - global: on the compound of all spike trains (binarized)
    surpriseMode = {'single', 'global'};
      
    % Minimum surprise to consider individual bursts. Actual number will be minus the logarithm of the input value.
    surpriseThreshold = 1;
    
    % Maximum ISI (in sec) to check for bursts
    maximumISI = 1;
    
    % Thresholds to use to detect global bursts (number of simultaneous suprise bursts). Two numbers as in Schmitt triggers (High and low). Only if surpriseMode = single
    globalSurpriseThresholds = [0.1 0.01];
    
    % How to compute the global suprirse threshold:
    % relative: based on the number of members in the current group
    % absolute: total cell count
    globalSurpriseThresholdType = {'relative', 'absolute'};
    
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
