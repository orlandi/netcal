classdef exportActiveNetworkToGephiOptions < baseOptions
% EXPORTACTIVENETWORKTOGEPHIOPTIONS Options for exporting the current active network to an .gexf file for GEPHI
%   Class containing the options for exporting the current active network to an .gexf file for GEPHI
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also burstDetectionX, baseOptions, optionsWindow

  properties
    % Group to get the active network from:
    % - none: will export all traces
    % - all: will recursively export throughout all defined groups
    % - group parent: will iterate through all its members
    % - group member: will only return the traces from this group member
    group = {'none', ''};
      
    % Size of the window (in secs) to compute averages with
    additionalScore = {'none', 'ask'};

    % In case you want to compute a network statistic that requires
    % surrrogates
    numberSurrogates = 100;
    
    % What main folder to export the network to
    exportBaseFolder = {'experiment', 'project'};
    
    % Tag to append to the exported file
    exportTag = '';
  end
  methods
    function obj = setExperimentDefaults(obj, experiment)
      scoreList = computeNetworkStatistic([], 'list');
      obj.additionalScore = ['none' scoreList' 'all' 'ask'];
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
