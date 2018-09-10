classdef burstDetectionISINexplorerOptions < baseOptions
% BURSTDETECTIONISINEXPLOREROPTIONS Options to explore parametesr for the ISI_N burst detection
%   Class containing the options for ISI_N detection. See: https://doi.org/10.3389/fncom.2013.00193
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also burstDetection, baseOptions, optionsWindow

  properties
    % Group to perform burst detection on:
    % - none: will export all traces
    % - all: will recursively export throughout all defined groups
    % - group parent: will iterate through all its members
    % - group member: will only return the traces from this group member
    group = {'none', ''};
    
    % Range of values for consecutive spikes exploration
    N = '2:2:20';
  
    % Histogram edges for the distribution binning (logarithmic)
    steps = '10.^[-3:.05:3]';

    % If true, will jitter spike times +/- half a frame (for smoother distributions)
    jitterSpikes = true;
    
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
