classdef peelingOptions < baseOptions
% PEELINGOPTIONS Peeling options
%   Class containing the parameters to perform spike inference with the peeling algorithm
%
%   Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
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
    
    % True to also store the model trace
    storeModelTrace = false;
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
