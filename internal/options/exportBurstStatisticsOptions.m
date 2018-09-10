classdef exportBurstStatisticsOptions < baseOptions
% EXPORTBURSTSTATISTICSOPTIONS Options for burst statistics
%   Class containing the options for burst statistics
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also exportBurstStatistics, baseOptions, optionsWindow

  properties
    % Group to extract the traces from:
    % - none: will export all traces
    % - all: will recursively export throughout all defined groups
    % - group parent: will iterate through all its members
    % - group member: will only return the traces from this group member
    group = {'none', ''};
    
    % Type of stastics to export
    % - moments: will export the main moments (and a few other observables) of the IBI, burst duration and amplitude statistics
    % - full: will export data for each individual burst
    statisticsType = {'moments', 'full'};
    
    % File type of the exported data:
    % - csv: comma separated values (the header will include the ROI IDs)
    % - txt: space separated ascii file (no header available) - use at your own risk
    fileType = {'csv', 'txt'};
    
    % Numeric format to save the data (fprintf format)
    numericFormat = {'%.5f', ''};
    
    % Main folder to export to (only for experiment pipeline)
    % - experiment: inside the exports folder of the experiment
    % - project: inside the exports folder of the project
    exportFolder = {'experiment', 'project'};
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
