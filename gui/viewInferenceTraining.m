function [hFigW, experiment] = viewInferenceTraining(experiment)
% VIEWINFERENCETRAINING screen to check performance of spike inference algorithms on single traces
%
% USAGE:
%    viewInferenceTraining(experiment)
%
% INPUT arguments:
%
%    experiment - experiment structure from loadExperiment
%
% OUTPUT arguments:
%    hFigW - figure handle
%
%    experiment - experiment structure

%
% EXAMPLE:
%    hFigW = viewInferenceTraining(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
% See also loadExperiment

%#ok<*AGROW>
%#ok<*ASGLU>
%#ok<*FXUP>
%#ok<*INUSD>
 
%% Initialization
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
gui = gcbf;
textFontSize = 10;
minGridBorder = 1;
trainingMode = 'peeling';
selectedROI = 1;
try
  if(~isfield(experiment, 'inferenceTrainingData'))
    experiment.inferenceTrainingData = [];
  elseif(isfield(experiment.inferenceTrainingData, 'mode'))
    trainingMode = experiment.inferenceTrainingData.mode;
  end
catch
end
ROIid = getROIid(experiment.ROI);
try
  experiment = loadTraces(experiment, 'smoothed', 'pbar', []);
catch
  experiment = loadTraces(experiment, 'raw', 'pbar', []);
end
if(isfield(experiment, 'traces'))
  traces = experiment.traces;
  t = experiment.t;
else
  traces = experiment.rawTraces;
  t = experiment.rawT;
end
  
originalExperiment = experiment;
experiment = checkGroups(experiment);
[~, curOptions] = preloadOptions(experiment, inferenceTrainingOptions, gui, false, false);
experiment.inferenceTrainingOptionsCurrent = curOptions;

try
  setappdata(gui, 'inferenceTrainingOptionsCurrent', experiment.inferenceTrainingOptionsCurrent);
catch
end

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
                       'Name', ['Spike inference training: ' experiment.name]);
hFigW = hs.mainWindow;
hFigW.Position = setFigurePosition(gui, 'width', 800, 'height', 500);

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

hs.menu.preferences.root = uimenu(hs.mainWindow, 'Label', 'Preferences');
hs.menu.preferences.plotOptions = uimenu(hs.menu.preferences.root, 'Label', 'Plotting options', 'Callback', @menuPlottingOptions);

hs.menuExport = uimenu(hs.mainWindow, 'Label', 'Export');
hs.menuExportFigure = uimenu(hs.menuExport, 'Label', 'Figure', 'Callback', @exportTraces);
hs.menuExportFigure = uimenu(hs.menuExport, 'Label', 'Editable figure', 'Callback', @exportFigure);
hs.menuExportData = uimenu(hs.menuExport, 'Label', 'Data',  'Callback', @exportData);

% Main grid
hs.mainWindowGrid = uix.Grid('Parent', hs.mainWindow);

%% COLUMN START
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Empty left
uix.Empty('Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowGrid);

%% COLUMN START
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
uix.Empty('Parent', hs.mainWindowGrid);

% Plot --------------------------------------------------------------------
hs.mainWindowFramesPanel = uix.Panel('Parent', hs.mainWindowGrid, 'Padding', 5, 'BorderType', 'none');
hs.mainWindowFramesAxes = axes('Parent', uicontainer('Parent', hs.mainWindowFramesPanel));
set(hs.mainWindowFramesAxes, 'ButtonDownFcn', @rightClick);


% Training buttons -----------------------------------------------------------
hs.mainWindowBottomButtons = uix.HBox( 'Parent', hs.mainWindowGrid);
%uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'Burst detection (threshold)', 'FontSize', textFontSize, 'callback', @burstDetectionThreshold);
uix.Empty('Parent', hs.mainWindowBottomButtons);
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'Peeling', 'FontSize', textFontSize, 'callback', {@inferenceTraining, 'peeling', []});
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'Foopsi', 'FontSize', textFontSize, 'callback', {@inferenceTraining, 'foopsi', []});
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'Schmitt', 'FontSize', textFontSize, 'callback', {@inferenceTraining, 'schmitt', []});
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'oasis', 'FontSize', textFontSize, 'callback', {@inferenceTraining, 'oasis', []});
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'MLspike', 'FontSize', textFontSize, 'callback', {@inferenceTraining, 'MLspike', []});
uix.Empty('Parent', hs.mainWindowBottomButtons);
%uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'Options', 'FontSize', textFontSize, 'callback', @inferenceOptions);
set(hs.mainWindowBottomButtons, 'Widths', [-1 1 1 1 1 1 -1]*125, 'Padding', 15, 'Spacing', 5);


