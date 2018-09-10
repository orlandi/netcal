function project = plotSpikeTreatmentStatistics(projexp, varargin)
% PLOTSPIKETREATMENTSTATISTICS plots changes in spike statistics between ROIs present in groups of experiments
%
% USAGE:
%    project = plotSpikeTreatmentStatistics(project, varargin)
%
% INPUT arguments:
%    project - project structure
%
% INPUT optional arguments ('key' followed by its value):
%    see plotSpikeTreatmentStatisticsOptions
%
% OUTPUT arguments:
%    project - project structure
%
% EXAMPLE:
%    project = plotSpikeTreatmentStatisticsOptions(project)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% PIPELINE
% name: plot inter-experiment spike statistics
% parentGroups: protocols: inter-experiment: spikes: plots
% optionsClass: plotSpikeTreatmentStatisticsOptions
% requiredFields: spikes

% Pass class options
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(plotSpikeTreatmentStatisticsOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Plotting spike statistics');
%--------------------------------------------------------------------------

% Fix in case for some reason the group is a cell
if(iscell(params.group))
  mainGroup = params.group{1};
else
  mainGroup = params.group;
end

% Check if its a project or an experiment
if(isfield(projexp, 'saveFile'))
  [~, ~, fpc] = fileparts(projexp.saveFile);
  if(strcmpi(fpc, '.exp'))
    mode = 'experiment';
    experiment = projexp;
  else
    mode = 'project';
    project = projexp;
  end
else
  mode = 'project';
  project = projexp;
end

gui = gcbf;

% Create necessary folders
if(params.saveFigure)
  if(strcmpi(mode, 'experiment'))
    switch params.saveBaseFolder
      case 'experiment'
        baseFolder = experiment.folder;
      case 'project'
        baseFolder = [experiment.folder '..' filesep];
    end
  else
    baseFolder = project.folder;
  end
  baseFigName = experiment.name;
  if(~exist(baseFolder, 'dir'))
    mkdir(baseFolder);
  end
  figFolder = [baseFolder 'figures' filesep];
  if(~exist(figFolder, 'dir'))
    mkdir(figFolder);
  end
end

if(params.showFigure)
  visible = 'on';
else
  visible = 'off';
end

maxGroups = 0;
labels = [];
experimentListNames = {};
% Do a first pass to gather all the data
switch mode
  case 'experiment'
    checkedExperiments = find(project.checkedExperiments);
    % Get ALL subgroups in case of parents
    if(strcmpi(mainGroup, 'all'))
      groupList = getExperimentGroupsNames(experiment);
    else
      groupList = getExperimentGroupsNames(experiment, mainGroup);
    end
    plotData = cell(1);
    plotData{1} = cell(length(groupList), 1);
    
    for git = 1:length(groupList)
      % Again, for compatibility reasons
      if(strcmpi(groupList{git}, 'none'))
        groupList{git} = 'everything';
      end
      plotData{1}{git} = getData(experiment, groupList{git}, params.statistic);
      plotData{1}{git}(plotData{1}{git} == 0) = NaN;
    end
    maxGroups = max(maxGroups, length(plotData{1}));
  case 'project'
    checkedExperiments = find(project.checkedExperiments);
    
    plotData = cell(length(checkedExperiments), 1);
    if(params.pbar > 0)
      ncbar.setBarName('Gathering data');
    end
    for i = 1:length(checkedExperiments)
      experimentName = project.experiments{checkedExperiments(i)};
      experimentListNames{end+1} = experimentName;
      experimentFile = [project.folderFiles experimentName '.exp'];
      experiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
      % Get ALL subgroups in case of parents
      if(strcmpi(mainGroup, 'all'))
        groupList = getExperimentGroupsNames(experiment);
      else
        groupList = getExperimentGroupsNames(experiment, mainGroup);
      end
      plotData{i} = cell(length(groupList), 1);
      for git = 1:length(groupList)
        % Again, for compatibility reasons
        if(strcmpi(groupList{git}, 'none'))
          groupList{git} = 'everything';
        end
        plotData{i}{git} = getData(experiment, groupList{git}, params.statistic);
        if(params.zeroToNan)
          plotData{i}{git}(plotData{i}{git} == 0) = NaN;
        end
      end
      maxGroups = max(maxGroups, length(plotData{1}));
      if(params.pbar > 0)
        ncbar.update(i/length(checkedExperiments));
      end
    end
end

expPos = 0;
switch params.groupingOrder
  case 'none'
    % Do nothing
    groupLabels = project.experiments(checkedExperiments);
  case 'label'
    if(isempty(labels))
      labels = project.labels(checkedExperiments);
      experimentOrder = 1:length(labels);
    else
      % Else, the labels were alredy defined and the experiments sorted
    end
    uniqueLabels = unique(labels);
    plotDataAveraged = cell(length(uniqueLabels), 1);
    maxExpPerLabel = -inf;
    maxDataPoints = -inf;
    for it = 1:length(plotDataAveraged)
      plotDataAveraged{it} = cell(maxGroups, 1);
      maxExpPerLabel = max(maxExpPerLabel,length(find(strcmp(labels, uniqueLabels{it}))));
      valid = find(strcmp(labels, uniqueLabels{it}));
      for git = 1:maxGroups
        plotDataAveraged{it}{git} = [];
        for k = 1:length(valid)
          maxDataPoints = max(maxDataPoints, length(plotData{valid(k)}{git}));
        end
      end
    end
    
    plotDataAveraged = nan(maxDataPoints, length(uniqueLabels), maxExpPerLabel);
    
    for it = 1:length(uniqueLabels)
      valid = find(strcmp(labels, uniqueLabels{it}));
      expPos = [expPos; length(valid)];
      for git = 1:maxGroups
        for k = 1:length(valid)
          %plotDataAveraged{it}{git} = [plotDataAveraged{it}{git}; plotData{valid(k)}{git}(:)];
          plotDataAveraged(1:length(plotData{valid(k)}{git}), it, k) = plotData{valid(k)}{git};
        end
      end
    end
    plotData = plotDataAveraged;
    expPos = cumsum(expPos);
    expPos = expPos(1:end-1);
    groupLabels = uniqueLabels;
  case 'label average'
    % Average statistics for each experiment, and group them by label
    if(isempty(labels))
      labels = project.labels(checkedExperiments);
      experimentOrder = 1:length(labels);
    else
      % Else, the labels were alredy defined and the experiments sorted
    end
    uniqueLabels = unique(labels);
    plotDataAveraged = cell(length(uniqueLabels), 1);
    switch params.factor
      case 'experiment'
        for it = 1:length(plotDataAveraged)
          plotDataAveraged{it} = cell(maxGroups, 1);
          valid = find(strcmp(labels, uniqueLabels{it}));
          for git = 1:maxGroups
            plotDataAveraged{it}{git} = zeros(length(valid), 1);
            for k = 1:length(valid)
              plotDataAveraged{it}{git}(k) = nanmean(plotData{valid(k)}{git});
            end
          end
        end
      case 'ROI'
        for it = 1:length(plotDataAveraged)
          plotDataAveraged{it} = cell(maxGroups, 1);
          valid = find(strcmp(labels, uniqueLabels{it}));
          for git = 1:maxGroups
            plotDataAveraged{it}{git} = [];
            for k = 1:length(valid)
              plotDataAveraged{it}{git} = [plotDataAveraged{it}{git}; plotData{valid(k)}{git}(:)];
            end
          end
        end
    end
    plotData = plotDataAveraged;
    groupLabels = uniqueLabels;
end
% Now that we have all the data stored, let's plot it 
if(params.pbar > 0)
  ncbar.setBarName('Plotting spike statistics');
end

hFig = figure('Name', [params.statistic], 'NumberTitle', 'off', 'Visible', visible);
%hFig.Position(3:4) = params.figureSize;
hFig.Position = setFigurePosition(gui, 'width', params.figureSize(1), 'height', params.figureSize(2));
ax = axes;
hold on;

gap = 1;
rowData = [];
groupData = [];
%plotData
%size(plotData)
switch params.groupingOrder
  case 'label'
    import iosr.statistics.*
    bpData = plotData;
    %nanmean(bpData(:, 4, :), 1)
    %experimentListNames(experimentOrder)
    h = boxPlot((0:(size(bpData,2)-1))*size(bpData,3), bpData, ...
                      'symbolColor','k',...
                      'medianColor','k',...
                      'symbolMarker','+',...
                      'showLegend',false, ...
                      'showOutliers', false, ...
                      'xseparator',true,...
                      'rescaleGroups', true, ...
                      'groupLabels', groupLabels, ...
                      'boxcolor', str2func(params.colormap));
    set(gca, 'XTickLabel', groupLabels);
    %set(gca, 'XTick', 1:length(experimentListNames));
    %set(gca, 'XTickLabel', experimentListNames(experimentOrder));
    
    ylabel(gca, [params.statistic]);
  otherwise
    for rt = 1:maxGroups
      for kr = 1:size(plotData, 1)
        if(isempty(plotData{kr}) || isempty(plotData{kr}{rt}))
            rowData = [rowData; NaN];
            groupData = [groupData; kr];
        else
            rowData = [rowData; plotData{kr}{rt}(:)];
            %groupData = [groupData; ones(size(plotData{kr}{rt}(:)))*(kr + gap*size(plotData, 1)*(rt-1))];
            groupData = [groupData; ones(size(plotData{kr}{rt}(:)))*((kr-1)*(maxGroups+gap) + rt)];
        end
      end
    end
    % Turn into an array now
    maxData = length(rowData);

    bpData = nan(maxData, maxGroups, size(plotData, 1));
    for rt = 1:maxGroups
      for kr = 1:size(plotData, 1)
          bpData(1:length(plotData{kr}{rt}), rt, kr) = plotData{kr}{rt};
      end
    end

    import iosr.statistics.*
    %h = notBoxPlotv2(rowData, groupData);
    %[Y, X] = tab2box(groupData, rowData);

    bpData = permute(bpData,[1 3 2]);
    
    h = boxPlot(groupLabels, bpData, ...
       'symbolColor','k',...
                      'medianColor','k',...
                      'symbolMarker','+',...
                      'showLegend',false, ...
                      'showOutliers', false, ...
                      'boxcolor', str2func(params.colormap));
                      %'groupLabels', groupLabels);
    %set(gca,'XTickLabels', groupList);
