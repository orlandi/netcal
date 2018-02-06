classdef plotStatistics < handle
% Main class to plot any one-dimensional statistic. Taking into account projects, experiments, labels, groups, etc
%
%   Copyright (C) 2016-2017, Javier G. Orlandi
  
  properties
    figureHandle;
    axisHandle;
    fullStatisticsData;
    statisticsName;
    labelList;
    mainGroup;
    mode;
    params; % Set at init
    guiHandle; % Set at init
    figName;
    figVisible;
    groupList;
    plotHandles;
    maxGroups;
    experiementNames;
    groupLabels;
    fullGroupList;
    exportFolder;
    figFolder;
  end
  
  methods
    % Use this function to setup the statistics data
    %----------------------------------------------------------------------
    function success = getData(obj, funcHandle, projexp, varargin)
      success = false;
      if(isempty(obj.params.styleOptions.figureTitle))
        obj.figName = [obj.params.statistic ' - ' projexp.name obj.params.saveOptions.saveFigureTag];
      else
        obj.figName = obj.params.styleOptions.figureTitle;
      end
      obj.figName = strrep(obj.figName, '_', '-');
      switch obj.mode
        case 'project'
          success = getDataProject(obj, funcHandle, projexp, varargin{:});
        case 'experiment'
          success = getDataExperiment(obj, funcHandle, projexp, varargin{:});
      end
    end
    
    %----------------------------------------------------------------------
    function success = getDataExperiment(obj, funcHandle, experiment, varargin)
      success = true;
      obj.fullStatisticsData = {};
      
      % Get ALL subgroups in case of parents
      if(strcmpi(obj.mainGroup, 'all') || strcmpi(obj.mainGroup, 'ask'))
        obj.groupList = getExperimentGroupsNames(experiment);
      else
        obj.groupList = getExperimentGroupsNames(experiment, obj.mainGroup);
      end
      % If ask, open the popup
      if(strcmpi(obj.mainGroup, 'ask'))
        [selection, ok] = listdlg('PromptString', 'Select groups to use', 'ListString', obj.groupList, 'SelectionMode', 'multiple');
        if(~ok)
          success = false;
          return;
        end
        obj.groupList = obj.groupList(selection);
      end
      for git = 1:length(obj.groupList)
        % Again, for compatibility reasons
        if(strcmpi(obj.groupList{git}, 'none'))
          obj.groupList{git} = 'everything';
        end
        % Here is where we obtain the data
        obj.fullStatisticsData{git} = feval(funcHandle, experiment, obj.groupList{git}, varargin{:});

        % Eliminate NaNs
        if(obj.params.zeroToNan)
          obj.fullStatisticsData{git} = obj.fullStatisticsData{git}(~isnan(obj.fullStatisticsData{git}));
        end
        if(isempty(obj.fullStatisticsData))
          logMsg(sprintf('Found no data for group %s on experiment %s', obj.groupList{git}, experiment.name), obj.gui, 'w');
          continue;
        end
      end
    end
    
    %----------------------------------------------------------------------
    function success = getDataProject(obj, funcHandle, project, varargin)
      success = true;
      obj.fullStatisticsData = {};
      checkedExperiments = find(project.checkedExperiments);
      
      plotData = cell(length(checkedExperiments), 1);
      if(obj.params.pbar > 0)
        ncbar.setBarName('Gathering data');
      end
      
      obj.maxGroups = 0;
      %%% First pass to gather all groups names
      for i = 1:length(checkedExperiments)
        experimentName = project.experiments{checkedExperiments(i)};
        experimentFile = [project.folderFiles experimentName '.exp'];
        experiment = load(experimentFile, '-mat', 'traceGroups', 'traceGroupsNames');
        % Get ALL subgroups in case of parents
        if(strcmpi(obj.mainGroup, 'all') || strcmpi(obj.mainGroup, 'ask'))
          obj.groupList = getExperimentGroupsNames(experiment);
        else
          obj.groupList = getExperimentGroupsNames(experiment, obj.mainGroup);
        end
        obj.fullGroupList = unique([obj.fullGroupList(:); obj.groupList(:)]);
      end
      % If ask, open the popup
      if(strcmpi(obj.mainGroup, 'ask'))
        [selection, ok] = listdlg('PromptString', 'Select groups to use', 'ListString', obj.fullGroupList, 'SelectionMode', 'multiple');
        if(~ok)
          success = false;
          return;
        end
        obj.fullGroupList = obj.fullGroupList(selection);
      end
      %%% Gather the data
      for i = 1:length(checkedExperiments)
        experimentName = project.experiments{checkedExperiments(i)};
        experimentFile = [project.folderFiles experimentName '.exp'];
        experiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
        % Get ALL subgroups in case of parents
        if(strcmpi(obj.mainGroup, 'all')  || strcmpi(obj.mainGroup, 'ask'))
          obj.groupList = getExperimentGroupsNames(experiment);
        else
          obj.groupList = getExperimentGroupsNames(experiment, obj.mainGroup);
        end
        plotData{i} = cell(length(obj.fullGroupList), 1);
        for git = 1:length(obj.groupList)
          groupIdx = find(strcmp(obj.groupList{git}, obj.fullGroupList));
          if(isempty(groupIdx))
            continue;
          end
          % Again, for compatibility reasons
          if(strcmpi(obj.groupList{git}, 'none'))
            obj.groupList{git} = 'everything';
          end
          %plotData{i}{git} = getData(experiment, obj.groupList{git}, obj.params.statistic);
          plotData{i}{groupIdx} = feval(funcHandle, experiment, obj.groupList{git}, varargin{:});
          if(obj.params.zeroToNan)
            plotData{i}{groupIdx}(plotData{i}{groupIdx} == 0) = NaN;
          end
        end
        obj.maxGroups = max(obj.maxGroups, length(plotData{i}));
        if(obj.params.pbar > 0)
          ncbar.update(i/length(checkedExperiments));
        end
      end
      
      %%% Get the labels we need
      [labelList, uniqueLabels, labelsCombinations, labelsCombinationsNames, experimentsPerCombinedLabel] = getLabelList(project, find(project.checkedExperiments));

      labelsToUse = obj.params.pipelineProject.labelGroups;
      labelsToUseJoined = cell(length(labelsToUse), 1);
      try
        if(isempty([obj.params.pipelineProject.labelGroups{:}]))
          emptyLabels = true;
          labelsToUseJoined = uniqueLabels;
        else
          for it = 1:length(obj.params.pipelineProject.labelGroups)
            labelsToUseJoined{it} = strjoin(sort(strtrim(strsplit(obj.params.pipelineProject.labelGroups{it}, ','))), ', ');
          end
        end
      catch
        emptyLabels = true;
        labelsToUseJoined = uniqueLabels;
      end
      validCombinations = cellfun(@(x)find(strcmp(labelsCombinationsNames, x)), labelsToUseJoined, 'UniformOutput', false);
      valid = find(cellfun(@(x)~isempty(x), validCombinations));
      if(length(valid) ~= length(validCombinations))
        logMsg('Some label sets had no representative experiments', 'w');
      end
      validCombinations = cell2mat(validCombinations(valid));
      labelsToUseJoined = labelsToUseJoined(valid);
      
      %%% Average the data as needed
      expPos = 0;
      switch obj.params.pipelineProject.groupingOrder
        case 'none'
          % Do nothing
          obj.groupLabels = project.experiments(checkedExperiments);
        case 'label'
          plotDataAveraged = cell(length(validCombinations), 1);
          maxExpPerLabel = -inf;
          maxDataPoints = -inf;
          for it = 1:length(validCombinations)
            plotDataAveraged{it} = cell(obj.maxGroups, 1);
            maxExpPerLabel = max(maxExpPerLabel,length(experimentsPerCombinedLabel{validCombinations(it)}));
            valid = [experimentsPerCombinedLabel{validCombinations(it)}{:}];
            for git = 1:obj.maxGroups
              plotDataAveraged{it}{git} = [];
              for k = 1:length(valid)
                if(length(valid) >= k && length(plotData) >= valid(k) && length(plotData{valid(k)}) >= git)
                  maxDataPoints = max(maxDataPoints, length(plotData{valid(k)}{git}));
                end
              end
            end
          end
          plotDataAveraged = nan(maxDataPoints, length(validCombinations), maxExpPerLabel);

          for it = 1:length(validCombinations)
            valid = [experimentsPerCombinedLabel{validCombinations(it)}{:}];
            expPos = [expPos; length(valid)];
            for git = 1:obj.maxGroups
              for k = 1:length(valid)
                if(length(plotData) >= valid(k) && length(plotData{valid(k)}) >= git)
                  plotDataAveraged(1:length(plotData{valid(k)}{git}), it, k) = plotData{valid(k)}{git};
                end
              end
            end
          end
          plotData = plotDataAveraged;
          
          expPos = cumsum(expPos);
          expPos = expPos(1:end-1);
          obj.groupLabels = labelsToUseJoined;
        case 'label average'
          % Average statistics for each experiment, and group them by label
          plotDataAveraged = cell(length(validCombinations), 1);
          switch obj.params.pipelineProject.factor
            case 'experiment'
              for it = 1:length(validCombinations)
                plotDataAveraged{it} = cell(obj.maxGroups, 1);
                valid = [experimentsPerCombinedLabel{validCombinations(it)}{:}];
                valid2 = arrayfun(@(x)find(x==checkedExperiments), valid, 'UniformOutput', false);
                valid2 = cell2mat(valid2);
                valid = valid2;
                for git = 1:obj.maxGroups
                  plotDataAveraged{it}{git} = zeros(length(valid), 1);
                  for k = 1:length(valid)
                    try
                      switch obj.params.pipelineProject.factorAverageFunction
                        case 'mean'
                          plotDataAveraged{it}{git}(k) = nanmean(plotData{valid(k)}{git});
                        case 'median'
                          plotDataAveraged{it}{git}(k) = nanmedian(plotData{valid(k)}{git});
                      end
                    catch
                    end
                  end
                end
              end
            case 'event'
              for it = 1:length(validCombinations)
                plotDataAveraged{it} = cell(obj.maxGroups, 1);
                valid = [experimentsPerCombinedLabel{validCombinations(it)}{:}];
                valid2 = arrayfun(@(x)find(x==checkedExperiments), valid, 'UniformOutput', false);
                valid2 = cell2mat(valid2);
                valid = valid2;
                for git = 1:obj.maxGroups
                  plotDataAveraged{it}{git} = [];
                  for k = 1:length(valid)
                    if(length(plotData) >= valid(k) && length(plotData{valid(k)}) >= git)
                      plotDataAveraged{it}{git} = [plotDataAveraged{it}{git}; plotData{valid(k)}{git}(:)];
                    end
                  end
                end
              end
          end
          plotData = plotDataAveraged;
          obj.groupLabels = labelsToUseJoined;
      end

      obj.fullStatisticsData = plotData;
    end
    
    %----------------------------------------------------------------------
    function createFigure(obj)
      switch obj.mode
        case 'experiment'
          obj.createFigureExperiment();
        case 'project'
          obj.createFigureProject();
      end
    end
    
    %----------------------------------------------------------------------
    function createFigureExperiment(obj)
      obj.plotHandles = [];
      
      if(obj.params.saveOptions.onlySaveFigure)
        obj.figVisible = 'off';
      else
        obj.figVisible = 'on';
      end
      obj.figureHandle = figure('Name', obj.figName, 'NumberTitle', 'off', 'Visible', obj.figVisible, 'Tag', 'netcalPlot');
      %obj.figureHandle.Position = setFigurePosition(obj.guiHandle, 'width', obj.params.styleOptions.figureSize(1), 'height', obj.params.styleOptions.figureSize(2));
      obj.figureHandle.Position = setFigurePosition(gcf, 'width', obj.params.styleOptions.figureSize(1), 'height', obj.params.styleOptions.figureSize(2));
      obj.axisHandle = axes;
      hold on;
      
      if(isempty(obj.params.styleOptions.xLabel))
        xlabel(obj.params.statistic);
      else
        xlabel(obj.params.styleOptions.xLabel);
      end
      if(isempty(obj.params.styleOptions.yLabel))
        ylabel('PDF');
      else
        ylabel(obj.params.styleOptions.yLabel);
      end
      
      if(isfield(obj.params.styleOptions, 'colormap') && ~isempty(obj.params.styleOptions.colormap))
        cmap = eval(sprintf('%s (%d)', obj.params.styleOptions.colormap, length(obj.groupList)));
      else
        cmap = lines(length(obj.groupList));
      end
      if(obj.params.styleOptions.invertColormap)
        if(size(cmap, 1) == 1)
          % If the colormap has a single entry we need to add another entry
          if(isfield(obj.params.styleOptions, 'colormap') && ~isempty(obj.params.styleOptions.colormap))
            cmap = eval(sprintf('%s (%d)', obj.params.styleOptions.colormap, length(obj.groupList)+1));
          else
            cmap = lines(length(obj.groupList)+1);
          end
          cmap = cmap(end:-1:1, :);
        else
          % Default behavior
          cmap = cmap(end:-1:1, :);
        end
      end
      if(length(obj.groupList) > 1)
        alpha = 0.5;
      else
        alpha = 1;
      end
      validGroups = [];
      for git = 1:length(obj.groupList)
        curData = obj.fullStatisticsData{git};
        if(isempty(curData))
          logMsg(sprintf('No data found for group: %s', obj.groupList{git}), obj.guiHandle, 'w');
          continue;
        else
          validGroups = [validGroups, git];
        end
        switch obj.params.pipelineExperiment.distributionEstimation
          case 'unbounded'
            [f, xi] = ksdensity(curData);
             h = plot(xi, f, 'Color', cmap(git, :));
          case 'positive'
            [f, xi] = ksdensity(curData, 'support', 'positive');
            h = plot(xi, f, 'Color', cmap(git, :));
          case 'histogram'
            if(isempty(obj.params.pipelineExperiment.distributionBins) || (~ischar(obj.params.pipelineExperiment.distributionBins) && obj.params.pipelineExperiment.distributionBins == 0))
              try
                bins = sshist(curData);
              catch
                bins = 10;
              end
            elseif(ischar(obj.params.pipelineExperiment.distributionBins))
              bins = eval(obj.params.pipelineExperiment.distributionBins);
              if(bins == 0)
                try
                  bins = sshist(curData);
                catch
                  bins = 10;
                end
              end
            else
              bins = obj.params.pipelineExperiment.distributionBins;
            end
            
            [f, xi] = hist(curData, bins);
            % Now normalize the histogram
            area = trapz(xi, f);
            f = f/area;
            h = bar(xi, f/area, 'FaceColor', cmap(git, :), 'EdgeColor', cmap(git, :)*0.5, 'FaceAlpha', alpha, 'EdgeAlpha', alpha);
          case 'raw'
            if(isempty(obj.params.pipelineExperiment.distributionBins) || (~ischar(obj.params.pipelineExperiment.distributionBins) && obj.params.pipelineExperiment.distributionBins == 0))
              try
                bins = sshist(curData);
              catch
                bins = 10;
              end
            elseif(ischar(obj.params.pipelineExperiment.distributionBins))
              bins = eval(obj.params.pipelineExperiment.distributionBins);
              if(bins == 0)
                try
                  bins = sshist(curData);
                catch
                  bins = 10;
                end
              end
            else
              bins = obj.params.pipelineExperiment.distributionBins;
            end
            [f, xi] = hist(curData, bins);
            h = bar(xi, f, 'FaceColor', cmap(git, :), 'EdgeColor', cmap(git, :)*0.5, 'FaceAlpha', alpha, 'EdgeAlpha', alpha);
            if(isempty(obj.params.styleOptions.yLabel))
              ylabel('count');
            else
              ylabel(obj.params.styleOptions.yLabel);
            end
        end
        obj.plotHandles = [obj.plotHandles; h];
      end
      legend(obj.groupList(validGroups))
      title(obj.axisHandle, obj.figName);
      set(obj.axisHandle, 'XTickLabelRotation', obj.params.styleOptions.XTickLabelRotation);
      set(obj.axisHandle, 'YTickLabelRotation', obj.params.styleOptions.YTickLabelRotation);
      box on;
      set(obj.axisHandle,'Color','w');
      set(obj.figureHandle,'Color','w');
      ui = uimenu(obj.figureHandle, 'Label', 'Export');
      uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf';'*.eps'; '*.tiff'; '*.png'}, strrep([obj.figFolder, obj.figName], ' - ', '_'), obj.params.saveOptions.saveFigureResolution});
      
      if(obj.params.saveOptions.saveFigure)
        export_fig([obj.figFolder, obj.figName, '.', obj.params.saveOptions.saveFigureType], ...
                    sprintf('-r%d', obj.params.saveOptions.saveFigureResolution), ...
                    sprintf('-q%d', obj.params.saveOptions.saveFigureQuality), obj.figureHandle);
      end
    end
    
    %----------------------------------------------------------------------
    function createFigureProject(obj)
      curData = obj.fullStatisticsData;
      if(obj.params.saveOptions.onlySaveFigure)
        obj.figVisible = 'off';
      else
        obj.figVisible = 'on';
      end
      %prevFig = gcf;
      obj.figureHandle = figure('Name', obj.figName, 'NumberTitle', 'off', 'Visible', obj.figVisible, 'Tag', 'netcalPlot');
      %obj.figureHandle.Position = setFigurePosition(obj.guiHandle, 'width', obj.params.styleOptions.figureSize(1), 'height', obj.params.styleOptions.figureSize(2));
      obj.figureHandle.Position = setFigurePosition(obj.guiHandle, 'width', obj.params.styleOptions.figureSize(1), 'height', obj.params.styleOptions.figureSize(2));
      obj.axisHandle = axes;
      hold on;

      gap = 1;
      rowData = [];
      groupData = [];

      switch obj.params.pipelineProject.groupingOrder
        % Label doesn't exist anymore
        case 'label'
