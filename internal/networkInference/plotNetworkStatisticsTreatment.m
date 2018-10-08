function projexp = plotNetworkStatisticsTreatment(projexp, varargin)
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
%    experiment = plotNetworkStatisticsTreatment(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% PIPELINE
% name: plot network statistics treatments
% parentGroups: network: plots, treatments, statistics: network
% optionsClass: plotNetworkStatisticsTreatmentOptions
% requiredFields: GTE

tmpStat = varargin{1}.statistic;
defClass = plotNetworkStatisticsTreatmentOptions;
defTitle = 'Plotting network statistics';
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
    obj = plotStatisticsTreatment;
    obj.init(projexp, defClass, defTitle, varargin{:}, 'gui', gcbf, 'loadFields', {'RS', 'name'});
    if(obj.getData(@getData, projexp,obj.params.statistic, obj.params.normalizeGlobalStatistic, obj.params.minimumSize, obj.params.numberSurrogates))
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
  obj = plotStatisticsTreatment;
  obj.init(projexp, defClass, defTitle, varargin{:}, 'gui', gcbf, 'loadFields', {'RS', 'name'});
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
  function data = getData(experiment, groupName, stat, norm, minSize, nSurrogates)
    %bursts = getExperimentGroupBursts(experiment, groupName, 'spikes');
    [field, idx] = getExperimentGroupCoordinates(experiment, groupName);
    
    RS = double(experiment.RS.(field){idx});
    if(~isempty(minSize) && size(RS, 1) < minSize)
      logMsg(sprintf('%s skipped due to minimum size (%d vs %d)', experiment.name, size(RS, 1), minSize));
      data = NaN;
      return;
    end
    data = computeNetworkStatistic(RS, stat, nSurrogates);
    % If we should normalize the statistic
    if(norm)
      switch stat
        case {'avg comp size', 'largest connected comp', 'louvain avg community size', 'louvain largest community', 'modularity avg community size', 'modularity largest community'}
          data = data/size(RS, 1);
      end
    end
  end
  
end