% Pages buttons -----------------------------------------------------------
hs.mainWindowPagesButtons = uix.HBox( 'Parent', hs.mainWindowGrid);
%uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'Burst detection (threshold)', 'FontSize', textFontSize, 'callback', @burstDetectionThreshold);
uix.Empty('Parent', hs.mainWindowPagesButtons);
uicontrol('Parent', hs.mainWindowPagesButtons, 'String', '< Previous ROI', 'FontSize', textFontSize, 'callback', {@inferenceTraining, [], 'previousROI'});
uix.Empty('Parent', hs.mainWindowPagesButtons);
uicontrol('Parent', hs.mainWindowPagesButtons, 'String', 'Random ROI', 'FontSize', textFontSize, 'callback', {@inferenceTraining, [], 'randomROI'});
uix.Empty('Parent', hs.mainWindowPagesButtons);
uicontrol('Parent', hs.mainWindowPagesButtons, 'String', '> Next ROI', 'FontSize', textFontSize, 'callback', {@inferenceTraining, [], 'nextROI'});
uix.Empty('Parent', hs.mainWindowPagesButtons);
%set(hs.mainWindowPagesButtons, 'ButtonSize', [125 15], 'Padding', 0, 'Spacing', 15);
set(hs.mainWindowPagesButtons, 'Widths', [-1 1 1 1 1 1 -1]*125, 'Padding', 15, 'Spacing', 5);

% Now the log panel
hs.logPanelParent = uix.Panel('Parent', hs.mainWindowGrid, ...
                               'BorderType', 'none');
hs.logPanel = uicontrol('Parent', hs.logPanelParent, ...
                      'style', 'edit', 'max', 5, 'Background','w');
                    
uix.Empty('Parent', hs.mainWindowGrid);

