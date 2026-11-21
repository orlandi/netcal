classdef burstDetectionPSPoptions < plotFigureOptions & baseOptions
% BURSTDETECTIONPSPOPTIONS Options for the PSP-based burst detection
%   Class containing the options for the PSP-based burst detection
%
% Copyright (C) 2016-2025, Javier G. Orlandi <javier.orlandi@ucalgary.ca>
%
%   See also burstDetectionPSP, baseOptions, optionsWindow

  properties
    % Group to perform burst detection on:
    % - none: will export all traces
    % - all: will recursively export throughout all defined groups
    % - group parent: will iterate through all its members
    % - group member: will only return the traces from this group member
    group = {'none', ''};
    
    % Type of traces to use
    tracesType = {'smoothed', 'raw', 'denoised'};
    
    % Size of the moving window (in secs) to compute PSP
    windowSize = 10;
    
    % Power Threshold
    powerT = 5e-4;
    
    % If the burst should be above baseline
    baselineCheck = true;
    
    % To show a plot after the detection
    plotResults = true;
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
