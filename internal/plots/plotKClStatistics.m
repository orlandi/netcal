function projexp = plotKClStatistics(projexp, varargin)
% PLOTKCLSTATISTICS plots KCl statistics
%
% USAGE:
%    experiment = plotKClStatistics(experiment, varargin)
%    project = plotKClStatistics(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see plotKClStatisticsOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = plotKClStatistics(experiment)
%    project = plotKClStatistics(project)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% PIPELINE
% name: plot KCl statistics
% parentGroups: protocols: KCl analysis: plots
% optionsClass: plotKClStatisticsOptions
% requiredFields: KClProtocolData


tmpStat = varargin{1}.statistic;
defClass = plotKClStatisticsOptions;
defTitle = 'Plotting KCl statistics';

% This block should be the same for any statistics plot
if(strcmpi(tmpStat, 'ask'))
  tmpClass = defClass.setExperimentDefaults([]);
  statList = tmpClass.statistic(1:end-1); % Removing last one since it's going to be 'all'
  [selection, ok] = listdlg('PromptString', 'Select statistics to plot', 'ListString', statList, 'SelectionMode', 'multiple');
  if(~ok)
    return;
  end
  for it = 1:length(selection)
    logMsg(sprintf('%s for: %s', defTitle, statList{selection(it)}));
    varargin{1}.statistic = statList{selection(it)};
    obj = plotStatistics;
    obj.init(projexp, defClass, defTitle, varargin{:}, 'gui', gcbf);
    if(obj.getData(@getData, projexp, obj.params.statistic))
      obj.createFigure();
    end
    obj.cleanup();
  end
else
  obj = plotStatistics;
  obj.init(projexp, defClass, defTitle, varargin{:}, 'gui', gcbf);
  if(obj.getData(@getData, projexp, obj.params.statistic))
    obj.createFigure();
  end
  obj.cleanup();
end


  %------------------------------------------------------------------------
  function data = getData(experiment, groupName, stat)
    [members, groupName, groupIdx] = getExperimentGroupMembers(experiment, groupName);
    if(~isempty(members))
      switch stat
        case {'baseLine', 'reactionTime', 'maxResponse', 'maxResponseTime',...
              'responseFitSegmentsMaxFluorescenceIncrease', 'responseFitSegmentsMaxSlope', 'responseFitSegments', ...
              'decay', 'decayTime', 'responseDuration', 'recoveryTime', 'recovered', 'protocolEndValue', 'lastResponseValue'}
          data = experiment.KClProtocolData.(groupName){groupIdx}.(stat);
        case 'responseFitFirstSegmentDuration'
          valid = experiment.KClProtocolData.(groupName){groupIdx}.responseFitSegments > 0;
          data = cellfun(@(x)x(1),experiment.KClProtocolData.(groupName){groupIdx}.responseFitSegmentsDuration(valid));
        case 'responseFitFirstSegmentFluorescenceIncrease'
          valid = experiment.KClProtocolData.(groupName){groupIdx}.responseFitSegments > 0;
          data = cellfun(@(x)x(1),experiment.KClProtocolData.(groupName){groupIdx}.responseFitSegmentsFluorescenceIncrease(valid));
        case 'responseFitFirstSegmentSlope'
          valid = experiment.KClProtocolData.(groupName){groupIdx}.responseFitSegments > 0;
          data = cellfun(@(x)x.responseFitSegmentsFluorescenceIncrease(1), experiment.KClProtocolData.(groupName){groupIdx});cellfun(@(x)x(1),experiment.KClProtocolData.(groupName){groupIdx}.responseFitSegmentsSlope(valid));
        otherwise % Just in case
          data = experiment.KClProtocolData.(groupName){groupIdx}.(stat);
      end
%      data = experiment.spikeFeatures(members, selectedStatistic);
      data = data(:); % Always as a column, just to be sure
    else
      data = [];
    end
  end

end