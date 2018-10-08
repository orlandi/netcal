function projexp = plotNetworkStatistics(projexp, varargin)
% PLOTNETWORKSTATISTICS # Plot network statistics
% Plots statistics associated to network structure
%
% USAGE:
%    projexp = plotNetworkStatistics(projexp, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see plotNetworkStatisticsOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = plotNetworkStatistics(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% PIPELINE
% name: plot network statistics
% parentGroups: network: plots, statistics: network
% optionsClass: plotNetworkStatisticsOptions
% requiredFields: RS

tmpStat = varargin{1}.statistic;
defClass = plotNetworkStatisticsOptions;
defTitle = 'Plotting network statistics';
if(strcmpi(tmpStat, 'ask') || strcmpi(tmpStat, 'all'))
  if(isfield(projexp, 'checkedExperiments'))
    exp = [projexp.folderFiles projexp.experiments{find(projexp.checkedExperiments, 1, 'first')} '.exp'];
    tmpClass = defClass.setExperimentDefaults(exp);
  else
    tmpClass = defClass.setExperimentDefaults(projexp);
  end
  %tmpClass = defClass.setExperimentDefaults([]);
  statList = tmpClass.statistic(1:end-2); % Removing last one since it's going to be empty and 'all'
  if(strcmpi(tmpStat, 'ask'))
    [selection, ok] = listdlg('PromptString', 'Select statistics to plot', 'ListString', statList, 'SelectionMode', 'multiple');
    if(~ok)
      return;
    end
  elseif(strcmpi(tmpStat, 'all'))
    selection = 1:length(statList);
  end
  plotDataFull = {};
  for it = 1:length(selection)
    logMsg(sprintf('%s for: %s', defTitle, statList{selection(it)}));
    varargin{1}.statistic = statList{selection(it)};
    obj = plotStatistics;
    if(it == 1)
      obj.init(projexp, defClass, defTitle, varargin{:}, 'gui', gcbf, 'multiStatistic', 'init', 'loadFields', {'RS', 'ROI', 'name'});
    else
      obj.init(projexp, defClass, defTitle, varargin{:}, 'gui', gcbf, 'multiStatistic', 'present', 'plotDataFull', plotDataFull{it}, 'loadFields', {'RS', 'ROI', 'name'});
    end
    %if(obj.getData(@getData, projexp, statList{selection(it)}, obj.params.normalizeGlobalStatistic, obj.params.minimumSize, obj.params.numberSurrogates))
    if(obj.getData(@getData, projexp, statList(selection), obj.params.normalizeGlobalStatistic, obj.params.minimumSize, obj.params.numberSurrogates))
      if(it == 1)
        plotDataFull = obj.plotDataFull;
      end
      obj.createFigure();
    end
    if(obj.params.normalizeGlobalStatistic)
      ax = obj.axisHandle;
      ax.Title.String = ['normalized ' ax.Title.String];
      hFig = obj.figureHandle;
      hFig.Name = ['normalized ' hFig.Name];
    end
    obj.cleanup();
    autoArrangeFigures();
  end
else
  obj = plotStatistics;
  obj.init(projexp, defClass, defTitle, varargin{:}, 'gui', gcbf, 'loadFields', {'RS', 'ROI', 'name'});
  if(obj.getData(@getData, projexp, obj.params.statistic, obj.params.normalizeGlobalStatistic, obj.params.minimumSize, obj.params.numberSurrogates))
    obj.createFigure();
  end
  if(obj.params.normalizeGlobalStatistic)
    ax = obj.axisHandle;
    ax.Title.String = ['normalized ' ax.Title.String];
    hFig = obj.figureHandle;
    hFig.Name = ['normalized ' hFig.Name];
  end
  obj.cleanup();
end

  %------------------------------------------------------------------------
  function fullData = getData(experiment, groupName, stat, norm, minSize, nSurrogates)
    %bursts = getExperimentGroupBursts(experiment, groupName, 'spikes');
    [field, idx] = getExperimentGroupCoordinates(experiment, groupName);
    
    RS = double(experiment.RS.(field){idx});
    originalRS = RS;
    if(~iscell(stat))
      stat = {stat};
    end
    fullData = cell(size(stat));
    if(~isempty(minSize) && size(RS, 1) < minSize)
      logMsg(sprintf('%s skipped due to minimum size (%d vs %d)', experiment.name, size(RS, 1), minSize));
    end
    for it_stat = 1:length(stat)
      RS = originalRS;
      if(~isempty(minSize) && size(RS, 1) < minSize)
        fullData{it_stat} = NaN;
        continue;
      end
      try
        data = computeNetworkStatistic(RS, stat{it_stat}, nSurrogates);
      catch
        logMsg(sprintf('Error getting data from experiment %s for %s. Setting it to NaN', experiment.name, stat{it_stat}), 'w');
        data = NaN;
      end
      % If we should normalize the statistic
      if(norm)
        %switch stat
        %  case {'avg comp size', 'largest connected comp', 'louvain avg community size', 'louvain largest community', 'modularity avg community size', 'modularity largest community'}
            data = data/size(RS, 1);
        %end
      end
      fullData{it_stat} = data;
    end
    if(length(fullData) == 1)
      fullData = fullData{1};
    end
  end
end
