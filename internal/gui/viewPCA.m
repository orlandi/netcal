function [hFigW, project] = viewPCA(project, features, featuresNames, PCAfield)
% VIEWPCA View PCA results for aggregated experiments
%
% USAGE:
%    [hFigW, project] = viewPCA(project, features, featuresNames)
%
% INPUT arguments:
%    project
%
%    features
%
%    featuresNames
%
% OUTPUT arguments:
%    hFigW
%
%    project
%
% EXAMPLE:
%    [hFigW, project] = viewPCA(project, features, featuresNames)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Initialization
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
gui = gcbf;
hFigW = [];
minGridBorder = 1;
numberOfClusters = 3;
kmeansIterations = 100;

clusterIdx = [];
colorList = ones(size(features, 1), 1);
uniqueColors = 1;
uniqueColorsCmap = [0 0 1];
if(isfield(project, 'PCA') && isfield(project.(PCAfield), 'clusterIdx'))
    clusterIdx = project.(PCAfield).clusterIdx;
    numberOfClusters = max(clusterIdx);
end
useDifferentBasis = false;
originalFeatures = features;
% Turn nan features into 0s to compute PCAs and k-means
features(isnan(features)) = 0;
colorLegend = 'none';
currentPlot = 'pca';
selectionX = [];
selectionY = [];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Create components
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
hs.mainWindow = figure('Visible','off',...
                       'Resize','on',...
                       'Toolbar', 'figure',...
                       'Tag','viewPCA', ...
                       'DockControls','off',...
                       'NumberTitle', 'off',...
                       'MenuBar', 'none',...
                       'CloseRequestFcn', @closeThis,...
                       'Name', 'PCA-based spike analysis');
hFigW = hs.mainWindow;
if(~verLessThan('MATLAB','9.5'))
  addToolbarExplorationButtons(hFigW);
end
hFigW.Position = setFigurePosition(gui, 'width', 800, 'height', 600);
if(~isempty(gui))
  setappdata(hFigW, 'logHandle', getappdata(gcbf, 'logHandle'));
end
hs.menuPlot = uimenu(hs.mainWindow, 'Label', 'Plot');
hs.menuPlotPCA = uimenu(hs.menuPlot, 'Label', 'PCA', 'Callback', @plotPCAfull);
hs.menuPlotPCA = uimenu(hs.menuPlot, 'Label', 'PCA axis', 'Callback', @plotPCAaxis);
hs.menuPlotPCA = uimenu(hs.menuPlot, 'Label', 'Feature Contributions', 'Callback', @plotContributions);
hs.menuPlotPCA = uimenu(hs.menuPlot, 'Label', 'Original Features', 'Callback', @plotFeatures);
hs.menuPlotPCA = uimenu(hs.menuPlot, 'Label', 'Select points', 'Callback', @selectPoints);
hs.menuPlotPCA = uimenu(hs.menuPlot, 'Label', 'Refresh', 'Callback', @updateImage);
hs.menuPlotCorrPlot = uimenu(hs.menuPlot, 'Label', 'Correlation plot', 'Callback', @menuViewCorrPlot);
hs.menuPlotFeaturesDistributions = uimenu(hs.menuPlot, 'Label', 'Features distribution');
for it = 1:length(featuresNames)
  uimenu(hs.menuPlotFeaturesDistributions, 'Label', featuresNames{it}, 'Callback', {@menuPlotFeaturesDistribution, it});
end

hs.menuClustering = uimenu(hs.mainWindow, 'Label', 'Clustering');
hs.menuKmeans = uimenu(hs.menuClustering, 'Label', 'K-means', 'Callback', @menuKmeans);
hs.menuKmeansStatistics = uimenu(hs.menuClustering, 'Label', 'K-means statistics');
hs.menuKmeansStatisticsFractions = uimenu(hs.menuKmeansStatistics, 'Label', 'Fractions', 'Callback', @menuKmeansStatisticsFractions);

hs.menu.preferences.root = uimenu(hs.mainWindow, 'Label', 'Preferences');
hs.menu.preferences.color.root = uimenu(hs.menu.preferences.root, 'Label', 'Color Mode');
hs.menu.preferences.color.exp = uimenu(hs.menu.preferences.color.root, 'Label', 'By experiment', 'Callback', {@colorModeChange, 'experiment'});
hs.menu.preferences.color.tag = uimenu(hs.menu.preferences.color.root, 'Label', 'By label', 'Callback', {@colorModeChange, 'label'});
hs.menu.preferences.color.cl = uimenu(hs.menu.preferences.color.root, 'Label', 'By cluster', 'Callback', {@colorModeChange, 'cluster'});

hs.menuExport = uimenu(hs.mainWindow, 'Label', 'Export');
hs.menuExportFigure = uimenu(hs.menuExport, 'Label', 'Figure', 'Callback', @exportFigure);
hs.menuExportData = uimenu(hs.menuExport, 'Label', 'Data per cluster', 'Callback', @exportData);
hs.menuExportDataFeature = uimenu(hs.menuExport, 'Label', 'Data per feature', 'Callback', @exportDataFeature);
hs.menuExportDataFull = uimenu(hs.menuExport, 'Label', 'Data full', 'Callback', @exportDataFull);
hs.menuExportAggregated = uimenu(hs.menuExport, 'Label', 'K-means clusters to the experiments', 'Callback', @exportKmeansGroups);
hs.menuExportAggregated = uimenu(hs.menuExport, 'Label', 'Aggregated experiments', 'Callback', @exportAggregatedExperiments);

hs.menuExport = uimenu(hs.mainWindow, 'Label', 'Import');
hs.menuExportFigure = uimenu(hs.menuExport, 'Label', 'PCA basis from external file', 'Callback', @importPCA);
hs.menuExportFigure = uimenu(hs.menuExport, 'Label', 'Features from external file', 'Callback', @importPCAfeatures);

