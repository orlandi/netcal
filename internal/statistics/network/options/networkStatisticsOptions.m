classdef networkStatisticsOptions < baseOptions
% NETWORKSTATISTICSOPTIONS # Options for computing statistics related to network
%
%   Copyright (C) 2016-2026, Javier G. Orlandi <javier.orlandi@ucalgary.ca>
%
%   See also baseOptions, optionsWindow

  properties
    % network statistic to compute:
    % - stat1: description
    statistic = computeNetworkStatistic([], 'list')'; % The real list is pulled on setExperimentDefaults
    
    % If true will divide the measured statistic from the number of cells in the current group. Only applies to measures
    % that deal with average or largest sizes, i.e., X avg community size, X largest community, etc
    normalizeGlobalStatistic = false;
    
    % Number of surrogates to use (for measures involving null models)
    numberSurrogates = 20;
    
    % Any networks with less than this number of nodes will be skipped
    minimumSize = 0;
  end
  
  properties (Constant = true, Hidden = true)
    % Required fields should go here
    loadFields = {'RS', 'ROI', 'name'};
  end
  
  methods
    function fullData = getData(obj, experiment, groupName, stat)
      % Add required preprocessing
      if(~iscell(stat))
        stat = {stat};
      end
      fullData = cell(size(stat));
      members = getExperimentGroupMembers(experiment, groupName);
      [field, idx] = getExperimentGroupCoordinates(experiment, groupName);
      experiment = loadBigFields(experiment, {'RS'});
      RS = double(experiment.RS.(field){idx});
      if(~isempty(obj.minimumSize) && size(RS, 1) < obj.minimumSize)
        logMsg(sprintf('%s skipped due to minimum size (%d vs %d)', experiment.name, size(RS, 1), obj.minimumSize));
      end
      for it_stat = 1:length(stat)
        if(~isempty(obj.minimumSize) && size(RS, 1) < obj.minimumSize)
          fullData{it_stat} = NaN;
          continue;
        end
        try
          data = computeNetworkStatistic(RS,  stat{it_stat}, obj.numberSurrogates, members, experiment.ROI);
        catch
        end
        if(obj.normalizeGlobalStatistic)
          data = data/size(RS, 1);
        end
        fullData{it_stat} = data;
      end
      if(length(fullData) == 1)
        fullData = fullData{1};
      end
    end
    
    
    
    function obj = setExperimentDefaults(obj, experiment) %#ok<INUSD>
      obj.statistic = computeNetworkStatistic([], 'list');
    end
  end
end
