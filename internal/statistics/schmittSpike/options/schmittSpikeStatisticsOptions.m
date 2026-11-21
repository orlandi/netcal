classdef schmittSpikeStatisticsOptions < baseOptions
% SCHMITTSPIKESTATISTICSOPTIONS # Options for computing statistics related to schmittSpike
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also baseOptions, optionsWindow

  properties
    % schmittSpike statistic to compute:
    % - duration: duration of the schmitt triggers
    % - amplitude: description
    % - area: description
    statistic = {'Main statistic'}; % The real list is pulled on setExperimentDefaults
    
    % Type of event to use for detection (leave empty if you do not know whta this is)
    type = 1;
  end
  
  properties (Constant = true, Hidden = true)
    % Required fields should go here
    loadFields = {'schmittSpikesData'};
  end
  
  methods
    function fullData = getData(obj, experiment, groupName, stat)
      % Add required preprocessing
      if(~iscell(stat))
        stat = {stat};
      end
      fullData = cell(size(stat));
      members = getExperimentGroupMembers(experiment, groupName);
      for it_stat = 1:length(stat)
        %%% NEEDS CHANGING
        data = computeSchmittSpikeStatistic(experiment.schmittSpikesData(members), stat{it_stat}, obj.type);
        fullData{it_stat} = data;
      end
      if(length(fullData) == 1)
        fullData = fullData{1};
      end
    end
    
    function data = computeSchmittSpikeStatistic(schmittSpikesData, stat, type)
      switch stat
        case 'duration'
          if(~isempty(type))
            valid = find(cellfun(@(x)isfield(x,'type'), schmittSpikesData));
            data = cellfun(@mean, cellfun(@(x)x.duration(x.type == type), schmittSpikesData(valid),'UniformOutput',false));
          else
            data = cellfun(@mean, cellfun(@(x)x.duration, schmittSpikesData,'UniformOutput',false));
          end
        case 'amplitude'
          if(~isempty(type))
            valid = find(cellfun(@(x)isfield(x,'type'), schmittSpikesData));
            data = cellfun(@mean, cellfun(@(x)x.amplitude(x.type == type), schmittSpikesData(valid),'UniformOutput',false));
          else
            data = cellfun(@mean, cellfun(@(x)x.amplitude, schmittSpikesData,'UniformOutput',false));
          end
        case 'area'
          if(~isempty(type))
            valid = find(cellfun(@(x)isfield(x,'type'),schmittSpikesData));
            data = cellfun(@mean, cellfun(@(x)x.area(x.type == type), schmittSpikesData(valid),'UniformOutput',false));
          else
            data = cellfun(@mean, cellfun(@(x)x.area, schmittSpikesData,'UniformOutput',false));
          end
        otherwise
          data = getCases('eval');
      end
      if(~ischar(data) && ~iscell(data))
        data = double(data(:)); % Always as a column, just to be sure
      end
    end
    
    function obj = setExperimentDefaults(obj, experiment)
      obj.statistic = computeSchmittSpikeStatistic([], 'list');
    end
  end
end
