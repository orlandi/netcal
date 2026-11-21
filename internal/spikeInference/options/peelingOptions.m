classdef peelingOptions < baseOptions
% PEELINGOPTIONS Peeling options
%   Class containing the parameters to perform spike inference with the peeling algorithm
%
%   Copyright (C) 2016, Javier G. Orlandi <javiergorlandi@gmail.com>
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
    
    % ROI index used to check peeling results with a single trace (only used in training mode)
    trainingROI = 1;
    
    % Time constant (in seconds) associated to the decay of the fluorescence signal
    tau = 3;

    % Characteristic fluorescence increase due to a spike
    amplitude = 0.9;
    
    % Second ampltiude (DO NOT CHANGE)
    secondAmplitude = 0;
    
    % Second tau (DO NOT CHANGE)
    secondTau = 1;
    
    % noise level (DO NOT CHANGE). Default is: mean(std(traces))*0.75
    standardNoise = []; 
    
    % How to estimate the noise level (if standardNoise is empty)
    % - global: will use a single value for all traces
    % - individual: will use a different value for each trace
    noiseEstimationMethod = {'global', 'individual'};
    
    % schmitt thresholds (DO NOT CHANGE)
    schmittThresholds = [2.4 -1.2];
    
    % Calcium mode:
    % - linDFF: spikes cause linear summation on the fluorescence signal
    % - satDFF: fluorescence signal can saturate
    calciumMode = {'linDFF', 'satDFF'};
    
    % Ca transient extrusion rate (in Hz) - only used in saturation mode
    gamma = 400;
    
    % Maximum DF/F value - only used in saturation mode
    dffmax = 93;
    
    % Optimization method
    optimizationMethod = {'none', 'simulated annealing', 'pattern search', 'genetic'};
    
    % True to also store the model trace
    storeModelTrace = false;
    
    % Do some plots from the original peeling code
    additionalPlots = false;
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
