function projexp = plotSpikeStatistics(projexp, varargin)
% PLOTSPIKESTATISTICS plots spike statistics
%
% USAGE:
%    experiment = plotSpikeStatistics(experiment, varargin)
%    project = plotSpikeStatistics(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see plotSpikeStatisticsOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = plotQCEC(experiment)
%    project = plotQCEC(project)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% PIPELINE
% name: plot spike statistics
% parentGroups: spikes: plots
% optionsClass: plotSpikeStatisticsOptions
% requiredFields: spikes

tmpStat = varargin{1}.statistic;
defClass = plotSpikeStatisticsOptions;
defTitle = 'Plotting spikes statistics';

% This block should be the same for any statistics plot
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
      obj.init(projexp, defClass, defTitle, varargin{:}, 'gui', gcbf, 'multiStatistic', 'init', 'loadFields', {'spikes', 'spikeFeaturesNames', 'spikeFeatures'});
    else
      obj.init(projexp, defClass, defTitle, varargin{:}, 'gui', gcbf, 'multiStatistic', 'present', 'plotDataFull', plotDataFull{it}, 'loadFields', {'spikes', 'spikeFeaturesNames', 'spikeFeatures'});
    end
    if(obj.getData(@getData, projexp, statList(selection)))
      if(it == 1)
        plotDataFull = obj.plotDataFull;
      end
      obj.createFigure();
    end
    obj.cleanup();
    autoArrangeFigures();
  end
else
  obj = plotStatistics;
  obj.init(projexp, defClass, defTitle, varargin{:}, 'gui', gcbf, 'loadFields', {'spikes','spikeFeaturesNames', 'spikeFeatures'});
  if(obj.getData(@getData, projexp, obj.params.statistic))
    obj.createFigure();
  end
  obj.cleanup();
end

  %------------------------------------------------------------------------
  function fullData = getData(experiment, groupName, stat)
    if(~iscell(stat))
      stat = {stat};
    end
    fullData = cell(size(stat));
    members = getExperimentGroupMembers(experiment, groupName);
    for it_stat = 1:length(stat)
      switch stat{it_stat}
        case 'Global Firing Rate (Hz)'
          selectedStatistic = strcmp(experiment.spikeFeaturesNames, 'Firing rate (Hz)');
          data = experiment.spikeFeatures(members, selectedStatistic);
          data = nansum(data(:)); % The sum of all firing rates
        case 'Total non-spiking'
          data = sum(cellfun(@(x)isempty(x)||all(isnan(x)),experiment.spikes(members)));
        case 'Fraction non-spiking'
          data = sum(cellfun(@(x)isempty(x)||all(isnan(x)),experiment.spikes(members)))/length(members);
        otherwise
        if(~isempty(members))
          selectedStatistic = strcmp(experiment.spikeFeaturesNames, stat{it_stat});
          data = experiment.spikeFeatures(members, selectedStatistic);
          data = data(:); % Always as a column, just to be sure
        else
          data = [];
        end
      end
      fullData{it_stat} = data;
    end
    if(length(fullData) == 1)
      fullData = fullData{1};
    end
  end

end