end
setappdata(hFig, 'boxData', h);

  
title(ax, [params.statistic]);
set(gcf,'Color','w');

box on;
ui = uimenu(hFig, 'Label', 'Export');
uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf';'*.eps'; '*.tiff'; '*.png'}, [experiment.folder experiment.name '_' params.statistic]});
uimenu(ui, 'Label', 'Data statistics',  'Callback', @exportDataAggregates);
uimenu(ui, 'Label', 'Data full',  'Callback', @exportDataFull);
uimenu(ui, 'Label', 'To workspace',  'Callback', @exportToWorkspace);

if(params.saveFigure)
  export_fig([figFolder, baseFigName, '_', params.statistic, params.saveFigureTag, '.', params.saveFigureType], ...
              sprintf('-r%d', params.saveFigureResolution), ...
              sprintf('-q%d', params.saveFigureQuality), hFig);
end

if(~params.showFigure)
  close(hFig);
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

function exportToWorkspace(~, ~)
  assignin('base', 'boxPlotData', h);
  if(~isempty(gui))
    logMsg('boxPlotData data succesfully exported to the workspace. Modify its components to modify the figure', gui, 'w');
  else
    logMsg('boxPlotData data succesfully exported to the workspace. Modify its components to modify the figure', 'w');
  end
end

