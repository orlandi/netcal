function projexp = plotSchmittSpikesStatistics(projexp, varargin)
% PLOTSCHMITTSPIKESSTATISTICS Plot schmitt spikes statistics
% Plots statistics associated to schmitt spikes inference
%
% USAGE:
%    projexp = plotSchmittSpikesStatistics(projexp, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see plotSchmittSpikesStatisticsOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = plotSchmittSpikesStatistics(experiment)
%    project = plotSchmittSpikesStatistics(project)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% PIPELINE
% name: plot schmitt spike statistics
% parentGroups: spikes: plots, statistics: spikes
% optionsClass: plotSchmittSpikesStatisticsOptions
% requiredFields: schmittSpikesData

tmpStat = varargin{1}.statistic;
defClass = plotSchmittSpikesStatisticsOptions;
defTitle = 'Plotting schmitt inference statistics';
if(strcmpi(tmpStat, 'all'))
  statList = defClass.setExperimentDefaults([]).statistic;
  statList = statList(1:end-1);
  for it = 1:length(statList)
    logMsg(sprintf('Plotting schmitt inference statistics for: %s', statList{it}));
    varargin{1}.statistic = statList{it};
    obj = plotStatistics;
    obj.init(projexp, defClass, defTitle, varargin{:}, 'gui', gcbf, 'loadFields', {'schmittSpikesData'});
    if(obj.getData(@getData, projexp, obj.params.statistic, obj.params.type))
      obj.createFigure();
    end
    obj.cleanup();
  end
else
  obj = plotStatistics;
  obj.init(projexp, defClass, defTitle, varargin{:}, 'gui', gcbf, 'loadFields', {'schmittSpikesData'});
  if(obj.getData(@getData, projexp, obj.params.statistic, obj.params.type))
    obj.createFigure();
  end
  obj.cleanup();
end
  %------------------------------------------------------------------------
  function data = getData(experiment, groupName, stat, type)
    % For now it's independent on the group
    %members = getExperimentGroupMembers(experiment, groupName);
    if(~isempty(type) && ischar(type))
      type = str2double(type);
    end
    members = getExperimentGroupMembers(experiment, groupName);
    
    if(~isempty(members))
      switch stat
        case 'duration'
          if(~isempty(type))
            valid = find(cellfun(@(x)isfield(x,'type'),experiment.schmittSpikesData(members)));
            data = cell2mat(cellfun(@(x)x.duration(x.type == type), experiment.schmittSpikesData(members(valid)),'UniformOutput',false));
          else
            data = cell2mat(cellfun(@(x)x.duration, experiment.schmittSpikesData(members),'UniformOutput',false));
          end
        case 'amplitude'
          if(~isempty(type))
            valid = find(cellfun(@(x)isfield(x,'type'),experiment.schmittSpikesData(members)));
            data = cell2mat(cellfun(@(x)x.amplitude(x.type == type), experiment.schmittSpikesData(members(valid)),'UniformOutput',false));
          else
            data = cell2mat(cellfun(@(x)x.amplitude, experiment.schmittSpikesData(members),'UniformOutput',false));
          end
        case 'area'
          if(~isempty(type))
            valid = find(cellfun(@(x)isfield(x,'type'),experiment.schmittSpikesData(members)));
            data = cell2mat(cellfun(@(x)x.area(x.type == type), experiment.schmittSpikesData(members(valid)),'UniformOutput',false));
          else
            data = cell2mat(cellfun(@(x)x.area, experiment.schmittSpikesData(members),'UniformOutput',false));
          end
        otherwise
          data = [];
      end
      data = data(:); % Always as a column, just to be sure
    else
      data = [];
    end
  end
end