classdef groupStatisticsOptions < baseOptions
% GROUPSTATISTICSOPTIONS # Options for computing statistics related to groups
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also baseOptions, optionsWindow

  properties
    % group statistic to compute:
    % - absolute: number of members in the selected group
    % - relative: fraction of members in the selected group (from the total)
    % - parentRelative: fraction of members in the selected group (from the parent)
    % - relativePercent: percentage of members in the selected group (from the total)
    % - parentRelativePercent: percentage of members in the selected group (from the parent)
    statistic = {'Main statistic'}; % The real list is pulled on setExperimentDefaults
    
    % Additional options should go here
  end
  
  properties (Constant = true, Hidden = true)
    % Required fields should go here
    loadFields = {'ROI'};
  end
  
  methods
    function fullData = getData(obj, experiment, groupName, stat) %#ok<INUSL>
      % Add required preprocessing
      if(~iscell(stat))
        stat = {stat};
      end
      fullData = cell(size(stat));
      members = getExperimentGroupMembers(experiment, groupName);

      % Number of ROIs in the parent category (all ROI if there is no parent) - Nov 2026 update
      nParent = length(experiment.ROI);
      comp = strsplit(groupName, ':');
      if(numel(comp) >= 2)
        parent = strtrim(comp{1});
        if(isfield(experiment, 'traceGroups') && isfield(experiment.traceGroups, parent))
          nParent = numel(unique(vertcat(experiment.traceGroups.(parent){:})));
        end
      end

      for it_stat = 1:length(stat)
        data = obj.computeGroupStatistic(members, stat{it_stat}, experiment.ROI, nParent);
        fullData{it_stat} = data;
      end
      if(length(fullData) == 1)
        fullData = fullData{1};
      end
    end
    
    function data = computeGroupStatistic(obj, members, stat, ROI, nParent)
      if(nargin < 5 && nargin >= 4)
        nParent = length(ROI);   % no parent info: same as 'relative'
      end
      switch stat
        case 'absolute'
          data = length(members);
        case 'relative'
          data = length(members)/length(ROI);
        case 'parentRelative'
          data = length(members)/nParent;
        case 'relativePercent'
          data = length(members)/length(ROI)*100;
        case 'parentRelativePercent'
          data = length(members)/nParent*100;
        otherwise
          data = getCases('eval');
      end
      if(~ischar(data) && ~iscell(data))
        data = double(data(:)); % Always as a column, just to be sure
      end
    end
    
    function obj = setExperimentDefaults(obj, experiment)
      obj.statistic = obj.computeGroupStatistic([], 'list');
    end
  end
end
