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
%    see plotQCECOptions
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
if(strcmpi(tmpStat, 'ask'))
  if(isfield(projexp, 'checkedExperiments'))
    exp = [projexp.folderFiles projexp.experiments{find(projexp.checkedExperiments, 1, 'first')} '.exp'];
    tmpClass = defClass.setExperimentDefaults(exp);
  else
    tmpClass = defClass.setExperimentDefaults(projexp);
  end
  %tmpClass = defClass.setExperimentDefaults([]);
  statList = tmpClass.statistic(1:end-2); % Removing last one since it's going to be empty and 'all'
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
    autoArrangeFigures();
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
    members = getExperimentGroupMembers(experiment, groupName);
    if(~isempty(members))
      selectedStatistic = strcmp(experiment.spikeFeaturesNames, stat);
      data = experiment.spikeFeatures(members, selectedStatistic);
      data = data(:); % Always as a column, just to be sure
    else
      data = [];
    end
  end

end