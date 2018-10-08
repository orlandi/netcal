classdef setActiveNetworkOptions < baseOptions
% SETACTIVENETWORKOPTIONS Sets some network inference measure as the active network (adjacency matrix)
% trace across the whole recording
%   Class containing the options for tsetting the active network
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also setActiveNetwork, baseOptions, optionsWindow

  properties
    % Group to perform burst detection on:
    % - none: will export all traces
    % - all: will recursively export throughout all defined groups
    % - group parent: will iterate through all its members
    % - group member: will only return the traces from this group member
    group = {'none', ''};
      
    % What nemtwork inference measure to use:
    % GTE: Generalized Transfer Entroy
    % GTE: Unconditioned: Generalized Transfer Entroy
    % xcorr: Cross correlation
    inferenceMeasure = {'GTE', 'GTE unconditioned', 'xcorr'};
    
    % Confidence level measure to establish significance
    confidenceLevelThreshold = 2;
    
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
