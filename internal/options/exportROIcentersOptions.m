classdef exportROIcentersOptions < baseOptions
% EXPORTROICENTERSOPTIONS Options for exporting ROI centers
%   Class containing the options for exporting ROI centers
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also exportROIcenters, baseOptions, optionsWindow

  properties
    % Group to extract the traces from:
    % - none: will export all traces
    % - all: will recursively export throughout all defined groups
    % - group parent: will iterate through all its members
    % - group member: will only return the traces from this group member
    group = {'none', ''};
    
    % File type of the exported data:
    % - csv: comma separated values (with header)
    % - txt: space separated ascii file (no header available)
    fileType = {'csv', 'txt'};
    
    % Coordiante system to use:
    % - cartesian: returns X,Y such that 1,1 corresponds to the lower-left of the image
    % - image: returns I,J (rows,cols) such that 1,1 corresponds to the top-left of the image
    coordinates = {'cartesian', 'image'};
    
    % Numeric format to save the data (fprintf format)
    numericFormat = {'%.2f', ''};
    
    % If true will include an additional column where the ROIs of the subpopulation have been rescaled from 1 to N (N being the subpopulation size)
    includeSimplifiedROIorder = false;
    
    % Main folder to export to
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