%           import iosr.statistics.*
%           bpData = curData;
% %           (0:(size(bpData,2)-1))*size(bpData,3)
% %           size(bpData)
%           obj.plotHandles = boxPlot((0:(size(bpData,2)-1))*size(bpData,3), bpData, ...
%                             'symbolColor','k',...
%                             'medianColor','k',...
%                             'symbolMarker','+',...
%                             'showLegend',false, ...
%                             'showOutliers', false, ...
%                             'xseparator',true,...
%                             'rescaleGroups', true, ...
%                             'boxcolor', cmap);
% 
%           ylabel(gca, [obj.params.statistic]);
        otherwise
          for rt = 1:obj.maxGroups
            for kr = 1:size(curData, 1)
              if(isempty(curData{kr}) || length(curData{kr}) < rt || isempty(curData{kr}{rt}))
                  rowData = [rowData; NaN];
                  groupData = [groupData; kr];
              else
                  rowData = [rowData; curData{kr}{rt}(:)];
                  groupData = [groupData; ones(size(curData{kr}{rt}(:)))*((kr-1)*(obj.maxGroups+gap) + rt)];
              end
            end
          end
          % Turn into an array now
          maxData = length(rowData);

          bpData = nan(maxData, obj.maxGroups, size(curData, 1));
          for rt = 1:obj.maxGroups
            for kr = 1:size(curData, 1)
              if(length(curData{kr}) >= rt)
                bpData(1:length(curData{kr}{rt}), rt, kr) = curData{kr}{rt};
              end
            end
          end
          
          import iosr.statistics.*

          switch obj.params.pipelineProject.barGroupingOrder
            case 'default'
              subData = permute(bpData,[1 3 2]);
              xList = obj.groupLabels;
              legendList = obj.fullGroupList;
              if(~iscell(legendList) || (iscell(legendList) && length(legendList) == 1))
                legendList = {legendList};
              end
            case 'group'
              subData = permute(bpData,[1 2 3]);
              legendList = obj.groupLabels;
              xList= obj.fullGroupList;
          end
          if(isfield(obj.params.styleOptions, 'colormap') && ~isempty(obj.params.styleOptions.colormap))
            cmap = eval(sprintf('%s (%d)', obj.params.styleOptions.colormap, length(legendList)));
          else
            cmap = lines(length(legendList));
          end
          if(obj.params.styleOptions.invertColormap)
            if(size(cmap, 1) == 1)
              % If the colormap has a single entry we need to add another entry
              if(isfield(obj.params.styleOptions, 'colormap') && ~isempty(obj.params.styleOptions.colormap))
                cmap = eval(sprintf('%s (%d)', obj.params.styleOptions.colormap, 2));
              else
                cmap = lines(2);
              end
              cmap = cmap(2, :);
            else
              % Default behavior
              cmap = cmap(end:-1:1, :);
            end
          end
          obj.fullGroupList = {obj.fullGroupList};
          grList = {};
          pList = [];
          switch obj.params.pipelineProject.showSignificance
            case 'none'
            case 'partial'
              for it = 1:size(subData, 2)
                for itt = 1:size(subData, 2)
                  if(it > itt)
                    try
                      p = ranksum(subData(:, it), subData(:, itt));
                      [h, p2] = kstest2(subData(:, it), subData(:, itt));
                      logMsg(sprintf('%s vs %s . Mann-Whitney U test P= %.3g - Kolmogorov-Smirnov test P= %.3g', xList{it}, xList{itt}, p, p2));
                      switch obj.params.pipelineProject.significanceTest
                        case 'Mann-Whitney'
                          if(p <= 0.05)
                            pList = [pList; p];
                            grList{end+1} = [it itt];
                          end
                        case 'Kolmogorov-Smirnov'
                          if(p <= 0.05)
                            pList = [pList; p2];
                            grList{end+1} = [it itt];
                          end
                      end
                    catch ME
                      logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'w');
                    end
                  end
                end
              end
            case 'all'
              for it = 1:size(subData, 2)
                for itt = 1:size(subData, 2)
                  if(it > itt)
                    p = ranksum(subData(:, it), subData(:, itt));
                    [h, p2] = kstest2(subData(:, it), subData(:, itt));
                    logMsg(sprintf('%s vs %s . Mann-Whitney U test P= %.3g - Kolmogorov-Smirnov test P= %.3g', xList{it}, xList{itt}, p, p2));
                    switch obj.params.pipelineProject.significanceTest
                      case 'Mann-Whitney'
                        pList = [pList; p];
                        grList{end+1} = [it itt];
                      case 'Kolmogorov-Smirnov'
                        pList = [pList; p2];
                        grList{end+1} = [it itt];
                    end
                    grList{end+1} = [it itt];
                  end
                end
              end
          end
          setappdata(gcf, 'subData', subData);
          
          obj.plotHandles = boxPlot(xList, subData, ...
             'symbolColor','k',...
                            'medianColor','k',...
                            'symbolMarker','+',...
                            'showLegend',false, ...
                            'showOutliers', false, ...
                            'groupLabels', legendList, ...
                            'showLegend', true, ...
                            'notch', obj.params.styleOptions.notch, ...
                            'boxcolor', cmap);
      end
      % Now let's fix the patches
      boxes = obj.plotHandles.handles.box;
      if(all(arrayfun(@(x)length(unique(x.Vertices(:, 2))) == 1, boxes,  'UniformOutput', true) | arrayfun(@(x)all(isnan(x.Vertices(:, 2))), boxes,  'UniformOutput', true)))
        singleStatistic = true;
      else
        singleStatistic = false;
      end
      % Turn the patches into simple bars
      if(singleStatistic)
        for it = 1:numel(boxes)
          boxes(it).Vertices(1,2) = 0;
          boxes(it).Vertices(end,2) = 0;
        end
      end
      
      hold on;
      if(~strcmpi(obj.params.pipelineProject.showSignificance, 'none'))
        switch obj.params.pipelineProject.significanceTest
          case 'Mann-Whitney'
            sigstar(grList, pList);
          case 'Kolmogorov-Smirnov'
            sigstar(grList, pList);
        end
      end
      
      obj.plotHandles.handles.box =  boxes;
      
      setappdata(obj.figureHandle, 'boxData', obj.plotHandles);


      title(obj.axisHandle, obj.figName);
      
      if(isempty(obj.params.styleOptions.xLabel))
      else
        xlabel(obj.params.styleOptions.xLabel);
      end
      if(isempty(obj.params.styleOptions.yLabel))
        ylabel(obj.statisticsName);
      else
        ylabel(obj.params.styleOptions.yLabel);
      end
      
      set(obj.figureHandle,'Color','w');

      box on;
      set(obj.axisHandle, 'XTickLabelRotation', obj.params.styleOptions.XTickLabelRotation);
      set(obj.axisHandle, 'YTickLabelRotation', obj.params.styleOptions.YTickLabelRotation);
    
      title(obj.axisHandle, obj.figName);
      box on;
      set(obj.axisHandle,'Color','w');
      set(obj.figureHandle,'Color','w');
      
      ui = uimenu(obj.figureHandle, 'Label', 'Export');
      uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf';'*.eps'; '*.tiff'; '*.png'}, strrep([obj.figFolder, obj.figName], ' - ', '_'), obj.params.saveOptions.saveFigureResolution});
      uimenu(ui, 'Label', 'To workspace',  'Callback', @exportToWorkspace);
      uimenu(ui, 'Label', 'Data (statistics)',  'Callback', @(h,e)obj.exportDataAggregates(bpData, obj.exportFolder));
      uimenu(ui, 'Label', 'Data (full)',  'Callback', @(h,e)obj.exportDataFull(bpData, obj.exportFolder));

      if(obj.params.saveOptions.saveFigure)
        export_fig([obj.figFolder, obj.figName, '.', obj.params.saveOptions.saveFigureType], ...
                    sprintf('-r%d', obj.params.saveOptions.saveFigureResolution), ...
                    sprintf('-q%d', obj.params.saveOptions.saveFigureQuality), obj.figureHandle);
      end
      
      %--------------------------------------------------------------------
      function exportToWorkspace(~, ~)
        assignin('base', 'boxPlotData', obj.plotHandles);
        if(~isempty(obj.guiHandle))
          logMsg('boxPlotData data succesfully exported to the workspace. Modify its components to modify the figure', obj.guiHandle, 'w');
        else
          logMsg('boxPlotData data succesfully exported to the workspace. Modify its components to modify the figure', 'w');
        end
      end
    end
   
    %----------------------------------------------------------------------
    function updateFigure(obj, params)
      
    end
    
    %----------------------------------------------------------------------
    function init(obj, projexp, optionsClass, msg, varargin)
      %--------------------------------------------------------------------
      [obj.params, var] = processFunctionStartup(optionsClass, varargin{:});
      % Define additional optional argument pairs
      obj.params.pbar = [];
      obj.params.gui = [];
      % Parse them
      obj.params = parse_pv_pairs(obj.params, var);
      obj.params = barStartup(obj.params, msg);
      obj.params = obj.params;
      obj.guiHandle = obj.params.gui;
      %--------------------------------------------------------------------
      
      % Fix in case for some reason the group is a cell
      if(iscell(obj.params.group))
        obj.mainGroup = obj.params.group{1};
      else
        obj.mainGroup = obj.params.group;
      end

      % Check if its a project or an experiment
      if(isfield(projexp, 'saveFile'))
        [~, ~, fpc] = fileparts(projexp.saveFile);
        if(strcmpi(fpc, '.exp'))
          obj.mode = 'experiment';
          experiment = projexp;
          baseFolder = experiment.folder;
        else
          obj.mode = 'project';
          project = projexp;
          baseFolder = project.folder;
        end
      else
        obj.mode = 'project';
        project = projexp;
        baseFolder = project.folder;
      end
      
      % Consistency checks
      if(obj.params.saveOptions.onlySaveFigure)
        obj.params.saveOptions.saveFigure = true;
      end
      if(ischar(obj.params.styleOptions.figureSize))
        obj.params.styleOptions.figureSize = eval(obj.params.styleOptions.figureSize);
      end
      
      % Create necessary folders
      if(strcmpi(obj.mode, 'experiment'))
        switch obj.params.saveOptions.saveBaseFolder
          case 'experiment'
            baseFolder = experiment.folder;
          case 'project'
            baseFolder = [experiment.folder '..' filesep];
        end
      else
        baseFolder = project.folder;
      end
      if(~exist(baseFolder, 'dir'))
        mkdir(baseFolder);
      end
      obj.figFolder = [baseFolder 'figures' filesep];
      if(~exist(obj.figFolder, 'dir'))
        mkdir(obj.figFolder);
      end
      obj.exportFolder = [baseFolder 'exports' filesep];
      if(~exist(obj.exportFolder, 'dir'))
        mkdir(obj.exportFolder);
      end
    end
    
    %----------------------------------------------------------------------
    function cleanup(obj)
      if(obj.params.saveOptions.onlySaveFigure)
       close(obj.figureHandle);
      end
      %--------------------------------------------------------------------
      barCleanup(obj.params);
      %--------------------------------------------------------------------
    end
    
    %--------------------------------------------------------------------
    function exportDataAggregates(obj, bpData, baseFolder)
      [fileName, pathName] = uiputfile('.csv', 'Save data', [baseFolder obj.params.statistic '_aggregates.csv']);
      if(fileName == 0)
        return;
      end
      fID = fopen([pathName fileName], 'w');
      names = {'label', 'group', 'median', 'mean', 'std', 'N', 'Q1', 'Q3', 'IQR', 'min', 'max'};

      data = obj.plotHandles.statistics;
      for it = 1:length(names)
        lineStr = sprintf('"%s"', names{it});
        for cit = 1:size(bpData, 2)
          for git = 1:size(bpData, 3)
            if(it == 1)
              lineStr = sprintf('%s,"%s"', lineStr, strrep(obj.groupLabels{git}, ',', ' -'));
            elseif(it == 2)
              lineStr = sprintf('%s,"%s"', lineStr, obj.fullGroupList{1}{cit});
            else
              data.(names{it})
              %lineStr = sprintf('%s,%.3f', lineStr, data.(names{it})(1, cit, git));
              lineStr = sprintf('%s,%.3f', lineStr, data.(names{it})(cit, git));
            end
          end
        end
        lineStr = sprintf('%s\n', lineStr);
        fprintf(fID, lineStr);
      end
      fclose(fID);
    end

    %--------------------------------------------------------------------
    function exportDataFull(obj, bpData, baseFolder)
      [fileName, pathName] = uiputfile('.csv', 'Save data', [baseFolder obj.params.statistic '_full.csv']);
      if(fileName == 0)
        return;
      end
      fID = fopen([pathName fileName], 'w');
      % +2 for the headers
      for it = 1:(size(bpData, 1)+2) 
        mainIdx = it-2;
        lineStr = '';
        for cit = 1:size(bpData, 2)
          for git = 1:size(bpData, 3)
            if(it == 1)
              if(git == 1)
                lineStr = sprintf('%s,"%s"', lineStr, strrep(obj.groupLabels{git}, ',', ' -'));
              else
                lineStr = sprintf('%s,"%s"', lineStr, strrep(obj.groupLabels{git}, ',', ' -'));
              end
            elseif(it == 2)
              lineStr = sprintf('%s,"%s"', lineStr, obj.fullGroupList{1}{cit});
            else
              lineStr = sprintf('%s,%.3f', lineStr, bpData(mainIdx, cit, git));
            end
          end
        end

        % Stop when everything is NaN
%         if(mainIdx >= 1 && all(all(isnan(bpData(mainIdx, :, :)))))
%           break;
%         end
        % 2:end to avoid the first comma NOT ANYMORE
        lineStr = sprintf('%s\r\n', lineStr(2:end));
        fprintf(fID, lineStr);
      end
      fclose(fID);
    end
  end
end