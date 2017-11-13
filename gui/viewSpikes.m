function [hFigW, experiment] = viewSpikes(experiment)
% VIEWSPIKES Shows the experiment spikes
%
% USAGE:
%    viewSpikes(gui, experiment)
%
% INPUT arguments:
%    gui - gui handle
%
%    experiment - experiment structure from loadExperiment
%
% OUTPUT arguments:
%    hFigW - figure handle
%
% EXAMPLE:
%    hFigW = viewSpikes(gui, experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also loadExperiment

%#ok<*AGROW>
%#ok<*ASGLU>
%#ok<*FXUP>

%% Initialization
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
gui = gcbf;
minGridBorder = 1;

LineFormat = [];
LineFormat.Color = [0, 0, 0.5];
LineFormat.LineWidth = 2;
LineFormat.LineStyle = '-';

ROIid = getROIid(experiment.ROI);

currentOrder = 1:length(experiment.spikes);

currentSelectionString = 'everything';
firingRateNbins = 100;
originalExperiment = experiment;
experiment = checkGroups(experiment);

%% Create components
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
hs.mainWindow = figure('Visible','off',...
                       'Resize','on',...
                       'Toolbar', 'figure',...
                       'Tag','viewTraces', ...
                       'DockControls','off',...
                       'NumberTitle', 'off',...
                       'ResizeFcn', @resizeCallback, ...
                       'CloseRequestFcn', @closeCallback,...
                       'MenuBar', 'none',...
                       'Name', ['Spike explorer: ' experiment.name]);
hFigW = hs.mainWindow;
hFigW.Position = setFigurePosition(gui, 'width', 800, 'height', 600);
setappdata(hFigW, 'currentOrder', currentOrder);
setappdata(hFigW, 'experiment', experiment);
resizeHandle = hFigW.ResizeFcn;
setappdata(hFigW, 'ResizeHandle', resizeHandle);
if(~isempty(gui))
  setappdata(hFigW, 'logHandle', getappdata(gcbf, 'logHandle'));
end

% Set the menu
hs.menu.file.root = uimenu(hs.mainWindow, 'Label', 'File');
uimenu(hs.menu.file.root, 'Label', 'Exit and discard changes', 'Callback', {@closeCallback, false});
uimenu(hs.menu.file.root, 'Label', 'Exit and save changes', 'Callback', {@closeCallback, true});
uimenu(hs.menu.file.root, 'Label', 'Exit (default)', 'Callback', @closeCallback);

hs.menu.traces.root = uimenu(hs.mainWindow, 'Label', 'Trace selection');

% This order due to cross references
hs.menu.sort.root = uimenu(hs.mainWindow, 'Label', 'Sort by', 'Tag', 'sort');
hs.menu.sort.ROI = uimenu(hs.menu.sort.root, 'Label', 'ROI',  'Checked', 'on');
if(isfield(experiment, 'similarityOrder'))
  hs.menu.sort.similarity = uimenu(hs.menu.sort.root, 'Label', 'similarity');
end
if(isfield(experiment, 'FCA'))
  hs.menu.sort.FCA = uimenu(hs.menu.sort.root, 'Label', 'FCA');
end

% Finish the selection menus
hs.menu.traces.selection = generateSelectionMenu(experiment, hs.menu.traces.root);
% Assigning the callbacks
hs.menu.sort.ROI.Callback = {@updateSortingMethod, 'ROI', hFigW};
if(isfield(experiment, 'similarityOrder'))
  hs.menu.sort.similarity.Callback = {@updateSortingMethod, 'similarity', hFigW};
end
if(isfield(experiment, 'FCA'))
  hs.menu.sort.FCA.Callback = {@updateSortingMethod, 'FCA', hFigW};
end

%hs.menuPreferences = uimenu(hs.mainWindow, 'Label', 'Preferences', 'Callback', @menuPreferences);
hs.menuPreferences = uimenu(hs.mainWindow, 'Label', 'Preferences');
hs.menuPreferencesLineWidth = uimenu(hs.menuPreferences, 'Label', 'Line width', 'Callback', @menuPreferencesLineWidth);
hs.menuPreferencesLineStyle = uimenu(hs.menuPreferences, 'Label', 'Line style', 'Callback', @menuPreferencesLineStyle);

hs.menu.analysis.root = uimenu(hs.mainWindow, 'Label', 'Analysis');
hs.menu.analysis.features = uimenu(hs.menu.analysis.root, 'Label', 'Features', 'Callback', @menuAnalysisFeatures);
hs.menu.analysis.detectConflicts = uimenu(hs.menu.analysis.root, 'Label', 'Detect conflicting spikes', 'Callback', @menuAnalysisDetectConflicts);
hs.menu.analysis.solveConflicts = uimenu(hs.menu.analysis.root, 'Label', 'Remove conflicting spikes', 'Callback', @menuAnalysisRemoveConflicts);

hs.menuView = uimenu(hs.mainWindow, 'Label', 'View');
hs.menuViewFiringRate = uimenu(hs.menuView, 'Label', 'Firing rate', 'Callback', @menuViewFiringRate);
hs.menuViewSpikeCount = uimenu(hs.menuView, 'Label', 'Spike count', 'Callback', @menuViewSpikeCount, 'Separator', 'on');
hs.menuViewCorrPlot = uimenu(hs.menuView, 'Label', 'Correlation plot', 'Callback', @menuViewCorrPlot);
hs.menuViewMainStatistics = uimenu(hs.menuView, 'Label', 'Main statistics', 'Callback', @menuViewMainStatistics);
hs.menuViewMainStatistics = uimenu(hs.menuView, 'Label', 'Spatio-temporal profile', 'Callback', @menuViewProfile);

hs.menuExport = uimenu(hs.mainWindow, 'Label', 'Export');
uimenu(hs.menuExport, 'Label', 'Figure', 'Callback', @exportTraces);
uimenu(hs.menuExport, 'Label', 'Spikes', 'Callback', @exportSpikes);
uimenu(hs.menuExport, 'Label', 'Features', 'Callback', @exportSpikesFeatures);


% Main grid
hs.mainWindowSuperBox = uix.VBox('Parent', hs.mainWindow);
hs.mainWindowGrid = uix.Grid('Parent', hs.mainWindowSuperBox);

%% COLUMN START
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Empty left
uix.Empty('Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowGrid);

%% COLUMN START
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
uix.Empty('Parent', hs.mainWindowGrid);

% Plot --------------------------------------------------------------------
hs.mainWindowFramesPanel = uix.Panel('Parent', hs.mainWindowGrid, 'Padding', 5, 'BorderType', 'none');
hs.mainWindowFramesAxes = axes('Parent', hs.mainWindowFramesPanel);
%set(hs.mainWindowFramesAxes, 'ButtonDownFcn', @rightClick);

uix.Empty('Parent', hs.mainWindowGrid);

%% COLUMN START
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Empty right
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

%% Final init
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
set(hs.mainWindowGrid, 'Widths', [minGridBorder -1 minGridBorder], ...
  'Heights', [minGridBorder -1 minGridBorder]);
cleanMenu();
updateButtons();

selectGroup([], [], 'everything', 1);
if(isfield(experiment, 'similarityOrder') && ~isempty(experiment.similarityOrder))
  updateSortingMethod([], [], 'similarity', hFigW, experiment);
else
  updateSortingMethod([], [], 'ROI', hFigW, experiment);
end

% Finish the new log panel
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

hs.mainWindow.Visible = 'on';
updateImage();
updateMenu();

if(~isempty(gui))
  parentHandle = getappdata(hFigW, 'logHandle');
  setappdata(hFigW, 'logHandle', [parentHandle hs.logPanelEditBox]);
else
  setappdata(hs.mainWindow, 'logHandle', hs.logPanelEditBox);
end
if(isempty(gui))
  waitfor(hFigW);
end

%% Callbacks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------------------------------------------------------------
function resizeCallback(~, ~)
  updateImage();
end

%--------------------------------------------------------------------------
function closeCallback(~, ~, varargin)
  if(isequaln(originalExperiment, experiment))
    experimentChanged = false;
  else
    experimentChanged = true;
  end
  
  guiSave(experiment, experimentChanged, varargin{:});
  
  delete(hFigW);
end

%--------------------------------------------------------------------------
function menuPreferencesLineWidth(~, ~)
    answer = inputdlg('Line width', 'Line width', [1 60],{num2str(LineFormat.LineWidth)});
    if(isempty(answer))
        return;
    end
    LineFormat.LineWidth = str2double(answer{1});
    updateImage();
end

%--------------------------------------------------------------------------
function menuPreferencesLineStyle(~, ~)
    answer = inputdlg('Line style', 'Line style', [1 60],{LineFormat.LineStyle});
    if(isempty(answer))
        return;
    end
    LineFormat.LineStyle = answer{1};
    updateImage();
end

%--------------------------------------------------------------------------
function menuAnalysisFeatures(~, ~)
  [success, ~, experiment] = preloadOptions(experiment, spikeFeaturesOptions, gui, true, false);
  if(success)
    experiment = getSpikesFeatures(experiment, experiment.spikeFeaturesOptionsCurrent);
    
    updateMenu();
    updateImage();
%     if(strcmpi(hs.menuPreferencesShowPatterns.Checked, 'on'))
%       hs.menuPreferencesShowPatterns.Checked = 'off';
%       menuPreferencesShowPatterns([], []);
%     end
  end
end

%--------------------------------------------------------------------------
function menuAnalysisDetectConflicts(~, ~)
  [success, ~, experiment] = preloadOptions(experiment, spikeDetectConflictsOptions, gui, true, false);
  if(success)
    experiment = spikeDetectConflicts(experiment, experiment.spikeDetectConflictsOptionsCurrent);
    updateMenu();
    updateImage();
  end
end

%--------------------------------------------------------------------------
function menuAnalysisRemoveConflicts(~, ~)
  [success, ~, experiment] = preloadOptions(experiment, spikeRemoveConflictsOptions, gui, true, false);
  if(success)
    experiment = spikeRemoveConflicts(experiment, experiment.spikeRemoveConflictsOptionsCurrent);
    updateMenu();
    updateImage();
  end
end

%--------------------------------------------------------------------------
function exportTraces(~, ~)
  [fileName, pathName] = uiputfile({'*.png'; '*.tiff'; '*.pdf';'*.eps'}, 'Save figure', [experiment.folder 'spikes_' currentSelectionString]);

  if(fileName ~= 0)
    axes(hs.mainWindowFramesAxes);
    title('Spikes');
    export_fig([pathName fileName], '-r300', hs.mainWindowFramesAxes);
    title([]);
  end
end

%--------------------------------------------------------------------------
function exportSpikes(~, ~)
  currentOrder = getappdata(hFigW, 'currentOrder');
  [fileName, pathName] = uiputfile({'*.txt'; '*.dat'; '*.csv'}, 'Export Spikes', [experiment.folder filesep experiment.name '_spikes.txt']);
  if(fileName == 0)
    return;
  end
  [fpa, fpb, fpc] = fileparts(fileName);
  logMsgHeader('Exporting spike data for the current selection', 'start');
  ROIid = getROIid(experiment.ROI);
  N = [];
  T = [];
  
  for it = 1:length(currentOrder)
    if(~all(isnan(experiment.spikes{currentOrder(it)}')))
      T = [T; experiment.spikes{currentOrder(it)}'];
      N = [N; ones(size(experiment.spikes{currentOrder(it)}))'*ROIid(currentOrder(it))];
    end
  end
  mat = double([N, T]);
  mat = sortrows(mat, 2);
  if(strcmpi(fpc, '.csv'))
    exportDataCallback([], [], [], ...
                            [], ...
                            mat, ...
                            {'ROI', 'time (s)'}, ...
                            [], [], [pathName fileName]);
  else
    fid = fopen([pathName fileName], 'w');
    fprintf(fid, '%d %.3f\n', mat');
    fclose(fid);
  end
  logMsgHeader('Done!', 'finish');
end

%--------------------------------------------------------------------------
function exportSpikesFeatures(~, ~)
  currentOrder = getappdata(hFigW, 'currentOrder');
  newNames = experiment.spikeFeaturesNames;
  newNames{end + 1} = 'ROI';
  ROIid = getROIid(experiment.ROI);
  fullFeatures = [experiment.spikeFeatures(currentOrder, :), ROIid(currentOrder)];
  fileName = exportDataCallback([], [], {'*.csv'}, ...
                            [experiment.folder filesep experiment.name 'SpikeFeatures'], ...
                            fullFeatures, ...
                            newNames);
  if(isempty(fileName))
    return;
  end
  logMsgHeader('Exporting spike features for the current selection', 'start');
  logMsgHeader('Done!', 'finish');
  
end

%--------------------------------------------------------------------------
function menuViewCorrPlot(~, ~, ~)
  currentOrder = getappdata(hFigW, 'currentOrder');
  if(isfield(experiment, 'spikeFeatures') && ~isempty(experiment.spikeFeatures))
    corrplot(experiment.spikeFeatures(currentOrder, :),'type','Pearson','testR','on', 'varNames', ...,
         experiment.spikeFeaturesNames);
    hfig = gcf;
    uimenu(hfig, 'Label', 'Export',  'Callback', {@exportFigCallback, {'*.png';'*.tiff'}, [experiment.folder 'corrPlot']});
  else
    logMsg('Spike features not found', 'e');
  end
end

%--------------------------------------------------------------------------
function menuViewProfile(~, ~, ~)
  figure;
  xyz = [];
  ROIcenters = [];
  firingRate = [];
  currentOrder = getappdata(hFigW, 'currentOrder');
    
  for it = 1:length(currentOrder)
    spikeTimes = experiment.spikes{currentOrder(it)}(:);
    if(~isnan(spikeTimes))
      xyz = [xyz; experiment.ROI{currentOrder(it)}.center(1)*ones(size(spikeTimes)) experiment.ROI{currentOrder(it)}.center(2)*ones(size(spikeTimes)) spikeTimes]; 
      ROIcenters = [ROIcenters; experiment.ROI{currentOrder(it)}.center];
      firingRate = [firingRate; length(spikeTimes)];
    end
  end
  firingRate = firingRate/(max(xyz(:,3)) - min(xyz(:,3)));
  scatter3(xyz(:,1), xyz(:,2), xyz(:,3), 16, 'fill');
  box on;
  xlim([1 experiment.width]);
  ylim([1 experiment.height]);
  
  bins = 512;
  pixelsRadius = 50;
  averageBins = 128;
  
  network.X = ROIcenters(:,1);
  network.Y = ROIcenters(:,2);
  network.totalSizeX = bins;
  network.totalSizeY = bins;
  xbins = linspace(0, experiment.width, experiment.width/experiment.height*averageBins+1);
  ybins = linspace(0, experiment.height, averageBins+1);


  network.RS = [];


  mode = 'center';
  coarseRadius = pixelsRadius;
  averageType = 'perNeuron';

  [mx, my, mz] = neuronAverageDensityMap(network, firingRate,...
    'mode', mode, 'coarseRadius', coarseRadius, 'averageType', averageType, ...
    'bins', averageBins, 'measureType', 'full', 'periodic', false, 'xbins', xbins, 'ybins', ybins);
  mz = mz/(nansum(mz(:))*(network.totalSizeX/bins)^2);

  hFig = figure;
  h = fspecial('gaussian', [10 10], 3);
  mz = filter2(h, mz);
  pcolor(mx, my, mz);
  %contourf(mx, my, mz, 7);
  axis equal;
  shading flat;
  axis ij;
  box on;
  xlabel('X (pixels)');
  ylabel('Y (pixels)');
  title('event rate (Hz)');
  set(gca,'color','w')
  set(gcf,'color','w')
  colorbar;
  generateFullExportFigureMenu(hFig, [experiment.folder 'firingRateMap']);

  % Now the lorenz curve
  lorenzX = (1:length(mz(:)))/length(mz(:));
  lorenzY = cumsum(sort(mz(:),'descend'))/sum(mz(:));

  % generate a surrogated curve first
  Nsurrogates = 10;
  lorenzYs = zeros(length(lorenzY), Nsurrogates);
  for it = 1:Nsurrogates
    [smx, smy, smz] = neuronAverageDensityMap(network, firingRate(randperm(length(firingRate))),...
      'mode', mode, 'coarseRadius', coarseRadius, 'averageType', averageType, ...
      'bins', averageBins, 'measureType', 'full', 'periodic', false, 'xbins', xbins, 'ybins', ybins);
    smz = smz/(nansum(smz(:))*(network.totalSizeX/bins)^2);

    lorenzYs(:, it) = cumsum(sort(smz(:),'descend'))/sum(smz(:));
  end
  hFig = figure;
  cmap = lines(5);
  h1 = plot(lorenzX, lorenzY, 'Color', cmap(2, :));
  hold on;
  %plot(lorenzXs, mean(lorenzYs, 2),'k');
  h = ciplot(mean(lorenzYs, 2)-1.96*std(lorenzYs,0,2), mean(lorenzYs, 2)+1.96*std(lorenzYs,0,2), lorenzX, cmap(1, :));
  set(h, 'FaceAlpha', 0.5, 'EdgeColor','none');
  h2 = plot(lorenzX, mean(lorenzYs, 2), 'Color', cmap(1, :));
  plot([0 1], [0 1],'k--');
  xlabel('Ordered area of # events per pixel');
  ylabel('Acumulated probability');
  title('Lorenz curve');
  axis equal;
  xlim([0 1]);
  ylim([0 1]);

  legend([h1, h2], sprintf('AUC = %.2f', trapz(lorenzX, lorenzY)), sprintf('AUC surr = %.2f', trapz(lorenzX, mean(lorenzYs, 2))), 'Location','NW');
  legend boxoff;
  generateFullExportFigureMenu(hFig, [experiment.folder 'firingRateCentersLorenz']);  
end

%--------------------------------------------------------------------------
function menuViewMainStatistics(~, ~, ~)
  currentOrder = getappdata(hFigW, 'currentOrder');
  if(~isfield(experiment, 'spikeFeatures') || isempty(experiment.spikeFeatures))
    logMsg('Spike features not found', 'e');
    return;
  end
    Nfeatures = length(experiment.spikeFeaturesNames);
    hFig = figure('Position', [200 200 650 400]);
    ax = multigap_subplot(3, ceil(Nfeatures/3), 'margin_LR', [0.1 0.1], 'gap_C', 0.07, 'gap_R', 0.1, 'margin_TB', 0.1);
    if(numel(ax) > Nfeatures)
      set(ax(Nfeatures+1:end), 'Visible', 'off');
    end
    featureList = 1:Nfeatures;
    
    for it = 1:length(featureList)
        h = ax(it);
        currData = experiment.spikeFeatures(currentOrder, featureList(it));
        xl = experiment.spikeFeaturesNames{featureList(it)};
        axes(h);
        [a, b] = hist(h, currData, sshist(currData));
        bar(b, a/trapz(b, a), 'FaceColor', [1 1 1]*0.8, 'EdgeColor', [1 1 1]*0.6);
        hold on;
        %if(any(currData) <= 0 || any(isnan(currData)))
            [f, xi] = ksdensity(currData); % Not using support
        %else
            %[f, xi] = ksdensity(currData, 'support', 'positive');
        %end
        valid = find(xi > 0);
        hk = plot(xi(valid), f(valid), 'LineWidth', 2);
        hx = xlabel(h, xl);
        %hx.Units = 'normalized';
        ylabel(h, 'PDF');
        legend(hk, sprintf('<>= %.2f', nanmean(currData)));
        legend('boxoff');
    end
    exportMenu = uimenu(hFig, 'Label', 'Export');
    uimenu(exportMenu, 'Label', 'Figure', 'Callback', {@exportFigCallback, {'*.png';'*.tiff';'*.eps';'*.pdf'}, [experiment.folder 'spikeStatistics']});
    uimenu(exportMenu, 'Label', 'Data', 'Callback', {@exportDataCallback, {'*.csv'}, ...
        [experiment.folder 'spikeStatisticsData'], ...
        [ROIid(currentOrder), experiment.spikeFeatures(currentOrder, featureList(:))], ...
        ['ROI ID'; experiment.spikeFeaturesNames(featureList(:))], ...
        experiment.name});
end

%--------------------------------------------------------------------------
function menuViewFiringRate(~, ~, ~)
  currentOrder = getappdata(hFigW, 'currentOrder');
    answer = inputdlg('Number of bins', 'Number of bins', [1 60],{num2str(firingRateNbins)});
    if(isempty(answer))
        return;
    end
    firingRateNbins = str2double(answer{1});
    Nbins = firingRateNbins;
    dt = experiment.t(2)-experiment.t(1);
    x = linspace(experiment.t(1)-dt/2, experiment.t(end)+dt/2, Nbins);
    h = zeros(size(x));
    for i = 1:(length(x)-1)
        for j = 1:length(experiment.spikes(currentOrder))
            valid = find(experiment.spikes{currentOrder(j)} > x(i) & experiment.spikes{currentOrder(j)} <= x(i+1));
            h(i) = h(i) + length(valid);
        end
    end
    %h = h/(x(2)-x(1))/length(spikes);
    %h = h/(x(2)-x(1))/length(groupTraces{1});
    h = h/(x(2)-x(1));
    hfig = figure;
    %plot(x,h,'o-');
    bar(x, h);
    box on;
    xlabel('time (s)');
    ylabel('Total firing rate (Hz)');
    uimenu(hfig, 'Label', 'Export',  'Callback', {@exportFigCallback, {'*.png';'*.tiff'}, [experiment.folder 'peelingFiringRate']});
    title('Total firing rate');
end

%--------------------------------------------------------------------------
function menuViewSpikeCount(~, ~, ~)
  currentOrder = getappdata(hFigW, 'currentOrder');
  answer = inputdlg('Number of bins', 'Number of bins', [1 60],{num2str(firingRateNbins)});
  if(isempty(answer))
      return;
  end
  firingRateNbins = str2double(answer{1});
  Nbins = firingRateNbins;
  dt = experiment.t(2)-experiment.t(1);
  x = linspace(experiment.t(1)-dt/2, experiment.t(end)+dt/2, Nbins);
  h = zeros(size(x));
  for i = 1:(length(x)-1)
      for j = 1:length(experiment.spikes(currentOrder))
          valid = find(experiment.spikes{currentOrder(j)} > x(i) & experiment.spikes{currentOrder(j)} <= x(i+1));
          h(i) = h(i) + length(valid);
      end
  end
  %h = h/(x(2)-x(1))/length(spikes);
  %h = h/(x(2)-x(1))/length(groupTraces{1});
  %h = h/(x(2)-x(1));
  hfig = figure;
  %plot(x,h,'o-');
  bar(x, h);
  xlim([x(1) x(end)]);
  box on;
  xlabel('time (s)');
  ylabel('Number of spikes');
  uimenu(hfig, 'Label', 'Export',  'Callback', {@exportFigCallback, {'*.png';'*.tiff'}, [experiment.folder 'spikeCount']});
  title('Number of spikes');
end

%% Utility functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------------------------------------------------------------
function updateButtons()
    
end

%--------------------------------------------------------------------------
function updateImage()
  currentOrder = getappdata(hFigW, 'currentOrder');
  axes(hs.mainWindowFramesAxes);
  cla(hs.mainWindowFramesAxes);
  Nspikes = 0;
%     subSpikes = cell(length(experiment.spikes), 1);
%     for it = 1:length(subSpikes)
%         subSpikes{it} = NaN;
%     end
  for it = 1:length(currentOrder)
      Nspikes = Nspikes+sum(~isnan(experiment.spikes{currentOrder(it)}(:)));
%         subSpikes{currentOrder(it)} = experiment.spikes{currentOrder(it)}(:)';
  end
  experiment.spikes = cellfun(@(x)x(:)', experiment.spikes, 'UniformOutput', false);
  if(Nspikes > 0)
%         [x,y]=plotSpikeRaster(subSpikes, 'PlotType', 'vertLine', 'LineFormat', LineFormat);
      [x,y]=plotSpikeRaster(experiment.spikes(currentOrder), 'PlotType', 'vertLine', 'LineFormat', LineFormat);
  end
  
  if(isfield(experiment, 'conflictingSpikes'))
    LineFormatC = LineFormat;
    LineFormatC.Color = [1 0 0];
    cSpikes = experiment.spikes;
    for i = 1:length(cSpikes)
      cSpikes{i} = cSpikes{i}(experiment.conflictingSpikes{i});
    end
    cSpikes = cellfun(@(x)x(:)', cSpikes, 'UniformOutput', false);
    if(sum(cellfun(@length, cSpikes)) > 0)
      [x,y]=plotSpikeRaster(cSpikes(currentOrder), 'PlotType', 'vertLine', 'LineFormat', LineFormatC);
    end
  end
  %axis tight;
  %hs.mainWindowFramesAxes.Units = 'normalized';
  %hs.mainWindowFramesAxes.OuterPosition = [0 0 1 1];
  xlabel('time (s)');
  ylabel('ordered ROI subset');
  ylim([0.5 length(currentOrder)+0.5]);
  xlim([min(experiment.t) max(experiment.t)]);
  box on;
  hold on;
  set(hs.mainWindowFramesAxes, 'LooseInset', [0,0,0,0]);
end

%--------------------------------------------------------------------------
function updateMenu()
  if(isfield(experiment, 'spikeFeatures'))
    hs.menu.analysis.features.Checked = 'on';
  else
    hs.menu.analysis.features.Checked = 'off';
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
    b = findall(a, 'ToolTipString', 'Insert Legend');
    set(b,'Visible','Off');
    b = findall(a, 'ToolTipString', 'Insert Colorbar');
    set(b,'Visible','Off');
    b = findall(a, 'ToolTipString', 'Data Cursor');
    set(b,'Visible','Off');
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