% Main grid
hs.mainWindowSuperBox = uix.VBox('Parent', hs.mainWindow);
hs.mainWindowGrid = uix.Grid('Parent', hs.mainWindowSuperBox);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% COLUMN START
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Empty left
uix.Empty('Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowGrid);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% COLUMN START
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
uix.Empty('Parent', hs.mainWindowGrid);

% Plot --------------------------------------------------------------------
hs.mainWindowFramesPanel = uix.Panel('Parent', hs.mainWindowGrid, 'Padding', 5, 'BorderType', 'none');
hs.mainWindowFramesAxes = axes('Parent', uicontainer('Parent',hs.mainWindowFramesPanel));
if(~verLessThan('MATLAB','9.5'))
  aa = gca;
  aa.Toolbar.Visible = 'off';
end
%set(hs.mainWindowFramesAxes, 'ButtonDownFcn', @rightClick);

uix.Empty('Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowGrid);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% COLUMN START
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Empty right
uix.Empty('Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowGrid);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Finish superbox
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Now the log panel
hs.logPanelParent = uix.Panel('Parent', hs.mainWindowSuperBox, ...
                               'BorderType', 'none');
hs.logPanel = uicontrol('Parent', hs.logPanelParent, ...
                      'style', 'edit', 'max', 5, 'Background','w');
set(hs.mainWindowSuperBox, 'Heights', [-1 100], 'Padding', 0, 'Spacing', 0);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Final init
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
set(hs.mainWindowGrid, 'Widths', [minGridBorder -1 minGridBorder], 'Heights', [minGridBorder -1 125 minGridBorder]);
cleanMenu();
updateButtons();
updateMenus();
% Finish the new log panel
hs.mainWindow.Visible = 'on';
jScrollPanel = findjobj(hs.logPanel);
try
    jScrollPanel.setVerticalScrollBarPolicy(jScrollPanel.java.VERTICAL_SCROLLBAR_AS_NEEDED);
    jScrollPanel = jScrollPanel.getViewport;
catch
    % may possibly already be the viewport, depending on release/platform etc.
end
hs.logPanelEditBox = handle(jScrollPanel.getView,'CallbackProperties');
hs.logPanelEditBox.setEditable(false);
logMessage(hs.logPanelEditBox, '<b>Message log</b>');
ncbar.automatic('Updating PCA');
[coeffPCA, scoresPCA, cscoresPCA, explainedPCA, coefforthPCA] = updatePCA(features);
if(isfield(project, 'PCA') && isfield(project.(PCAfield), 'clusterIdx'))
  colorModeChange([], [], 'cluster');
else
  colorModeChange([], [], 'none');
end
plotPCA();
%updateImage();
ncbar.close();
if(~isempty(gui))
  parentHandle = getappdata(hFigW, 'logHandle');
  setappdata(hFigW, 'logHandle', [parentHandle hs.logPanelEditBox]);
else
  setappdata(hs.mainWindow, 'logHandle', hs.logPanelEditBox);
end
%legend(colorLegend);

if(isempty(gui))
  waitfor(hFigW);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Callbacks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------------------------------------------------------------
function closeThis(~, ~)
  if(~isempty(gui))
    if(isvalid(gui))
      setappdata(gui, 'project', project);
    else
      delete(hFigW);
      return;
    end
  else
    delete(hFigW);
    return;
  end
  
  % To force updating
  resizeHandle = getappdata(gui, 'ResizeHandle');
  if(isa(resizeHandle,'function_handle'))
    resizeHandle([], [], 'full');
  end
  
  delete(hFigW);
end

%--------------------------------------------------------------------------
function exportFigure(~, ~)
    [fileName, pathName] = uiputfile({'*.png'; '*.tiff'; '*.pdf'; '*.eps'}, 'Save figure', [project.folder 'PCA']);

    if(fileName ~= 0)
        axes(hs.mainWindowFramesAxes);
        title('PCA analysis');
        export_fig([pathName fileName], '-r150', hs.mainWindowFramesAxes);
        title([]);
    end
end


%--------------------------------------------------------------------------
function plotPCA(~, ~, ~)
  lh = findall(hs.mainWindow, 'Type', 'Legend');
  axes(hs.mainWindowFramesAxes);
  cla(hs.mainWindowFramesAxes);
  cla reset;

  axis tight;
  hold on;
  for itt = 1:size(uniqueColors, 1)
    valid = (colorList == uniqueColors(itt));
    scatter(scoresPCA(valid,1), scoresPCA(valid,2), 64, uniqueColorsCmap(colorList(valid), :), 'fill');
  end

  if(~isempty(lh))
    legend(colorLegend);
  end

  xlabel('1st PC');
  ylabel('2nd PC');
  box on;
  currentPlot = 'pca';
end

%--------------------------------------------------------------------------
function plotPCAfull(~, ~, varargin)
  if(nargin <= 2 || ~varargin{1})
    % Select axes features
    [selectionX, ok] = listdlg('PromptString', 'Select X axis', 'ListString', num2str((1:size(scoresPCA,2))'), 'SelectionMode', 'single');
    if(~ok)
        return;
    end
    [selectionY, ok] = listdlg('PromptString', 'Select Y axis', 'ListString', num2str((1:size(scoresPCA,2))'), 'SelectionMode', 'single');
    if(~ok)
        return;
    end
  end
  lh = findall(hs.mainWindow, 'Type', 'Legend');
  axes(hs.mainWindowFramesAxes);
  cla(hs.mainWindowFramesAxes);
  cla reset;

  axis tight;
  hold on;
%    scatter(scoresPCA(:,selectionX), scoresPCA(:,selectionY), 8, colorList, 'fill');

  for itt = 1:length(uniqueColors)
    valid = (colorList == uniqueColors(itt));
    scatter(scoresPCA(valid,selectionX), scoresPCA(valid,selectionY), 8, uniqueColorsCmap(colorList(valid), :), 'fill');
  end
  
  if(~isempty(lh))
    legend(colorLegend);
  end

  xlabel(['Component #' num2str(selectionX)]);
  ylabel(['Component #' num2str(selectionY)]);
  box on;
  currentPlot = 'pcafull';
end

%--------------------------------------------------------------------------
function plotFeatures(~, ~, varargin)
   if(nargin <= 2 || ~varargin{1})
    % Select axes features
    [selectionX, ok] = listdlg('PromptString', 'Select X axis', 'ListString', featuresNames, 'SelectionMode', 'single');
    if(~ok)
        return;
    end
    [selectionY, ok] = listdlg('PromptString', 'Select Y axis', 'ListString', featuresNames, 'SelectionMode', 'single');
    if(~ok)
        return;
    end
   end
  lh = findall(hs.mainWindow, 'Type', 'Legend');
  axes(hs.mainWindowFramesAxes);
  cla(hs.mainWindowFramesAxes);
  cla reset;
  hold on;
  axis tight;
  %scatter(features(:,selectionX), features(:,selectionY), 8, colorList, 'fill');
  for itt = 1:length(uniqueColors)
    valid = (colorList == uniqueColors(itt));
    scatter(features(valid,selectionX), features(valid,selectionY), 8, uniqueColorsCmap(colorList(valid), :), 'fill');
  end
  
  if(~isempty(lh))
    legend(colorLegend);
  end

  xlabel(featuresNames(selectionX));
  ylabel(featuresNames(selectionY));
  box on;
  currentPlot = 'features';
end

%--------------------------------------------------------------------------
function plotPCAaxis(~, ~, ~)
  hFig = figure('Position', [200 200 650 400]);
  axis tight;

  biplot(coefforthPCA(:,1:2), 'scores', scoresPCA(:,1:2), 'varlabels', featuresNames);
  
  box on;
  hold on;
  exportMenu = uimenu(hFig, 'Label', 'Export');
  uimenu(exportMenu, 'Label', 'Figure', 'Callback', {@exportFigCallback, {'*.png';'*.tiff';'*.pdf';'*.eps'}, [project.folder 'PCAaxis']});
  currentPlot = 'none';
end

%--------------------------------------------------------------------------
function selectPoints(~, ~, ~)
    h = gname;
    for i = 1:length(h)
        curPoint = str2num(h(i).String);
        ROIidx = features(curPoint, end-1);
        expIdx = features(curPoint, end);
        
        logMsg(['Selected point: ' h(i).String ' - ROI: ' num2str(ROIidx) ' - experiment: ' project.experiments{expIdx}]);
    end
end

%--------------------------------------------------------------------------
function menuPlotFeaturesDistribution(~, ~, featureNum)
  if(isempty(clusterIdx))
    logMsg('No cluster information found', 'e');
    return;
  end
  % Now select the clusters
  [selectedClusters, success] = listdlg('PromptString', 'Select clusters', 'SelectionMode', 'multiple', 'ListString', num2str((1:numberOfClusters)'));
  if(~success)
      return;
  end
  
  
  % Now select plot options
  [success, currOpts] = preloadOptions([], spikeFeaturesDistributionPlotOptions, gui, true, false);
  if(~success)
    return;
  end
  spikeFeaturesDistributionPlotOptionsCurrent = currOpts;
  
  % Now let's do the plot
  cmap = eval([spikeFeaturesDistributionPlotOptionsCurrent.colormap '(' num2str(length(selectedClusters)) ')']);
  hFig = figure;
  hold on;
  h = [];
  fullData = cell(length(selectedClusters), 1);
  for i = 1:length(selectedClusters)
    members = find(clusterIdx == selectedClusters(i));
    switch spikeFeaturesDistributionPlotOptionsCurrent.distributionType
      case 'unbounded kernel density'
        [f, xi] = ksdensity(features(members, featureNum));    
        h = [h; plot(xi, f, 'Color', cmap(i, :))];
      case 'positive kernel density'
        [f, xi] = ksdensity(features(members, featureNum), 'support', 'positive');
        h = [h; plot(xi, f, 'Color', cmap(i, :))];
      case 'histogram'
        [f, xi] = hist(features(members, featureNum), sshist(features(members, featureNum)));
        % Now normalize the histogram
        area = trapz(xi, f);
        f = f/area;
        hh = bar(xi, f/area);
        set(hh, 'FaceColor', cmap(i, :));
        h = [h; hh];
      otherwise
        [f, xi] = hist(features(members, featureNum), str2num(spikeFeaturesDistributionPlotOptionsCurrent.distributionType));
        area = trapz(xi, f);
        f = f/area;
        hh = bar(xi, f);
        set(hh, 'FaceColor', cmap(i, :));
        h = [h; hh];
    end
    fullData{i} = [xi(:), f(:)];
  end
  setappdata(0, 'fullData', fullData);
  Nrows = max(cellfun('length', fullData));
  fullDataExport = nan(Nrows, length(selectedClusters)*2);
  fullDataExportNames = cell(length(selectedClusters)*2, 1);
  for i = 1:length(selectedClusters)
    fullDataExport(1:size(fullData{i}, 1), (2*(i-1)+1):(2*(i-1)+2)) = fullData{i};
    fullDataExportNames{(2*(i-1)+1)} = ['x cluster: ' num2str(selectedClusters(i))];
    fullDataExportNames{(2*(i-1)+2)} = ['y cluster: ' num2str(selectedClusters(i))];
  end
  xlabel(featuresNames{featureNum});
  switch spikeFeaturesDistributionPlotOptionsCurrent.distributionType
    case 'unbounded kernel density'
      ylabel('density');
    case 'positive kernel density'
      ylabel('density');
    case 'histogram'
      ylabel('count');
    otherwise
      ylabel('count');
  end
  legend(h, num2str(selectedClusters(:)));
  title(['Distribution estimate for feature: ' featuresNames{featureNum}]);
  box on;
  
  ui = uimenu(hFig, 'Label', 'Export');
  uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.png'; '*.tiff'; '*.pdf'; '*.eps'}, [project.folder 'distribution' featuresNames{featureNum}]});
  uimenu(ui, 'Label', 'Data',  'Callback', ...
   {@exportDataCallback, {'*.csv'}, ...
                    [project.folder 'distributionData' featuresNames{featureNum}], ...
                    fullDataExport, ...
                    fullDataExportNames});
    
                  
  
  setappdata(gui, 'spikeFeaturesDistributionPlotOptionsCurrent', spikeFeaturesDistributionPlotOptionsCurrent);
  
end

%--------------------------------------------------------------------------
function menuViewCorrPlot(~, ~, ~)
    corrplot(features(:,1:(end-2)), 'type','Pearson','testR','on', 'varNames',...
        featuresNames);
    hfig = gcf;
    uimenu(hfig, 'Label', 'Export',  'Callback', {@exportFigCallback, {'*.png';'*.tiff'}, [project.folder 'corrPlot']});
end

%--------------------------------------------------------------------------
function plotContributions(~, ~, ~)
    answer = inputdlg('Enter number of components to show contributions from',...
                      'Number of components', [1 60], {'2'});
    if(isempty(answer))
        return;
    end
    nComponents = str2num(answer{1});
    if(nComponents > size(coeffPCA, 2))
      logMsg('Too many components', 'e');
    end
    hFig = figure('Position', [200 200 650 400]);
    axis tight;
    
    %bar(coeffPCA(1:2, :)');
    bar(coeffPCA(:, 1:nComponents));
    
    set(gca,'XTick',1:length(featuresNames));
    set(gca,'XTickLabel', featuresNames);
    set(gca, 'XTickLabelRotation', 30);
    xlabel('');
    ylabel('Contribution');
    title('Feature contribution to the first 2 PC');
    box on;
    hold on;
    legendStr = strsplit(strtrim(sprintf('PC: %d\t', (1:nComponents)')),'\t');
    legend(legendStr);
    
    exportMenu = uimenu(hFig, 'Label', 'Export');
    uimenu(exportMenu, 'Label', 'Figure', 'Callback', {@exportFigCallback, {'*.png';'*.tiff';'*.pdf';'*.eps'}, [project.folder 'PCAcontributions']});
  
    uimenu(exportMenu, 'Label', 'Data',  'Callback', ...
   {@exportDataCallback, {'*.csv'}, ...
                    [project.folder 'featuresContributions'], ...
                    coeffPCA(:, 1:nComponents), ...
                    legendStr, 'pcaContrib', featuresNames});
    
end
%--------------------------------------------------------------------------
function colorModeChange(~, ~, mode)
  switch mode
    case 'experiment'
      colorList = features(:, end);
      ucol = unique(colorList);
      colorLegend = {};
      for i = 1:length(ucol);
        colorLegend{end+1} = sprintf('exp: %d', ucol(i));
      end
    case 'label'
      labelList = project.labels(features(:, end));
      labelSet = unique(project.labels);
      colorList = zeros(size(features, 1), 1);
      for itt = 1:length(labelSet)
      	valid = (strcmp(labelList, labelSet{itt}));
        colorList(valid) = itt;
      end
      colorLegend = labelSet;
    case 'cluster'
      colorList = clusterIdx;
      ucol = unique(colorList);
      colorLegend = {};
      for i = 1:length(ucol);
        colorLegend{end+1} = sprintf('cluster: %d', ucol(i));
      end
    otherwise
      colorList = ones(size(features, 1), 1);
      colorLegend = 'none';
  end
  uniqueColors = unique(colorList);
  uniqueColorsCmap = lines(max(uniqueColors));
  
  updateColor();
end

%--------------------------------------------------------------------------
function menuKmeans(~, ~, ~)
    if(isfield(project, 'KMeansOptionsCurrent'))
        KMeansOptionsCurrent = project.KMeansOptionsCurrent;
    else
        KMeansOptionsCurrent = KMeansOptions;
    end
    [success, KMeansOptionsCurrent] = optionsWindow(KMeansOptionsCurrent);
    if(~success)
        return;
    end
    project.KMeansOptionsCurrent = KMeansOptionsCurrent;
    numberOfClusters = project.KMeansOptionsCurrent.clusters;
    kmeansIterations = project.KMeansOptionsCurrent.iterations;
    
    % Redo the PCA
    if(project.KMeansOptionsCurrent.nanToZero)
        features = originalFeatures;
        features(isnan(features)) = 0;
    else
        features = originalFeatures;
    end
    ncbar.automatic('Running Kmeans');
    if(project.KMeansOptionsCurrent.zNorm)
        zFeatures = features;
        for i = 1:size(zFeatures, 2)
            zFeatures(:, i) = (zFeatures(:, i) - nanmean(zFeatures(:, i)))/(nanstd(zFeatures(:, i)));
        end
        if(~useDifferentBasis)
          [coeffPCA, scoresPCA, cscoresPCA, explainedPCA, coefforthPCA] = updatePCA(zFeatures);
        else
          scoresPCA = bsxfun(@minus, features(:,1:end-2), mean(features(:,1:end-2)))*coeffPCA;
        end
        plotPCA();
    else
      if(~useDifferentBasis)
        [coeffPCA, scoresPCA, cscoresPCA, explainedPCA, coefforthPCA] = updatePCA(features);
      else
        scoresPCA = bsxfun(@minus, features(:,1:end-2), mean(features(:,1:end-2)))*coeffPCA;
      end
    end
    plotPCA();
    X = scoresPCA;
    
    clusterIdx = kmeans(X, numberOfClusters, 'Distance', 'cityblock', 'MaxIter', kmeansIterations);
    ncbar.close();
    project.(PCAfield).clusterIdx = clusterIdx;
    colorModeChange([], [], 'cluster');
    %setappdata(gui, 'project', project);
    updateImage();
end

%--------------------------------------------------------------------------
function menuKmeansStatisticsFractions(~, ~, ~)
    if(isempty(clusterIdx))
        logMsg('No cluster information found', 'e');
        return;
    end
    
    hFig = figure('Position', [200 200 650 400]);
    hold on;
    [a, b] = hist(clusterIdx, 1:numberOfClusters);
    h = [];
    cmap = parula(numberOfClusters);
    for i = 1:length(a)
        h(i) = bar(b(i),a(i)/sum(a)*100);
        set(h(i), 'FaceColor', cmap(i, :));
    end
    xlabel('cluster index');
    ylabel('fraction');
    title('Fraction of spiking neurons on each cluster');
    set(gca, 'XTick', 1:numberOfClusters);
    for i = 1:numberOfClusters    
        text(i, a(i)/sum(a)*100, [num2str(a(i)/sum(a)*100,'%.2f') '%'],...
                   'HorizontalAlignment','center',...
                   'VerticalAlignment','bottom', 'FontSize', 12, 'Parent', gca);
    end
    yl = ylim;
    ylim([yl(1) yl(2)*1.1]);
    box on;
    exportMenu = uimenu(hFig, 'Label', 'Export');
    uimenu(exportMenu, 'Label', 'Figure', 'Callback', {@exportFigCallback, {'*.png';'*.tiff';'*.pdf';'*.eps'}, [project.folder 'kmeansStatistics']});
end

%--------------------------------------------------------------------------
function importPCA(~, ~)
  %[fileName, pathName] = uiputfile({'*.png'; '*.tiff'; '*.pdf'; '*.eps'}, 'Save figure', [project.folder 'PCA']);
  [fileName, pathName] = uigetfile({'*.csv'}, 'Select file', project.folder);
  if(fileName == 0 | ~exist([pathName fileName], 'file'))
    logMsg('Invalid file', 'e');
    return;
  end
  
  % Get the column name
  dividend = size(featuresNames, 1)+3;
  columnName = '';
  while (dividend > 0)
    modulo = mod(dividend - 1, 26);
    columnName = [char(65 + modulo), columnName];
    dividend = floor((dividend - modulo) / 26);
  end
  finalPos = [columnName, num2str(size(features, 1)+1)];
  finalPosMax = [columnName, num2str(size(features, 1)*2+1)];
  ncbar.automatic('Loading file');
  %newFeatures = xlsread([pathName fileName], ['A2:', finalPosMax]);
  newFeatures = csvread([pathName fileName], 1, 0);
  ncar.close();
  tmpFeatures = newFeatures(:, 1:end-1);
  if(size(tmpFeatures, 2) ~= size(features, 2))
    logMsg(sprintf('Number of features in the external file (%d) differs from the current number (%d)', size(tmpFeatures,2)-2, size(features,2)-2), 'e');
    return;
  end
  %clusterIdx = newFeatures(:, end);
  [coeffPCA, ~, cscoresPCA, explainedPCA, coefforthPCA] = updatePCA(tmpFeatures);
  
  scoresPCA = bsxfun(@minus, features(:,1:end-2), mean(features(:,1:end-2)))*coeffPCA;
  %clusterIdx = [];
  useDifferentBasis = true;
  plotPCA();
  updateImage();
end

%--------------------------------------------------------------------------
function importPCAfeatures(~, ~)
  [fileName, pathName] = uigetfile({'*.csv'}, 'Select file', project.folder);
  if(fileName == 0 | ~exist([pathName fileName], 'file'))
    logMsg('Invalid file', 'e');
    return;
  end
  
  % Get the column name
  dividend = size(featuresNames, 1)+3;
  columnName = '';
  while (dividend > 0)
    modulo = mod(dividend - 1, 26);
    columnName = [char(65 + modulo), columnName];
    dividend = floor((dividend - modulo) / 26);
  end
  finalPos = [columnName, num2str(size(features, 1)+1)];
  finalPosMax = [columnName, num2str(size(features, 1)*2+1)];
  ncbar.automatic('Loading file');
  newFeatures = csvread([pathName fileName], 1, 0);
  ncbar.close();
  if(size(newFeatures, 1) ~= size(features, 1))
    logMsg(sprintf('Warning. External file contains %d ROI, but current analysis has %d ROI. Proceed with caution!', size(newFeatures,1), size(features, 1)), 'w');
  end
  features = newFeatures(:, 1:end-1);
  clusterIdx = newFeatures(:, end);
  colorModeChange([], [], 'cluster');
  [coeffPCA, scoresPCA, cscoresPCA, explainedPCA, coefforthPCA] = updatePCA(features);
  
  plotPCA();
  updateImage();
end

%--------------------------------------------------------------------------
function exportData(hObject, hEvent, ~)
    %(~, ~, extensions, defaultName, data, varargin)
    % Varargin: column names - sheet name - row names FFU
    if(isempty(clusterIdx))
        logMsg('No cluster information found', 'e');
        return;
    end
    
    newNames = featuresNames;
    newNames{end + 1} = 'ROI';
    newNames{end + 1} = 'experiment index';
    fullFile = [];

    for i = 1:numberOfClusters
        valid = find(clusterIdx == i);
        if(i == 1)
            fullFile = exportDataCallback(hObject, hEvent, {'*.csv'}, ...
                            [project.folder 'DataPCA'], ...
                            features(valid,:), ...
                            newNames, ...
                            ['cluster' num2str(i)]);
        else
            exportDataCallback(hObject, hEvent, {'*.csv'}, ...
                            [project.folder 'DataPCA'], ...
                            features(valid,:), ...
                            newNames, ...
                            ['cluster' num2str(i)], [], fullFile);
        end
    end
end

%--------------------------------------------------------------------------
function exportDataFeature(hObject, hEvent, ~)

    if(isempty(clusterIdx))
        logMsg('No cluster information found', 'e');
        return;
    end
    
    newNames = featuresNames;
    newNames{end + 1} = 'ROI';
    newNames{end + 1} = 'experiment index';
    fullFile = [];
    tmpFeatureListNames = cell(numberOfClusters*3, 1);
    for i = 1:numberOfClusters
        tmpFeatureListNames{1+(i-1)*3} = ['Cluster ' num2str(i)];
        tmpFeatureListNames{2+(i-1)*3} = ['ROI'];
        tmpFeatureListNames{3+(i-1)*3} = ['Experiment index'];
    end
    for i = 1:length(featuresNames)
        [hits, ~] = hist(clusterIdx, 1:numberOfClusters);
        tmpFeatureList = nan(max(hits), numberOfClusters*3);
        for j = 1:numberOfClusters
            valid = find(clusterIdx == j);
            tmpFeatureList(1:length(valid), 1+(j-1)*3) = features(valid, i);
            tmpFeatureList(1:length(valid), 2+(j-1)*3) = features(valid, end-1);
            tmpFeatureList(1:length(valid), 3+(j-1)*3) = features(valid, end);
        end
        if(i == 1)
            fullFile = exportDataCallback(hObject, hEvent, {'*.csv'}, ...
                            [project.folder 'DataPCAfeatures'], ...
                            tmpFeatureList, ...
                            tmpFeatureListNames, ...
                            newNames{i});
            if(isempty(fullFile))
                return;
            end
            ncbar('Exporting features ');
        else
            [fpa, fpb, fpc] = fileparts(fullFile);
            tmpFullFile = [fpa filesep fpb '_' num2str(i) fpc];
            exportDataCallback(hObject, hEvent, {'*.csv'}, ...
                            [project.folder 'DataPCAfeatures'], ...
                            tmpFeatureList, ...
                            tmpFeatureListNames, ...
                            newNames{i}, [], tmpFullFile);
        end
        
        ncbar.update(i/length(featuresNames));
    end
    ncbar.close();
end

%--------------------------------------------------------------------------
function exportDataFull(hObject, hEvent, ~)
    %(~, ~, extensions, defaultName, data, varargin)
    % Varargin: column names - sheet name - row names FFU
    if(isempty(clusterIdx))
        logMsg('No cluster information found', 'e');
        return;
    end
    
    newNames = featuresNames;
    newNames{end + 1} = 'ROI';
    newNames{end + 1} = 'experiment index';
    newNames{end + 1} = 'cluster index';
    fullFeatures = [features, clusterIdx];
    exportDataCallback(hObject, hEvent, {'*.csv'}, ...
                    [project.folder 'DataPCAfull'], ...
                    fullFeatures, ...
                    newNames);
    
end

%--------------------------------------------------------------------------
function exportKmeansGroups(~, ~)
  newGroupName = 'kmeansCluster';
  if(isempty(clusterIdx))
    logMsg('No clusters found. Did you run k-means?', 'e');
    return;
  end

  logMsgHeader('Exporting K-means clusters', 'start')
  ncbar('Exporting K-means clusters');
  validExperiments = project.(PCAfield).experimentList;
  for itv = 1:length(validExperiments)
    j = validExperiments(itv);
    %if(j == 1)
  Niterations = numberOfClusters*length(validExperiments);
  curIteration = 0;
    %  ncbar.update(0, 1, 'force');
    %end
    
    % Load the experiment
    experiment = loadExperiment([project.folderFiles project.experiments{j} '.exp'], 'project', project, 'verbose', false);
    % Remove old groups if they exist
    if(isfield(experiment.traceGroups, newGroupName))
      experiment.traceGroups = rmfield(experiment.traceGroups, newGroupName);
    end
    if(isfield(experiment.traceGroupsNames, newGroupName))
      experiment.traceGroupsNames = rmfield(experiment.traceGroupsNames, newGroupName);
    end
    orderTypes = fieldnames(experiment.traceGroupsOrder);
    for k = 1:length(orderTypes)
      if(isfield(experiment.traceGroupsOrder.(orderTypes{k}), newGroupName))
        experiment.traceGroupsOrder.(orderTypes{k}) = rmfield(experiment.traceGroupsOrder.(orderTypes{k}), newGroupName);
      end
    end
    % Create the new ones
    experiment.traceGroups.(newGroupName) = cell(numberOfClusters, 1);
    experiment.traceGroupsNames.(newGroupName) = cell(numberOfClusters, 1);
    for k = 1:numberOfClusters
      experiment.traceGroupsNames.(newGroupName){k} = num2str(k);
    end
    % Only create ROI ordering by default
    experiment.traceGroupsOrder.ROI.(newGroupName) = cell(numberOfClusters, 1);
    
    % Now assign the values
    for i = 1:numberOfClusters
      curIteration = curIteration+1;
      % That's the experiment idx
      validSubset = find((features(:, end) == j) & (clusterIdx == i));
      % That's the ROI idx
      validSubsetIdx = features(validSubset, end-1)';
      if(isempty(validSubsetIdx))
        ncbar.update(curIteration/Niterations);
        continue;
      end
      experiment.traceGroups.(newGroupName){i} = validSubsetIdx;
      experiment.traceGroupsOrder.ROI.(newGroupName){i} = sort(validSubsetIdx);
      
      ncbar.update(curIteration/Niterations);
    end
    % Now save the experiment
    saveExperiment(experiment, 'verbose', true);
  end
  ncbar.close();
end

%--------------------------------------------------------------------------
function exportAggregatedExperiments(~, ~, ~)

  %(gui, project, features, featuresNames)
  if(isempty(clusterIdx))
    logMsg('No clusters found. Did you run k-means?', 'e');
    return;
  end

  logMsgHeader('Generating new experiments', 'start')
  ncbar('Generating new experiments');
  validExperiments = project.(PCAfield).experimentList;
  Niterations = numberOfClusters*length(validExperiments);
  curIteration = 0;
  for i = 1:numberOfClusters
    %if(i == 1)
    %  ncbar.update(0, 1, 'force');
    %end
    newExperimentName = ['aggregatedKmeansCluster' num2str(i)];
    validName = checkExperimentName(newExperimentName, project, gui, true);
    if(isempty(validName))
        return;
    end
    valid = find(clusterIdx == i);
    % Now that we have the members of this cluster, get the data
    fullTraces = [];
    fullRawTraces = [];
    fullSpikes = [];
    fullROI = [];
    fullT = [];
    fullRawT = [];
    currFps = [];
    currTotalTime = NaN;
    for itv = 1:length(validExperiments)
      j = validExperiments(itv);
      curIteration = curIteration + 1;
      validSubset = find(features(valid,end) == j);
      validSubsetIdx = features(valid(validSubset), end-1)';
      if(isempty(validSubsetIdx))
        continue;
      end
      traces = [];
      fps = [];
      totalTime = [];
      spikes = [];
      ROI = [];
      t = [];
      load([project.folderFiles project.experiments{j} '.exp'], '-mat', 'traces');
      load([project.folderFiles project.experiments{j} '.exp'], '-mat', 'rawTraces');
      load([project.folderFiles project.experiments{j} '.exp'], '-mat', 'ROI');
      load([project.folderFiles project.experiments{j} '.exp'], '-mat', 't');
      load([project.folderFiles project.experiments{j} '.exp'], '-mat', 'rawT');
      load([project.folderFiles project.experiments{j} '.exp'], '-mat', 'fps');
      load([project.folderFiles project.experiments{j} '.exp'], '-mat', 'totalTime');
      load([project.folderFiles project.experiments{j} '.exp'], '-mat', 'spikes');
      % Consistency checks
      if(isempty(traces))
        logMsg(sprintf('traces missing on experiment %s', project.experiments{j}), 'w');
        traces = [];
      elseif(ischar(traces))
        tracesFile = [project.folder project.experiments{j} filesep 'data' filesep project.experiments{j} '_traces.dat'];
        if(exist(tracesFile, 'file'))
          load(tracesFile, '-mat');
        else
          logMsg(sprintf('traces missing on experiment %s', project.experiments{j}), 'w');
          traces = [];
        end
      end
      if(isempty(rawTraces))
        logMsg(sprintf('rawTraces missing on experiment %s', project.experiments{j}), 'w');
        rawTraces = [];
      elseif(ischar(rawTraces))
        rawTracesFile = [project.folder project.experiments{j} filesep 'data' filesep project.experiments{j} '_rawTraces.dat'];
        if(exist(rawTracesFile, 'file'))
          load(rawTracesFile, '-mat');
        else
          logMsg(sprintf('rawTraces missing on experiment %s', project.experiments{j}), 'w');
          rawTraces = [];
        end
      end
      if(isempty(ROI))
        logMsg(sprintf('ROI missing on experiment %s', project.experiments{j}), 'w');
        ROI = [];
      end
      if(isempty(spikes))
        logMsg(sprintf('spikes missing on experiment %s', project.experiments{j}), 'w');
        spikes = [];
      end
      if(isempty(t))
        logMsg(sprintf('t missing on experiment %s', project.experiments{j}), 'w');
        t = [];
      end
      if(isempty(rawT))
        logMsg(sprintf('rawT missing on experiment %s', project.experiments{j}), 'w');
        rawT = [];
      end
      if(isempty(fps))
        logMsg(sprintf('fps missing on experiment %s', project.experiments{j}),'e');
        return;
      end
      if(isempty(totalTime))
        logMsg(sprintf('totalTime missing on experiment %s', project.experiments{j}),'e');
        return;
      end
      % FPS check
      if(~isempty(currFps) && currFps ~= fps)
        logMsg(sprintf('Inconsistency detected on the fps of the experiment %s', project.experiments{j}), 'w');
      end
      currFps = fps;
      % Total time check
      if(~isnan(currTotalTime) && totalTime ~= currTotalTime)
        logMsg(sprintf('Inconsistency detected on totalTime at experiment %s. Keeping the minimum', project.experiments{j}), 'w');
      end
      currTotalTime = min(currTotalTime, totalTime);
      % Trace size check
      if(~isempty(traces) && ~isempty(fullTraces) && (size(fullTraces, 1) ~= size(traces, 1)))
        logMsg(sprintf('Inconsistency detected on trace sizes at experiment %s. Keeping the smallest', project.experiments{j}), 'w');
        if(size(fullTraces, 1) < size(traces, 1))
          traces = traces(1:size(fullTraces,1), :);
          rawTraces = rawTraces(1:size(fullRawTraces,1), :);
          t = fullT;
          rawT = fullRawT;
        else
          fullTraces = fullTraces(1:size(traces,1), :);
          fullRawTraces = fullRawTraces(1:size(rawTraces,1), :);
        end
      end
      % Let's start the assignments
      if(~isempty(traces))
        fullTraces = [fullTraces, traces(:, validSubsetIdx)];
      end
      if(~isempty(rawTraces))
        fullRawTraces = [fullRawTraces, rawTraces(:, validSubsetIdx)];
      end
      if(~isempty(t))
        fullT = t;
      end
      if(~isempty(rawT))
        fullRawT = rawT;
      end
      if(~isempty(spikes))
        fullSpikes = [fullSpikes; spikes(validSubsetIdx)];
      end
      % Need to change the ROI ID to reflect experiment number
      if(~isempty(ROI))
        for k = validSubsetIdx
            ROI{k}.ID = [num2str(ROI{k}.ID) ',' num2str(j)];
        end
        fullROI = [fullROI; ROI(validSubsetIdx)];
      end
      
      ncbar.update(curIteration/Niterations);
    end
    % Generate experiment metadata
    experiment = [];
    experiment.handle = 'none';
    experiment.name = newExperimentName;
    experiment.handle = [];
    experiment.metadata = 'no metadata';
    experiment.pixelType = 'none';
    experiment.numFrames = size(fullTraces,1);
    experiment.width = 0;
    experiment.height = 0;
    experiment.bpp = 0;
    experiment.folder = [project.folder experiment.name filesep];
    experiment.saveFile = ['..' filesep 'projectFiles' filesep experiment.name '.exp'];

    % The actual assignments
    experiment.fps = currFps;
    experiment.totalTime = currTotalTime;
    experiment.traces = fullTraces;
    experiment.rawTraces = fullRawTraces;
    experiment.spikes = fullSpikes;
    experiment.ROI = fullROI;
    experiment.t = fullT;
    experiment.rawT = fullRawT;

    if(ischar(validName))
      project.experiments{numel(project.experiments)+1} = experiment.name;
      if(isfield(project, 'labels'))
        project.labels{numel(project.experiments)} = 'PCA';
      end
    else
      % Else, it already exists, just overwrite
    end

    % Save new experiment
    saveExperiment(experiment, 'verbose', false, 'pbar', 0);
    setappdata(gui, 'project', project);
  end
  
  % So we reset the project tree
  resizeHandle = getappdata(gui, 'ResizeHandle');
  if(isa(resizeHandle,'function_handle'))
    resizeHandle([], [], 'resetTree');
  end
  
  ncbar.close();
  logMsgHeader('Done!', 'finish');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Utility functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------------------------------------------------------------
function [wcoeff, scores, cscores, explained, coefforth] = updatePCA(feat)
    [wcoeff,scores,latent,tsquared,explained] = pca(feat(:,1:end-2));
    coefforth = inv(diag(nanstd(feat(:,1:end-2))))*wcoeff;
    cscores = zscore(feat(:,1:end-2))*coefforth;
end


%--------------------------------------------------------------------------
function updateButtons()
    
end

%--------------------------------------------------------------------------
function updateMenus()
%   
%     if(isfield(experiment, 'spikeFeatures'))
%         hs.menuViewFeatures.Checked = 'on';
%     end
end

%--------------------------------------------------------------------------
function updateColor()
%   childPlot = hs.mainWindowFramesAxes.Children;
%   
%   for i = 1:length(childPlot)
%     if(isa(childPlot(i), 'matlab.graphics.chart.primitive.Scatter'))
%       childPlot(i).CData = colorList;
%     end
%   end
  redoPlot();
end

%--------------------------------------------------------------------------
function updateImage(~, ~, ~)
  lh = findall(hs.mainWindow, 'Type', 'Legend');
  axes(hs.mainWindowFramesAxes);
  cla(hs.mainWindowFramesAxes);

  axis tight;
  hold on;

  for itt = 1:length(uniqueColors)
    valid = (colorList == uniqueColors(itt));
    scatter(scoresPCA(valid,1), scoresPCA(valid,2), 8, uniqueColorsCmap(colorList(valid), :), 'fill');
  end
  
  if(~isempty(lh))
    legend(colorLegend);
  end

  %gscatter(scoresPCA(:,1), scoresPCA(:,2), colorList);
  
  xlabel('1st principal component');
  ylabel('2nd principal component');
  %ylim([0.5 length(currentOrder)+0.5]);
  %xlim([min(experiment.t) max(experiment.t)]);
  box on;
  hold on;
end

%--------------------------------------------------------------------------
function redoPlot()
  switch currentPlot
    case 'pca'
      plotPCA();
    case 'pcafull'
      plotPCAfull([], [], true);
    case 'features'
      plotFeatures([], [], true);
    otherwise
  end
end

%--------------------------------------------------------------------------
function cleanMenu(h)
    if(nargin == 0)
        h = gcf;
    end
    a = findall(h);
    b = findall(a, 'ToolTipString', 'Save Figure');
    set(b,'Visible','Off');
    b = findall(a, 'ToolTipString', 'Show Plot Tools');
    set(b,'Visible','Off');
    b = findall(a, 'ToolTipString', 'Hide Plot Tools');
    set(b,'Visible','Off');
    b = findall(a, 'ToolTipString', 'Open File');
    set(b,'Visible','Off');
    b = findall(a, 'ToolTipString', 'New Figure');
    set(b,'Visible','Off');
    %b = findall(a, 'ToolTipString', 'Insert Legend');
    %set(b,'Visible','Off');
    b = findall(a, 'ToolTipString', 'Insert Colorbar');
    set(b,'Visible','Off');
    %b = findall(a, 'ToolTipString', 'Data Cursor');
    %set(b,'Visible','Off');
    b = findall(a, 'ToolTipString', 'Rotate 3D');
    set(b,'Visible','Off');
    b = findall(a, 'ToolTipString', 'Edit Plot');
    set(b,'Visible','Off');
    b = findall(a, 'ToolTipString', 'Print Figure');
    set(b,'Visible','Off');
    b = findall(a, 'ToolTipString', 'Brush/Select Data');
    set(b,'Visible','Off');
    b = findall(a, 'ToolTipString', 'Link Plot');
    set(b,'Visible','Off');
    b = findall(a, 'ToolTipString', 'Show Plot Tools and Dock Figure');
    set(b,'Visible','Off');
end

end