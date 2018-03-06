classdef MLspikeOptions < baseOptions
% MLSPIKEOPTIONS Options for the MLspike algorithm
%   Class containing the parameters to perform spike inference with the MLspike algorithm
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
    
    % Type of traces to use. Raw is usually better for MLspike
    tracesType = {'raw', 'smoothed', 'denoised'};
    
    % ROI index used to check peeling results with a single trace (only used in training mode)
    trainingROI = 1;
    
    % Decay time (in s) Leave empty for automatic estimation.
    tau = 1;
    
    % Amplitude associated to one spike. Leave empty for automatic estimation.
    a = 0.1;
    
    % When to estimate tau and a:
    % - trainingROI: the training ROI trace will be used to estimate the parameters. If none is provided, one will be selected at random from the current group
    % - all: parameters will be estimated for every trace. Please note that this might be extremely slow
    automaticEstimationMode = {'trainingROI', 'all'};
    
    % Type of baseline estimation
    baseLineMode = {'drifting', 'stable'};
    
    % baseLine fluorescence. Leave empty for automatic estimation
    F0 = [];
    
    % show graph summary
    showSummary = false;
    
    % True to also store the model trace
    storeModelTrace = false;
    
    % If the function should be run in parallel (1 trace per job)
    parallel = false;
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
