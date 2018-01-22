classdef detectDyingCellsOptions < baseOptions
% DETECTDYINGCELLSOPTIONS Options for detecting dying cells based on large and sudden fluroescence changes. The way this works is that it defines a running baseline looking only at X timesteps into the past. At the same time, it looks at future points, if all of them within a given interval are above a limit, an abrupt change has happened and the cell might have died
%   Class containing the options for dying cells detection
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also detectDyingCells, baseOptions, optionsWindow

  properties
    % Group to perform function on:
    % - none: will use all traces
    % - all: will recursively go through all defined groups
    % - group parent: will iterate through all the group submembers
    % - group member: will only use the members of this group
    group = {'none', ''};
    
    
    % Time (in seconds) to look for changes ahead in the fluorescence baseline
    peekLength = 10;
  
    % Time (in seconds) to keep looking back in time to define the baseline
    pastLength = 10;
    
    % Threshold (times the standard deviation) to check for abrupt changes in the baseline
    stdThreshold = 2;
    
    % Only use one out of every X frames for detection
    frameJump = 1;
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
