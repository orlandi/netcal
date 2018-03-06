classdef oasisOptions < baseOptions
% OASISOPTIONS Options for the Oasis algorithm
%   Class containing the parameters to perform spike inference with the oasis algorithm
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
    
    % True to also store the model trace
    storeModelTrace = false;
    
    % Penalty parameter
    lambda = 50;
    
    % Infernece method
    method = {'foopsi', 'constrained', 'thresholded', 'mcmc'},

    % Infernece model
    model = {'ar1', 'ar2', 'exp2', 'kernel'},
    
    % Minimum spike size constraint (leave 0 for automatic)
    smin = 0;
    
    % Signal to noise parameter (leave at 0 for automatic estimation)
    sn = 0;
    
    % pars. Leave empty if you don't know what this is
    pars = [];
    
    % Window (in frames) for kernel/exp2 generation
    window = 200;
    
    % Shift (slide in frames)
    shift = 100;
    
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
