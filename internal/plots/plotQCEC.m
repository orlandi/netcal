function projexp = plotQCEC(projexp, varargin)
% PLOTQCEC plots the avearge trace
%
% USAGE:
%    experiment = plotQCEC(experiment, varargin)
%    project = plotQCEC(project, varargin)
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
% name: plot q-complexity-entropy curve
% parentGroups: fluorescence: basic: plots, spikes: plots
% optionsClass: plotQCECOptions
% requiredFields: qCEC

% Pass class options
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(plotQCECOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Plotting q-complexity-entropy curve');
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

type = params.type;


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
hFig = figure('Name', [type '_QCEC'], 'NumberTitle', 'off', 'Visible', visible);
ax = axes;
hold on;

% It's not the rmse, bur rather the 95% percentile CL
switch mode
  case 'experiment'
    members = getAllMembers(experiment, mainGroup);
    if(isempty(members))
      logMsg(sprintf('Group %s not found or empty on experiment %s', mainGroup, experiment.name), 'w');
      return;
    end
    qCEC = experiment.qCEC;
    if(size(qCEC.C, 1) == 1)
      members = 1;
    end
    % Creating a subgroup to reuse code
    qCEC.C = qCEC.C(members, :);
    qCEC.H = qCEC.H(members, :);
    qCEC.minH = qCEC.minH(members);
    qCEC.maxC = qCEC.maxC(members);
    qCEC.perimeter = qCEC.perimeter(members);
    
    [~, q1] = min(abs(qCEC.qList-1));
    switch type
      case 'full'
        for it = 1:size(qCEC.H, 1)
          h = plot3(qCEC.H(it, :), qCEC.C(it, :), qCEC.qList, '-');  
          plot3(qCEC.H(it, q1), qCEC.C(it, q1), it, 'o', 'Color', h.Color);
        end
        plot3(mean(qCEC.H,1), mean(qCEC.C,1), qCEC.qList, '-', 'Color', 'k', 'LineWidth', 2);
        plot3(mean(qCEC.H(:,q1),1), mean(qCEC.C(:,q1),1), 1, 'x', 'Color', 'k');
      case 'mean'
        rmse = 1.96*std(qCEC.C,[], 1);
        % Divide the patch in two
        [~, minH] = min(mean(qCEC.H,1));
        h = ciplot(mean(qCEC.C(:,1:minH),1)-rmse(1:minH), mean(qCEC.C(:,1:minH),1)+rmse(1:minH), mean(qCEC.H(:,1:minH),1), [0 0 0.95]);
        h.FaceAlpha = 0.5;
        h = ciplot(mean(qCEC.C(:,minH:end),1)-rmse(minH:end), mean(qCEC.C(:,minH:end),1)+rmse(minH:end), mean(qCEC.H(:,minH:end),1), [0 0 0.95]);
        h.FaceAlpha = 0.5;
        plot3(mean(qCEC.H,1), mean(qCEC.C,1), qCEC.qList, '-', 'Color', 'k');
        plot3(mean(qCEC.H(:,q1),1), mean(qCEC.C(:,q1),1), 1, 'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'k');
    end
    if(params.plotStandardEntropy)
      measure = qCEC.H(:, q1);
      [f, xi] = ksdensity(measure); % Not using support
      valid = find(xi > 0);
      hFigH = figure('Name', [experiment.name ' entropy distribution'], 'NumberTitle', 'off', 'Visible', visible);
      axH = axes(hFigH);
      plot(axH, xi(valid), f(valid));
      yl = ylim(axH);
      hold on;
      hm = plot(axH, [1, 1]*mean(measure), yl, 'k--');
      xlabel(axH, 'entropy');
      ylabel(axH, 'PDF');
      legend(hm, sprintf('mean = %.4f', mean(measure)));
      ui = uimenu(hFigH, 'Label', 'Export');
      uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf';'*.eps'; '*.tiff'; '*.png'}, [experiment.folder experiment.name '_entropy']});
      if(params.saveFigure)
        export_fig([figFolder, baseFigName, '_entropy', params.saveFigureTag, '.', params.saveFigureType], ...
                    sprintf('-r%d', params.saveFigureResolution), ...
                    sprintf('-q%d', params.saveFigureQuality), hFigH);
      end
      if(~params.showFigure)
        close(hFigH);
      end
    end
    if(params.plotStandardComplexity)
      measure = qCEC.C(:, q1);
      [f, xi] = ksdensity(measure); % Not using support
      valid = find(xi > 0);
      hFigH = figure('Name', [experiment.name ' complexity distribution'], 'NumberTitle', 'off', 'Visible', visible);
      axH = axes(hFigH);
      plot(axH, xi(valid), f(valid));
      yl = ylim(axH);
      hold on;
      hm = plot(axH, [1, 1]*mean(measure), yl, 'k--');
      xlabel(axH, 'complexity');
      ylabel(axH, 'PDF');
      legend(hm, sprintf('mean = %.4f', mean(measure)));
      ui = uimenu(hFigH, 'Label', 'Export');
      uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf';'*.eps'; '*.tiff'; '*.png'}, [experiment.folder experiment.name '_complexity']});
      if(params.saveFigure)
        export_fig([figFolder, baseFigName, '_complexity', params.saveFigureTag, '.', params.saveFigureType], ...
                    sprintf('-r%d', params.saveFigureResolution), ...
                    sprintf('-q%d', params.saveFigureQuality), hFigH);
      end
      if(~params.showFigure)
        close(hFigH);
      end
    end
  case 'project'
    checkedExperiments = find(project.checkedExperiments);
    switch params.groupingOrder
      case 'none'
        switch params.sortingOrder
          case 'original'
          case 'label'
            labels = project.labels(checkedExperiments);
            [~,experimentOrder] = sort(labels);
            checkedExperiments = checkedExperiments(experimentOrder);
        end
        cmap = eval([params.colormap '(' num2str(length(checkedExperiments)) ')']);
        hList = [];
        experimentsPlotted = [];
        for i = 1:length(checkedExperiments)
          experimentName = project.experiments{checkedExperiments(i)};
          experimentFile = [project.folderFiles experimentName '.exp'];
          experiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
          members = getAllMembers(experiment, mainGroup);
          
          if(isempty(members))
            logMsg(sprintf('Group %s not found or empty on experiment %s', mainGroup, experiment.name), 'w');
            continue;
          end
          try
            qCEC = experiment.qCEC;
            if(size(qCEC.C, 1) == 1)
              members = 1;
            end
            % Creating a subgroup to reuse code
            qCEC.C = qCEC.C(members, :);
            qCEC.H = qCEC.H(members, :);
            qCEC.minH = qCEC.minH(members);
            qCEC.maxC = qCEC.maxC(members);
            qCEC.perimeter = qCEC.perimeter(members);
            [~, q1] = min(abs(qCEC.qList-1));
            switch type
              case 'full'
                for it = 1:size(qCEC.H, 1)
                  h = plot3(qCEC.H(it, :), qCEC.C(it, :), qCEC.qList, '-', 'Color', 'k');  
                  plot3(qCEC.H(it, q1), qCEC.C(it, q1), it, 'o', 'Color', h.Color);
                end
                plot3(mean(qCEC.H,1), mean(qCEC.C,1), qCEC.qList, '-', 'Color', cmap(i, :), 'LineWidth', 2);
                plot3(mean(qCEC.H(:,q1),1), mean(qCEC.C(:,q1),1), 1, 'x', 'Color', cmap(i, :));
              case 'mean'
                %rmse = 1.96*std(qCEC.C,1);
                rmse = std(qCEC.C,[], 1)/sqrt(size(qCEC.C, 1));
                % Divide the patch in two
                [~, minH] = min(mean(qCEC.H,1));
                h = ciplot(mean(qCEC.C(:,1:minH),1)-rmse(1:minH), mean(qCEC.C(:,1:minH),1)+rmse(1:minH), mean(qCEC.H(:,1:minH),1), cmap(i, :));
                h.FaceAlpha = 0.5;
                h = ciplot(mean(qCEC.C(:,minH:end),1)-rmse(minH:end), mean(qCEC.C(:,minH:end),1)+rmse(minH:end), mean(qCEC.H(:,minH:end),1), cmap(i, :));
                h.FaceAlpha = 0.5;
                hList = [hList; h];
                plot3(mean(qCEC.H,1), mean(qCEC.C,1), qCEC.qList, '-', 'Color', cmap(i, :));
                plot3(mean(qCEC.H(:,q1),1), mean(qCEC.C(:,q1),1), 1, 'o', 'MarkerFaceColor', cmap(i, :), 'MarkerEdgeColor', cmap(i, :));
            end
            experimentsPlotted = [experimentsPlotted; checkedExperiments(i)];
    %        colormap
           catch ME
            logMsg(sprintf('Something went wrong with qCEC data in experiment %s', experimentName), 'e');
            logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
          end
        end
        legend(hList, project.experiments{experimentsPlotted});
      case 'label'
        hList = [];
        rmseCfull = [];
        rmseHfull = [];
        meanCfull = [];
        meanHfull = [];
        % Let's group by order together
        labels = project.labels(checkedExperiments);
        uniqueLabels = unique(labels);
        cmap = eval([params.colormap '(' num2str(length(uniqueLabels)) ')']);
        for i = 1:length(uniqueLabels)
          validExperiments = find(strcmp(labels, uniqueLabels{i}));
          %qCEClist = cell(length(validExperiments), 1);
          for j = 1:length(validExperiments)
            curExp = checkedExperiments(validExperiments(j));
            % Now that we have the experiment, load the qCEC data
            experimentName = project.experiments{curExp};
            experimentFile = [project.folderFiles experimentName '.exp'];
            try
              experiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
            catch
              logMsg(sprintf('Could not load experiment %s', experimentName), 'w');
              continue;
            end
            if(~isfield(experiment, 'qCEC'))
              logMsg(sprintf('qCEC not found on experiment %s', experimentName), 'w');
              continue;
            end
            members = getAllMembers(experiment, mainGroup);
            
            if(isempty(members))
              logMsg(sprintf('Group %s not found or empty on experiment %s', mainGroup, experiment.name), 'w');
              continue;
            end
            qCEC = experiment.qCEC;
            if(size(qCEC.C, 1) == 1)
              members = 1;
            end
            % Creating a subgroup to reuse code
            qCEC.C = qCEC.C(members, :);
            qCEC.H = qCEC.H(members, :);
            qCEC.minH = qCEC.minH(members);
            qCEC.maxC = qCEC.maxC(members);
            qCEC.perimeter = qCEC.perimeter(members);

            [~, q1] = min(abs(qCEC.qList-1));
            rmseC = std(qCEC.C,[], 1)/sqrt(size(qCEC.C, 1));
            rmseH = std(qCEC.H,[], 1)/sqrt(size(qCEC.H, 1));
            meanC = mean(qCEC.C,1);
            meanH = mean(qCEC.H,1);
            rmseCfull = [rmseCfull, rmseC(:)];
            rmseHfull = [rmseHfull, rmseH(:)];
            meanCfull = [meanCfull, meanC(:)];
            meanHfull = [meanHfull, meanH(:)];
            %qCEClist = qCEC;
          end
          % Now that we have the qCEC list for a label, plot it
          % If all are 0, it's because they are single traces. Do the rmse between experiments
          if(all(rmseCfull == 0))
            rmseCfullCombined = std(meanCfull, [], 2)/size(meanCfull, 2);
          else
            rmseCfullCombined = sqrt(sum(rmseCfull.^2,2))/size(rmseCfull, 2);
          end
          if(all(rmseHfull == 0))
            rmseHfullCombined = std(meanHfull, [], 2)/size(meanHfull, 2);
          else
            rmseHfullCombined = sqrt(sum(rmseHfull.^2,2))/size(rmseHfull, 2);
          end
          meanCfullCombined = mean(meanCfull, 2);
          meanHfullCombined = mean(meanHfull, 2);
          [~, minH] = min(meanHfull);
          %h = ciplot(meanCfullCombined(1:minH)-rmseCfullCombined(1:minH), meanCfullCombined(1:minH)+rmseCfullCombined(1:minH), meanHfullCombined(1:minH), cmap(i, :));
          h = ciplotXY(meanCfullCombined(1:minH)-rmseCfullCombined(1:minH), meanCfullCombined(1:minH)+rmseCfullCombined(1:minH), ...
                     meanHfullCombined(1:minH)-rmseHfullCombined(1:minH), meanHfullCombined(1:minH)+rmseHfullCombined(1:minH), cmap(i, :));
          h.FaceAlpha = 0.5;
          %h = ciplot(meanCfullCombined(minH:end)-rmseCfullCombined(minH:end), meanCfullCombined(minH:end)+rmseCfullCombined(minH:end), meanHfullCombined(minH:end), cmap(i, :));
          h = ciplotXY(meanCfullCombined(minH:end)-rmseCfullCombined(minH:end), meanCfullCombined(minH:end)+rmseCfullCombined(minH:end), ...
            meanHfullCombined(minH:end)-rmseHfullCombined(minH:end), meanHfullCombined(minH:end)+rmseHfullCombined(minH:end), cmap(i, :));
          h.FaceAlpha = 0.5;
          hList = [hList; h];
          plot3(meanHfullCombined, meanCfullCombined, qCEC.qList, '-', 'Color', cmap(i, :));
          plot3(meanHfullCombined(q1), meanCfullCombined(q1), 1, 'o', 'MarkerFaceColor', cmap(i, :), 'MarkerEdgeColor', cmap(i, :));
        end
        legend(hList, uniqueLabels, 'Location', 'SW');
    end
end
xlabel(ax, 'q-Entropy Hq');
ylabel(ax, 'q-Complexity Cq');
zlabel(ax, 'q');
view(ax, [0 90]);
xl = xlim;
yl = ylim;
if(xl(2) == 1)
  xlim(ax, [xl(1) 1+(1-xl(1))*0.01]);
end
if(yl(1) == 0)
  ylim(ax, [-yl(2)*0.01 yl(2)]);
end
box on;
title(ax, [type ' q-CEC']);
set(gcf,'Color','w');
pos = get(hFig, 'Position');
pos(4) = pos(3)/((1+sqrt(5))/2);
set(hFig, 'Position', pos);

ui = uimenu(hFig, 'Label', 'Export');
uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf';'*.eps'; '*.tiff'; '*.png'}, [experiment.folder experiment.name '_' type '_qCEC']});

if(params.saveFigure)
  export_fig([figFolder, baseFigName, '_', type, '_qCEC', params.saveFigureTag, '.', params.saveFigureType], ...
              sprintf('-r%d', params.saveFigureResolution), ...
              sprintf('-q%d', params.saveFigureQuality), hFig);
end

if(~params.showFigure)
  close(hFig);
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
  

end