%% COLUMN START
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Empty right
uix.Empty('Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowGrid);

%% Final init
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
set(hs.mainWindowGrid, 'Widths', [minGridBorder -1 minGridBorder], ...
  'Heights', [minGridBorder -1 55 55 100 minGridBorder]);
cleanMenu();
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

if(~isempty(gui))
  parentHandle = getappdata(hFigW, 'logHandle');
  setappdata(hFigW, 'logHandle', [parentHandle hs.logPanelEditBox]);
else
  setappdata(hs.mainWindow, 'logHandle', hs.logPanelEditBox);
end


updateImage();
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
function menuPlottingOptions(~, ~)
  [success, curOptions] = preloadOptions(experiment, inferenceTrainingOptions, gui, true, false);
  if(success)
    experiment.inferenceTrainingOptionsCurrent = curOptions;
    setappdata(gui, 'inferenceTrainingOptionsCurrent', experiment.inferenceTrainingOptionsCurrent);
    updateImage();
  end
end

%--------------------------------------------------------------------------
function exportTraces(~, ~)
  [fileName, pathName] = uiputfile({'*.png'; '*.tiff'; '*.pdf'; '*.eps'}, 'Save figure', [experiment.folder 'inferenceTraining']); 
  if(fileName ~= 0)
    export_fig([pathName fileName], '-r300', hs.mainWindowFramesAxes);
  end
end

function exportFigure(~, ~)
  hFig = figure;
  hFig.Position = setFigurePosition(gui, 'width', 800, 'height', 500);
  axx = axes;
  updateImage(axx);
  ui = uimenu(hFig, 'Label', 'Export');
  uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf'; '*.png'; '*.tiff'; '*.eps'}, [experiment.folder 'inferenceTrainingTrace']});
end

%--------------------------------------------------------------------------
function exportData(hObject, hEvent)
  selectedROI = find(ROIid == experiment.peelingOptionsCurrent.trainingROI);
  currentTrace = traces(:, selectedROI);
  inferenceTrainingData = experiment.inferenceTrainingData;
  exportData = [t(:), currentTrace(:), inferenceTrainingData.model(:)];
  exportDataSpikes = [t(1)+inferenceTrainingData.spikes(:)];
   
  fullFile = exportDataCallback(hObject, hEvent, {'*.csv'}, ...
                               [experiment.folder 'peelingTrainingData'], ...
                               exportData, ...
                               {'time', 'trace', 'infered trace'}, ...
                               'trace');
        
  exportDataCallback(hObject, hEvent, {'*.csv'}, ...
                    [experiment.folder 'peelingTrainingData'], ...
                    exportDataSpikes, ...
                    {'spike times'}, ...
                    'spikes', [], fullFile);
        
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
function inferenceTraining(hObject, eventData, mode, changeROI)
  % First pass for preexisting options
  if(~isempty(changeROI))
    switch changeROI
      case 'previousROI'
        mode = experiment.inferenceTrainingData.mode;
      case 'nextROI'
        mode = experiment.inferenceTrainingData.mode;
      case 'randomROI'
        mode = experiment.inferenceTrainingData.mode;
    end
  end
  switch mode
    case 'peeling'
      optionsClass = peelingOptions;
      inferenceHandle = 'spikeInferencePeeling';
      trainingMode = 'peeling';
    case 'foopsi'
      optionsClass = foopsiOptions;
      inferenceHandle = 'spikeInferenceFoopsi';
      trainingMode = 'foopsi';
    case 'schmitt'
      optionsClass = schmittOptions;
      inferenceHandle = 'spikeInferenceSchmitt';
      trainingMode = 'schmitt';
    case 'oasis'
      optionsClass = oasisOptions;
      inferenceHandle = 'spikeInferenceOasis';
      trainingMode = 'oasis';
    case 'MLspike'
      optionsClass = MLspikeOptions;
      inferenceHandle = 'spikeInferenceMLspike';
      trainingMode = 'MLspike';
  end
  if(~isempty(changeROI))
    [success, optionsClassCurrent] = preloadOptions(experiment, optionsClass, gcbf, false, true);
  else
    [success, optionsClassCurrent] = preloadOptions(experiment, optionsClass, gcbf, true, false);
  end
  if(~success)
    return;
  end
  if(~isempty(optionsClassCurrent.trainingROI))
    selectedROI = find(ROIid == optionsClassCurrent.trainingROI);
    % Check that the selectedROI belongs to the selected group
    members = getExperimentGroupMembers(experiment, optionsClassCurrent.group);
    if(~any(members == selectedROI))
      logMsg('Selected ROI does not belong to the target group. Running anyway', 'w');
    end
    % Now we try to change the ROI
    if(~isempty(changeROI))
      members = getExperimentGroupMembers(experiment, optionsClassCurrent.group);
      switch changeROI
        case 'previousROI'
          curROIpos = find(members == selectedROI);
          curROIpos = curROIpos - 1;
          if(curROIpos < 1)
            curROIpos = 1;
          end
          selectedROI = members(curROIpos);
        case 'nextROI'
          curROIpos = find(members == selectedROI);
          curROIpos = curROIpos + 1;
          if(curROIpos > length(members))
            curROIpos = length(members);
          end
          selectedROI = members(curROIpos);
        case 'randomROI'
          selectedROI = members(randperm(length(members), 1));
      end
      optionsClassCurrent.trainingROI = experiment.ROI{selectedROI}.ID;
    end
  else
    members = getExperimentGroupMembers(experiment, optionsClassCurrent.group);
    selectedROI = members(randperm(length(members), 1));
    optionsClassCurrent.trainingROI = experiment.ROI{selectedROI}.ID;
  end
  
  [experiment, inferenceTrainingData] = feval(inferenceHandle, experiment, optionsClassCurrent, 'subset', selectedROI, 'training', true);
  logMsg(sprintf('Successfully ran %s on ROI: %d. Found %d spikes', mode, experiment.ROI{selectedROI}.ID, length(inferenceTrainingData.spikes)));
  inferenceTrainingData.mode = mode;
  experiment.inferenceTrainingData = inferenceTrainingData;

  experiment.([class(optionsClass) 'Current']) = optionsClassCurrent;
  try
    setappdata(gui, [class(optionsClass) 'Current'], optionsClassCurrent);
  catch
  end
  updateImage();
end



%% Utility functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------------------------------------------------------------
function updateMenus()
    
end

%--------------------------------------------------------------------------
function updateImage(varargin)
  if(nargin < 1)
    axx = hs.mainWindowFramesAxes;
  else
    axx = varargin{1};
  end
  axes(axx);
  cla(axx);  
  axis tight;
  switch trainingMode
    case 'peeling'
      inferenceTrainingData = experiment.inferenceTrainingData;
      if(~isempty(inferenceTrainingData) && isfield(experiment, 'peelingOptionsCurrent'))
        selectedROI = find(ROIid == experiment.peelingOptionsCurrent.trainingROI);
        currentTrace = traces(:, selectedROI);

        plot(t, currentTrace);
        hold on;
        if(experiment.inferenceTrainingOptionsCurrent.showModelTrace)
          plot(t, inferenceTrainingData.model)  
        end
        yl = ylim;
        plot(t(1)+inferenceTrainingData.spikes, ones(size(inferenceTrainingData.spikes))*yl(2)*1.1, experiment.inferenceTrainingOptionsCurrent.symbol);
        Nspikes = length(inferenceTrainingData.spikes);
        peelingCorrelation = corr(inferenceTrainingData.model', traces(:, selectedROI));
        title(sprintf('ROI: %d - Peeling correlation: %.3f - # spikes: %d', experiment.ROI{selectedROI}.ID, peelingCorrelation, Nspikes));

        ylim([yl(1) yl(2)*1.2]);
      else
        currentTrace = traces(:, selectedROI);
        plot(t, currentTrace);
        title(['Spike inference training on ROI: ' num2str(experiment.ROI{selectedROI}.ID)]);
      end
    case 'foopsi'
      inferenceTrainingData = experiment.inferenceTrainingData;
      %if(~isempty(inferenceTrainingData) && isfield(experiment, 'peelingOptionsCurrent'))
      if(~isempty(inferenceTrainingData))
        if(~isempty(experiment.foopsiOptionsCurrent.trainingROI))
          selectedROI = find(ROIid == experiment.foopsiOptionsCurrent.trainingROI);
        end
        switch experiment.foopsiOptionsCurrent.tracesType
            case 'raw'
                currentTrace = experiment.rawTraces(:, selectedROI);
                plot(t, currentTrace);
                hold on;
                if(experiment.inferenceTrainingOptionsCurrent.showModelTrace)
                  plot(t, inferenceTrainingData.model+min(currentTrace))
                end
                plot(t(inferenceTrainingData.spikes), ones(size(inferenceTrainingData.spikes))*max(currentTrace)*1.001, experiment.inferenceTrainingOptionsCurrent.symbol);
            otherwise
                currentTrace = experiment.traces(:, selectedROI);
                plot(t, currentTrace);
                hold on;
                if(experiment.inferenceTrainingOptionsCurrent.showModelTrace)
                  plot(t, inferenceTrainingData.model)
                end
                plot(t(inferenceTrainingData.spikes), ones(size(inferenceTrainingData.spikes))*max(currentTrace)*1.1, experiment.inferenceTrainingOptionsCurrent.symbol);
        end
        
        %plot(t(1)+data2.spikes, ones(length(data2.spikes))*ca_p2.amp1,'o');
        yl = ylim;
        %plot(t(1)+inferenceTrainingData.spikes, ones(size(inferenceTrainingData.spikes))*yl(2)*1.1, experiment.inferenceTrainingOptionsCurrent.symbol);
        

        Nspikes = length(inferenceTrainingData.spikes);
         switch experiment.foopsiOptionsCurrent.tracesType
            case 'raw'
                foopsiCorrelation = corr(inferenceTrainingData.model', experiment.rawTraces(:, selectedROI));
                ylim([min(currentTrace), max(currentTrace)*1.1]);
            otherwise
                foopsiCorrelation = corr(inferenceTrainingData.model', experiment.traces(:, selectedROI));
                ylim([yl(1) yl(2)*1.2]);
        end
        
        title(sprintf('ROI: %d - Foopsi correlation: %.3f - # spikes: %d', experiment.ROI{selectedROI}.ID, foopsiCorrelation, Nspikes));

        
      else
        currentTrace = traces(:, selectedROI);
        plot(t, currentTrace);
        title(['Spike inference training on ROI: ' num2str(experiment.ROI{selectedROI}.ID)]);
      end
    case 'oasis'
      inferenceTrainingData = experiment.inferenceTrainingData;
      
      if(~isempty(inferenceTrainingData))
        if(~isempty(experiment.oasisOptionsCurrent.trainingROI))
          selectedROI = find(ROIid == experiment.oasisOptionsCurrent.trainingROI);
        end
          switch experiment.oasisOptionsCurrent.tracesType
            case 'raw'
                currentTrace = experiment.rawTraces(:, selectedROI);
                plot(t, currentTrace);
                hold on;
                if(experiment.inferenceTrainingOptionsCurrent.showModelTrace)
                  plot(t, inferenceTrainingData.model+min(currentTrace))
                end
                plot(t(inferenceTrainingData.spikes), ones(size(inferenceTrainingData.spikes))*max(currentTrace)*1.001, experiment.inferenceTrainingOptionsCurrent.symbol);
            otherwise
                currentTrace = experiment.traces(:, selectedROI);
                plot(t, currentTrace);
                hold on;
                if(experiment.inferenceTrainingOptionsCurrent.showModelTrace)
                  plot(t, inferenceTrainingData.model)
                end
                plot(t(inferenceTrainingData.spikes), ones(size(inferenceTrainingData.spikes))*max(currentTrace)*1.1, experiment.inferenceTrainingOptionsCurrent.symbol);
          end

        yl = ylim;
        Nspikes = length(inferenceTrainingData.spikes);
        oasisCorrelation = corr(inferenceTrainingData.model, traces(:, selectedROI));
        title(sprintf('ROI: %d - Oasis correlation: %.3f - # spikes: %d', experiment.ROI{selectedROI}.ID, oasisCorrelation, Nspikes));

        ylim([yl(1) yl(2)*1.2]);
      else
        currentTrace = traces(:, selectedROI);
        plot(t, currentTrace);
        title(['Spike inference training on ROI: ' num2str(experiment.ROI{selectedROI}.ID)]);
      end
    case 'MLspike'
      inferenceTrainingData = experiment.inferenceTrainingData;
      
      if(~isempty(inferenceTrainingData))
        if(~isempty(experiment.MLspikeOptionsCurrent.trainingROI))
          selectedROI = find(ROIid == experiment.MLspikeOptionsCurrent.trainingROI);
        end
          switch experiment.MLspikeOptionsCurrent.tracesType
            case 'raw'
                currentTrace = experiment.rawTraces(:, selectedROI);
                plot(t, currentTrace);
                hold on;
                if(experiment.inferenceTrainingOptionsCurrent.showModelTrace)
                  plot(t, inferenceTrainingData.model)
                end
                plot(t(inferenceTrainingData.spikes), ones(size(inferenceTrainingData.spikes))*max(currentTrace)+(max(currentTrace)-min(currentTrace))*0.05, experiment.inferenceTrainingOptionsCurrent.symbol, 'MarkerSize', 8, 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'k');
            otherwise
                currentTrace = experiment.traces(:, selectedROI);
                plot(t, currentTrace);
                hold on;
                if(experiment.inferenceTrainingOptionsCurrent.showModelTrace)
                  plot(t, inferenceTrainingData.model)
                end
                plot(t(inferenceTrainingData.spikes), ones(size(inferenceTrainingData.spikes))*max(currentTrace)*1.1, experiment.inferenceTrainingOptionsCurrent.symbol);
          end

        yl = ylim;
        Nspikes = length(inferenceTrainingData.spikes);
        MLspikeCorrelation = corr(inferenceTrainingData.model, traces(:, selectedROI));
        title(sprintf('ROI: %d - MLspike correlation: %.3f - # spikes: %d', experiment.ROI{selectedROI}.ID, MLspikeCorrelation, Nspikes));

        ylim([yl(1) yl(2)*1.2]);
      else
        currentTrace = traces(:, selectedROI);
        plot(t, currentTrace);
        title(['Spike inference training on ROI: ' num2str(experiment.ROI{selectedROI}.ID)]);
      end
    case 'schmitt'
      if(isfield(experiment, 'schmittOptionsCurrent'))
        if(~isempty(experiment.schmittOptionsCurrent.trainingROI))
          selectedROI = find(ROIid == experiment.schmittOptionsCurrent.trainingROI);
        end
        currentTrace = traces(:, selectedROI);

        plot(t, currentTrace);
        hold on;
        yl = ylim;
        plot(t(1)+experiment.inferenceTrainingData.spikes, ones(size(experiment.inferenceTrainingData.spikes))*yl(2)*1.1, experiment.inferenceTrainingOptionsCurrent.symbol);
        xl = xlim;
        switch experiment.schmittOptionsCurrent.thresholdType
          case 'relative'
            plot(xl, mean(currentTrace)+std(currentTrace)*[1,1]*experiment.schmittOptionsCurrent.lowerThreshold, '--');
            plot(xl, mean(currentTrace)+std(currentTrace)*[1,1]*experiment.schmittOptionsCurrent.upperThreshold, '--');
          case 'absolute'
            plot(xl, [1,1]*experiment.schmittOptionsCurrent.lowerThreshold, '--');
            plot(xl, [1,1]*experiment.schmittOptionsCurrent.upperThreshold, '--');
        end
        for it = 1:length(experiment.inferenceTrainingData.frames)
          plot(t(experiment.inferenceTrainingData.frames{it}), currentTrace(experiment.inferenceTrainingData.frames{it}));
        end
        Nspikes = length(experiment.inferenceTrainingData.spikes);
        title(sprintf('ROI: %d - # spikes: %d', experiment.ROI{selectedROI}.ID, Nspikes));

        ylim([yl(1) yl(2)*1.2]);
      else
        currentTrace = traces(:, selectedROI);
        plot(t, currentTrace);
        title(['Spike inference training on ROI: ' num2str(experiment.ROI{selectedROI}.ID)]);
      end
  end
  xlim(round([t(1) t(end)]));

  xlabel('time (s)');
  ylabel('Fluoresence (a.u.)');
  box on;
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
