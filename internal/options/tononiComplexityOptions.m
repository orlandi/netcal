classdef tononiComplexityOptions < baseOptions
% TONONICOMPLEXITYOPTIONS # Tononi complexity
%   Options for measuring Tononi Complexity. Implemented from the NCCToolboxV1.
%   See: [http://www.pnas.org/content/91/11/5033](http://www.pnas.org/content/91/11/5033)
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also baseOptions, optionsWindow

  properties
    % Group to perform function on:
    % - none: will use all traces
    % - all: will recursively go through all defined groups
    % - group parent: will iterate through all the group submembers
    % - group member: will only use the members of this group
    group = {'none', ''};

    % binSize (in seconds) for generating the raster (if empty, it will use the inverse of the framerate)
    binSize = [];
    
    % Maximum number of subsets to use on the computation
    maxSubsets = 100;
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
