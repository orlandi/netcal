classdef burstDetectionISINoptions < baseOptions
% BURSTDETECTIONISINOPTIONS Options for the ISI_N burst detection
%   Class containing the options for ISI_N detection. See: https://doi.org/10.3389/fncom.2013.00193
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also burstDetectionISIN, baseOptions, optionsWindow

  properties
    % Group to perform burst detection on:
    % - none: will export all traces
    % - all: will recursively export throughout all defined groups
    % - group parent: will iterate through all its members
    % - group member: will only return the traces from this group member
    group = {'none', ''};
    
    % Number of consecutive spikes to use for ISI_N calculation
    N = 20;
  
    % Maximum ISI_N to consider a burst (in seconds)
    ISI_N = 1;
    
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
