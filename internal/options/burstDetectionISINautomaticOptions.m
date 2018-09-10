classdef burstDetectionISINautomaticOptions < baseOptions
% BURSTDETECTIONISINAUTOMATICOPTIONS Options for the semi-automatic ISI_N burst detection
%   Class containing the options for semi-automatic ISI_N detection. See: https://doi.org/10.3389/fncom.2013.00193
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also burstDetectionISINautomatic, baseOptions, optionsWindow

  properties
    % Group to perform burst detection on:
    % - none: will export all traces
    % - all: will recursively export throughout all defined groups
    % - group parent: will iterate through all its members
    % - group member: will only return the traces from this group member
    group = {'none', ''};
    
    % Method to use for the semi-automated detection:
    % - schmitt: will use an schmitt trigger with thresholds guessed from the ISI_N distribution
    % - peaks: will use findpeaks function on the log of the ISI_N time course
    % - explore: will show the output of both methods (and do nothing)
    method = {'schmitt', 'peaks', 'explore'};
    
    % minimum fraction of grouped spikes to defined a burst (as a fraction of the number of cells) (only for schmitt)
    burstThreshold = 0.05;
  
    % Minimum time (in seconds) between bursts. Any bursts with a smaller IBI than that will be merged together
    minBurstSeparation = 0.5;
    
    % Minimum number of cells that should fire within a burst. Any burst with less participators than that will be discarded
    minParticipators = 10;
    
    % Multiplier to fine-tune the automatic threshold selection. Increase it to see more bursts (only for schmitt)
    highMultiplier = 1;
    
    % Multiplier to fine-tune the automatic threshold selection. Increase it to see longer bursts (only for schmitt)
    lowMultiplier = 1;
    
    % Multiplier to find-tune the peak detector. Incrase it to capture less bursts and decrease it to capture more (only for peaks)
    peakMultiplier = 1;
    
    % To show a plot after the detection
    plotResults = true;
    
    % If true, will reorder ROI before plotting based on their activity (from high to low, only if plotResults = true)
    reorderChannels = false;
    
    % If true, figures should be tiled within the screen
    tileFigures = true;
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
