classdef plotFluorescenceRasterOptions < plotFigureOptions & baseOptions
% PLOTFLUORESCENCERASTEROPTIONS Base options for fluorescence a raster plot
%   Class containing the options for a raster plot
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also plotFluorescenceRaster, plotBaseOptions, baseOptions, optionsWindow

  properties
    % Group to perform function on:
    % - none: will use all traces
    % - all: will recursively go through all defined groups
    % - group parent: will iterate through all the group submembers
    % - group member: will only use the members of this group
    group = {'none', ''};

    % What traces to use
    tracesType = {'smoothed', 'raw'};
    
    % If true, also plot the average trace on top 
    plotAverageActivity = true;
    
    % If the fluorescence levels should be normalized
    % none: no normalization
    % global: all fluorescence levels are normalized between the global minimum and maximum
    % per trace: each trace is normalized between its minimum and maximum
    normalization = {'none', 'global', 'per trace'};
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
          obj.group{end+1} = '';
        end
        if(length(obj.group) == 1)
          obj.group{end+1} = '';
        end
      end
      obj.styleOptions.figureSize = [800 400];
      obj.styleOptions.colormap = 'parula';
    end
  end
end
