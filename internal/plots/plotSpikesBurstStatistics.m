function projexp = plotSpikesBurstStatistics(projexp, varargin)
% plotSpikesBurstStatistics # Plot spikes burst statistics
% Plots statistics associated to spikes (global) bursts: amplitude, duration, IBI
%
% USAGE:
%    projexp = plotSpikesBurstStatistics(projexp, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see plotFluorescenceBurstStatisticsOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = plotSpikesBurstStatistics(experiment)
%    project = plotSpikesBurstStatistics(project)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% PIPELINE
% name: plot burst statistics
% parentGroups: spikes: bursts: plots
% optionsClass: plotSpikesBurstStatisticsOptions
% requiredFields: spikeBursts

tmpStat = varargin{1}.statistic;
defClass = plotSpikesBurstStatisticsOptions;
defTitle = 'Plotting spike burst statistics';
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
    obj.init(projexp, defClass, defTitle, varargin{:}, 'gui', gcbf, 'loadFields', {'spikeBursts','t','totalTime'});
    if(obj.getData(@getData, projexp, obj.params.statistic))
      obj.createFigure();
    end
    obj.cleanup();
    autoArrangeFigures();
  end
else
  obj = plotStatistics;
  obj.init(projexp, defClass, defTitle, varargin{:}, 'gui', gcbf, 'loadFields', {'spikeBursts','t','totalTime'});
  if(obj.getData(@getData, projexp, obj.params.statistic))
    obj.createFigure();
  end
  obj.cleanup();
end

% if(strcmpi(tmpStat, 'all'))
%   statList = defClass.setExperimentDefaults([]).statistic;
%   statList = statList(1:end-1);
%   for it = 1:length(statList)
%     logMsg(sprintf('Plotting burst statistics for: %s', statList{it}));
%     varargin{1}.statistic = statList{it};
%     obj = plotStatistics;
%     obj.init(projexp, defClass, defTitle, varargin{:}, 'gui', gcbf, 'loadFields', {'spikeBursts','t','totalTime'});
%     if(obj.getData(@getData, projexp, obj.params.statistic))
%       obj.createFigure();
%     end
%     obj.cleanup();
%   end
%   
% else
%   obj = plotStatistics;
%   obj.init(projexp, defClass, defTitle, varargin{:}, 'gui', gcbf, 'loadFields', {'spikeBursts','t','totalTime'});
%   if(obj.getData(@getData, projexp, obj.params.statistic))
%     obj.createFigure();
%   end
%   obj.cleanup();
% end
  %------------------------------------------------------------------------
  function data = getData(experiment, groupName, stat)
    bursts = getExperimentGroupBursts(experiment, groupName, 'spikes');
    if(~isempty(bursts))
      % Only a single burstRate
      switch stat
        case 'bursting rate'
          try
            data = length(bursts.amplitude)/(experiment.t(end)-experiment.t(1));
          catch
            data = length(bursts.amplitude)/experiment.totalTime;
          end
        case 'bursting rate high'
          [members, ~, ~] = getExperimentGroupMembers(experiment, groupName);
          data = cellfun(@length, bursts.participators)/length(members);
          valid = find(data >= 0.2);
          data = length(valid)/(experiment.t(end)-experiment.t(1));
          if(isempty(data))
            data = 0;
          end
        case 'bursting rate low'
          [members, ~, ~] = getExperimentGroupMembers(experiment, groupName);
          data = cellfun(@length, bursts.participators)/length(members);
          valid = find(data < 0.2);
          data = length(valid)/(experiment.t(end)-experiment.t(1));
          if(isempty(data))
            data = 0;
          end
        case 'IBI CV'
          data = nanstd(bursts.IBI)/nanmean(bursts.IBI);
        case 'num spikes'
          data = bursts.amplitude;
        case 'num participating cells'
          data = cellfun(@length, bursts.participators);
        case 'ratio participating cells'
          [members, ~, ~] = getExperimentGroupMembers(experiment, groupName);
          data = cellfun(@length, bursts.participators)/length(members);
          %data = bursts.participators/length(members);
        case 'num spikes per group member'
          [members, ~, ~] = getExperimentGroupMembers(experiment, groupName);
          data = bursts.amplitude/length(members);
        case 'burstiness'
          if(~isempty(bursts.amplitude) && length(bursts.amplitude) > 1)
            data = 1;
          else
            data = 0;
          end
        otherwise
          data = bursts.(stat);
      end
      data = data(:); % Always as a column, just to be sure
    else
      switch stat
        case 'burstiness'
          data = 0;
        otherwise
          data = [];
      end
    end
  end

end