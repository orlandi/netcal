classdef detectPeaksOptions < baseOptions
% DETECTPEAKSOPTIONS Options for peak detection
%   Class containing the options for pattern detrection
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also detectPeaks, baseOptions, optionsWindow

  properties
    % Group to perform function on:
    % - none: will use all traces
    % - all: will recursively go through all defined groups
    % - group parent: will iterate through all the group submembers
    % - group member: will only use the members of this group
    group = {'none', ''};
    
    % Type of traces to use
    tracesType = {'smoothed', 'raw', 'denoised'};
    
    % Minimum peak height
    minPeakHeight = 5;
    
    % Minimum peak prominence
    minPeakProminence = 5;
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
