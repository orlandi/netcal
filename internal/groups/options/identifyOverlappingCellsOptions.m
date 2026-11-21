classdef identifyOverlappingCellsOptions < baseOptions
% IDENTIFYOVERLAPPINGCELLSOPTIONS Base options for identifying overlapping cells. Only for 3D data
%   Class containing the options for identifying the overlapping cells
%
%   Copyright (C) 2016-2020, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also identifyOverlappingCells, baseOptions, optionsWindow

  properties
    % Group to perform function on:
    % - none: will use all traces
    % - all: will recursively go through all defined groups
    % - group parent: will iterate through all the group submembers
    % - group member: will only use the members of this group
    group = {'none', ''};
    
    % Type of traces to use
    tracesType = {'smoothed', 'raw', 'denoised'};
    
    % Correlation threshold to use to identify the same cell
    correlationLevel = 0.8;
    
    % Fraction of overlapping pixels to consider it a real overlap (in the projected plane)
    overlapFraction = 0.3;
    
    % Size of pixels (in your respective units, usually um)
    pixelSize = 0.585;
    
    % Distance between planes (in the same units as pixelSize)
    planeSize = 5.08;
    
    
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
