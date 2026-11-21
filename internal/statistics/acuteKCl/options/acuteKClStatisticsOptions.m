classdef acuteKClStatisticsOptions < baseOptions
% ACUTEKCLSTATISTICSOPTIONS # Options for computing statistics related to acuteKCl
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also baseOptions, optionsWindow

  properties
    % acuteKCl statistic to compute:
    % - baseLine
    % - reactionTime
    % - maxResponse
    % - maxResponseTime
    % - responseFitSegmentsMaxFluorescenceIncrease
    % - responseFitSegmentsMaxSlope
    % - responseFitSegments
    % - decay
    % - decayTime
    % - responseDuration
    % - recoveryTime
    % - recovered
    % - protocolEndValue
    % - lastResponseValue
    % - responseFitFirstSegmentDuration
    % - responseFitFirstSegmentFluorescenceIncrease
    % - responseFitFirstSegmentSlope
    statistic = {'Main statistic'}; % The real list is pulled on setExperimentDefaults
    
  end
  
  properties (Constant = true, Hidden = true)
    % Required fields should go here
    loadFields = {'additionalFields'};
  end
  
  methods
    function fullData = getData(obj, experiment, groupName, stat) %#ok<INUSL>
      if(~iscell(stat))
        stat = {stat};
      end
      fullData = cell(size(stat));
      [field,  idx] = getExperimentGroupCoordinates(experiment, groupName);
      KClProtocolData = experiment.KClProtocolData.(field){idx};
      for it_stat = 1:length(stat)
        data = computeAcuteKClStatistic(KClProtocolData, stat{it_stat});
        fullData{it_stat} = data;
      end
      if(length(fullData) == 1)
        fullData = fullData{1};
      end
    end
    
    function data = computeAcuteKClStatistic(KClProtocolData, stat)
      switch stat
        case 'baseLine'
          data = KClProtocolData.(stat);
        case 'reactionTime'
          data = KClProtocolData.(stat);
        case 'maxResponse'
          data = KClProtocolData.(stat);
        case 'maxResponseTime'
          data = KClProtocolData.(stat);
        case 'responseFitSegmentsMaxFluorescenceIncrease'
          data = KClProtocolData.(stat);
        case 'responseFitSegmentsMaxSlope'
          data = KClProtocolData.(stat);
        case 'responseFitSegments'
          data = KClProtocolData.(stat);
        case 'decay'
          data = KClProtocolData.(stat);
        case 'decayTime'
          data = KClProtocolData.(stat);
        case 'responseDuration'
          data = KClProtocolData.(stat);
        case 'recoveryTime'
          data = KClProtocolData.(stat);
        case 'recovered'
          data = KClProtocolData.(stat);
        case 'protocolEndValue'
          data = KClProtocolData.(stat);
        case 'lastResponseValue'
          data = KClProtocolData.(stat);
        case 'responseFitFirstSegmentDuration'
          valid = KClProtocolData.responseFitSegments > 0;
          data = cellfun(@(x)x(1),KClProtocolData.responseFitSegmentsDuration(valid));
        case 'responseFitFirstSegmentFluorescenceIncrease'
          valid = KClProtocolData.responseFitSegments > 0;
          data = cellfun(@(x)x(1),KClProtocolData.responseFitSegmentsFluorescenceIncrease(valid));
        case 'responseFitFirstSegmentSlope'
          valid = KClProtocolData.responseFitSegments > 0;
          data = cellfun(@(x)x.responseFitSegmentsFluorescenceIncrease(1), KClProtocolData);cellfun(@(x)x(1),KClProtocolData.responseFitSegmentsSlope(valid));
        otherwise
          data = getCases('eval');
      end
      if(~ischar(data) && ~iscell(data))
        data = double(data(:)); % Always as a column, just to be sure
      end
    end
    
    function obj = setExperimentDefaults(obj, experiment)
      obj.statistic = computeAcuteKClStatistic([], 'list');
    end
  end
end
