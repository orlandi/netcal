classdef exportActiveNetworkOptions < baseOptions
% EXPORTACTIVENETWORKOPTIONS Options for exporting the current active network to a .mat file
%
%   Copyright (C) 2016-2025, Javier G. Orlandi <javier.orlandi@ucalgary.ca>
%
%   See also setActiveNetwork, baseOptions, optionsWindow

  properties
    % Group to get the active network from:
    % - none: will export all traces
    % - all: will recursively export throughout all defined groups
    % - group parent: will iterate through all its members
    % - group member: will only return the traces from this group member
    group = {'none', ''};
    
    % What base network inference measure to export:
    % GTE: Generalized Transfer Entroy
    % GTE: Unconditioned: Generalized Transfer Entroy
    % xcorr: Cross correlation
    inferenceMeasure = {'GTE', 'GTE unconditioned', 'xcorr'};

    % What main folder to export the network to
    exportBaseFolder = {'experiment', 'project'};
    
    % Tag to append to the exported file
    exportTag = '';
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
