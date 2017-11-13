classdef foopsiOptions < baseOptions
% FOOPSI Options for the FOOPSI algorithm
%   Class containing the parameters to perform spike inference with the foopsi algorithm
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also spikeInferenceFoopsi, baseOptions, optionsWindow

  properties
    % Group to perform function on:
    % - none: will use all traces
    % - all: will recursively go through all defined groups
    % - group parent: will iterate through all the group submembers
    % - group member: will only use the members of this group
    group = {'none', ''};
    
    % Type of traces to use
    tracesType = {'smoothed', 'raw', 'denoised'};
    
    % ROI index used to check peeling results with a single trace (only used in training mode)
    trainingROI = 1;
    
    % Type of threshold to use for spike detection:
    % - relative: X, where X is mean+X standard deviation of the firing probability distribution
    % - absolute: absolute threshold for the firing probability
    % - time varying: will compute a new relative threshold based on the local standard deviation (see probabilityThresholdBlockSize)
    probabilityThresholdType = {'relative', 'absolute', 'time varying'};
    
    % Probability threshold for spike detection (see probabilityThresholdType)
    probabilityThreshold = 1.96;
    
    % Number of seconds within a point to use to estimate the local mean and standard deviation (if threshold type = time varying)
    probabilityThresholdBlockSize = 5;
    
    % True to also store the model trace
    storeModelTrace = false;
    
    % True to also plot the firing probability (only for training). Useful to select the probability threshold
    showFiringProbability = false;
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
