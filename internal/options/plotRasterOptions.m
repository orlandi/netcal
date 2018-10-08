classdef plotRasterOptions < plotFigureOptions & baseOptions
% PLOTRASTEROPTIONS Base options for a raster plot
%   Class containing the options for a raster plot
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also plotRaster, plotBaseOptions, baseOptions, optionsWindow

  properties
    % Group to perform function on:
    % - none: will use all traces
    % - all: will recursively go through all defined groups
    % - group parent: will iterate through all the group submembers
    % - group member: will only use the members of this group
    group = {'none', ''};

    % If true, also plot the average activity on top 
    plotAverageActivity = true;
    
    % Bin size (in sec) for the average activity plot. If empty, will use
    % the inverse of the frame rate
    averageActivityBinning = 0.1;
    
    % Scale to use when plotting the average activity (leave empty for
    % automatic, use an interval to define lower and upper limit, e.g., [0 1])
    averageActivityScale = [];
    
    % How to normalize the average activity:
    % - none: no normalization (spike count per bin)
    % - ROI: normalize per cell within the target group
    % - bin: normalize per bin size (total firing rate)
    % - binAndROI: normalize per bin size and roi (firing rate pr cell)
    averageActivityNormalization = {'none', 'ROI', 'bin', 'binAndROI'};
    
    % Line color (only if 1 group i selected. Otherwise it will use the full colormap)
    lineColor = [0, 0, 0.5];
    
    % Line width
    lineWidth = 1;

    % Line style
    lineStyle = '-';
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
    end
  end
end
