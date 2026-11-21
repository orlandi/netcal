classdef exportCompactDataOptions < baseOptions
% EXPORTCOMPACTDATAOPTIONS Options for exporting a subset (compact) of
% esseential project data that can be easily opened by other softwares
%
%   Copyright (C) 2016-2026, Javier G. Orlandi <javier.orlandi@ucalgary.ca>
%
%   See also exportCompactData, baseOptions, optionsWindow

  properties
    % Group to get the active network from:
    % - none: will export all traces
    % - all: will recursively export throughout all defined groups
    % - group parent: will iterate through all its members
    % - group member: will only return the traces from this group member
    group = {'none', ''};
    
    % What trace type to export
    % none: Won't be exported
    % raw: rawTraces
    % smoothed: traces after whatever smoothing option you ran
    traces = {'none', 'raw', 'smoothed', 'all'};

    % What network to export
    % none: Won't be exported
    % active: whatever is set as active network
    % GTE: generalized Transfer Entropy
    % GTE unconditioned: generalized Transfer Entropy without conditioning
    % all: all networks
    networks = {'none', 'active', 'GTE', 'GTE unconditioned', 'all'};

    % What movement data to export
    % none: Won't be exported
    % continuous: the continuous movement data
    % binned: after the data was binarized
    % all: both continuous and binned
    movement = {'none', 'continuous', 'binned', 'all'}

    % What spikes to export
    % none: Won't be exported
    % raster: will export the discrete spikes in raster form
    % probability: will export the spike probability instead
    % sparse: will export only the sparse spike list
    % all: will export everything
    spikes = {'none', 'raster', 'probability', 'sparse', 'all'}

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
