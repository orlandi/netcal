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
% Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% PIPELINE
% name: plot network statistics
% parentGroups: network: plots
% optionsClass: plotNetworkStatisticsOptions
% requiredFields: GTE

tmpStat = varargin{1}.statistic;
defClass = plotNetworkStatisticsOptions;
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
    obj = plotStatistics;
    obj.init(projexp, defClass, defTitle, varargin{:}, 'gui', gcbf, 'loadFields', {'GTE', 'GTEunconditioned', 'name'});
    if(obj.getData(@getData, projexp, obj.params.inferenceMeasure, obj.params.statistic, obj.params.confidenceLevelThreshold))
      obj.createFigure();
    end
    obj.cleanup();
    autoArrangeFigures();
  end
else
  obj = plotStatistics;
  obj.init(projexp, defClass, defTitle, varargin{:}, 'gui', gcbf, 'loadFields', {'GTE', 'GTEunconditioned', 'name'});
  if(obj.getData(@getData, projexp, obj.params.inferenceMeasure, obj.params.statistic, obj.params.confidenceLevelThreshold))
    obj.createFigure();
  end
  obj.cleanup();
end

  %------------------------------------------------------------------------
  function data = getData(experiment, groupName, meas, stat, sigLevel)
    %bursts = getExperimentGroupBursts(experiment, groupName, 'spikes');
    [field, idx] = getExperimentGroupCoordinates(experiment, groupName);
    switch meas
      case 'GTE'
        if(~isfield(experiment, 'GTE'))
          experiment.name
          data = NaN;
          return;
        end
        RS = (experiment.GTE.(field){idx}(:, :, 2) > sigLevel);
      case 'GTE unconditioned'
        if(~isfield(experiment, 'GTEunconditioned'))
          experiment.name
          data = NaN;
          return;
        end
        RS = (experiment.GTEunconditioned.(field){idx}(:, :, 2) > sigLevel);
    end
    switch stat
      case 'degree'
        [~, ~, data] = degrees_dir(RS);
      case 'output degree'
        [~, data, ~] = degrees_dir(RS);
      case 'input degree'
        [data, ~, ~] = degrees_dir(RS);
      case 'clustering coefficient'
        data = clustering_coef_bd(RS);
      case  'transitivity'
        data = transitivity_bd(RS);
      case 'assortativity out-in'
        data = assortativity_bin(RS, 1);
      case 'assortativity in-out'
        data = assortativity_bin(RS, 2);
      case 'assortativity out-out'
        data = assortativity_bin(RS, 3);
      case 'assortativity in-in'
        data = assortativity_bin(RS, 4);
      case 'global efficiency'
        data = efficiency_bin(RS, 0);
      case 'local efficiency'
        data = efficiency_bin(RS, 1);
      case 'rich club coeff'
        [data, ~, ~] = rich_club_bd(RS);
      case 'coreness'
        data = double(core_periphery_dir(RS));
      case 'char path length'
        D = distance_bin(RS);
        [data,~,~,~,~] = charpath(D);
      case 'radius'
        D = distance_bin(RS);
        [~,~,~,data,~] = charpath(D);
      case 'diameter'
        D = distance_bin(RS);
        [~,~,~,~,data] = charpath(D);
      case 'eccentricity'
        D = distance_bin(RS);
        [~,~,data,~,~] = charpath(D);
      case 'num connected comp'
        [~,comp_sizes] = get_components(RS);
        valid = comp_sizes > 1;
        data = length(comp_sizes(valid));
      case 'avg comp size'
        [~,comp_sizes] = get_components(RS);
        valid = comp_sizes > 1;
        data = mean(comp_sizes(valid));
      case 'largest connected comp'
        [~,comp_sizes] = get_components(RS);
        data = max(comp_sizes);
      case 'louvain num communities'
        [M,Q]=community_louvain(RS);
        [a,b] = hist(M, 1:max(M));
        valid = find(a > 1);
        data = length(valid);
      case 'louvain avg community size'
        [M,Q]=community_louvain(RS);
        [a,b] = hist(M, 1:max(M));
        valid = find(a > 1);
        data = mean(M(valid));
      case 'louvain community statistic'
        [M,Q]=community_louvain(RS);
        data = Q;
      case 'louvain largest community'
        [M,Q]=community_louvain(RS);
        [a,b] = hist(M, 1:max(M));
        data = max(a);
      case 'modularity num communities'
        [M,Q]=modularity_dir(RS);
        [a,b] = hist(M, 1:max(M));
        valid = find(a > 1);
        data = length(valid);
      case 'modularity avg community size'
        [M,Q]=modularity_dir(RS);
        [a,b] = hist(M, 1:max(M));
        valid = find(a > 1);
        data = mean(M(valid));
      case 'modularity largest community'
        [M,Q]=modularity_dir(RS);
        [a,b] = hist(M, 1:max(M));
        data = max(a);
      case 'modularity statistic'
        [M,Q]=modularity_dir(RS);
        data = Q;
      otherwise
        data = [];
    end
    data = data(:); % Always as a column, just to be sure
  end
end