function exportDataAggregates(~, ~)
  [fileName, pathName] = uiputfile('.csv', 'Save data', [project.folder filesep 'data' filesep params.statistic ' Aggregates.csv']);
  if(fileName == 0)
    return;
  end
  fID = fopen([pathName fileName], 'w');
  names = {'label', 'median', 'mean', 'std', 'N', 'Q1', 'Q3', 'IQR', 'min', 'max'};
  lineStr = [sprintf('%s,',names{1:end-1}), sprintf('%s',names{end}), sprintf('\n')];
  fprintf(fID, lineStr);
  % Data (everything turned into doubles)
  data = h.statistics;
  for it = 1:size(bpData, 2)
    lineStr = sprintf('%s, %.3f, %.3f, %.3f, %d, %.3f, %.3f, %.3f, %.3f, %.3f\n', groupLabels{it}, data.median(it), data.mean(it), data.std(it), data.N(it), data.Q1(it), data.Q3(it), data.IQR(it), data.min(it), data.max(it));
    fprintf(fID, lineStr);
  end
  fclose(fID);
end

function exportDataFull(~, ~)
  [fileName, pathName] = uiputfile('.csv', 'Save data', [project.folder filesep 'data' filesep params.statistic ' Full.csv']);
  if(fileName == 0)
    return;
  end
  fID = fopen([pathName fileName], 'w');
  names = groupLabels;
  lineStr = [sprintf('%s,',names{1:end-1}), sprintf('%s',names{end}), sprintf('\n')];
  fprintf(fID, lineStr);
  % Data (everything turned into doubles)
  data = h.statistics;
  for it = 1:size(bpData, 1)
    subData = bpData(it, :);
    if(all(isnan(subData)))
      break;
    end
    lineStr = [sprintf('%.3f,',subData(1:end-1)), sprintf('%.3f',subData(end)), sprintf('\n')];
    fprintf(fID, lineStr);
  end
  fclose(fID);
end

function data = getData(experiment, groupName, stat)
  members = getExperimentGroupMembers(experiment, groupName);
  if(~isempty(members))
    selectedStatistic = strcmp(experiment.spikeFeaturesNames, stat);
    data = experiment.spikeFeatures(members, selectedStatistic);
  end
end

end