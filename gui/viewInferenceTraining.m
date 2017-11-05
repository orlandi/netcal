function [hFigW, experiment] = viewInferenceTraining(experiment)
% VIEWINFERENCETRAINING screen to check performance of spike inference algorithms on single traces (for now only peeling)
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
% Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
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
if(~isfield(experiment, 'inferenceTrainingData'))
  experiment.inferenceTrainingData = [];
end
ROIid = getROIid(experiment.ROI);
experiment = loadTraces(experiment, 'all');
originalExperiment = experiment;
experiment = checkGroups(experiment);
[~, curOptions] = preloadOptions(experiment, inferenceTrainingOptions, gui, false, false);
experiment.inferenceTrainingOptionsCurrent = curOptions;

setappdata(gui, 'inferenceTrainingOptionsCurrent', experiment.inferenceTrainingOptionsCurrent);

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

%% COLUMN START
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
uix.Empty('Parent', hs.mainWindowGrid);

% Plot --------------------------------------------------------------------
hs.mainWindowFramesPanel = uix.Panel('Parent', hs.mainWindowGrid, 'Padding', 5, 'BorderType', 'none');
hs.mainWindowFramesAxes = axes('Parent', uicontainer('Parent', hs.mainWindowFramesPanel));
set(hs.mainWindowFramesAxes, 'ButtonDownFcn', @rightClick);


% Pages buttons -----------------------------------------------------------
% Below image panel
%uix.Empty('Parent', hs.mainWindowGrid);
hs.mainWindowBottomButtons = uix.HButtonBox( 'Parent', hs.mainWindowGrid);
%uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'Burst detection (threshold)', 'FontSize', textFontSize, 'callback', @burstDetectionThreshold);
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'Peeling', 'FontSize', textFontSize, 'callback', {@inferenceTraining, 'peeling'});
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'Foopsi', 'FontSize', textFontSize, 'callback', {@inferenceTraining, 'foopsi'});
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'Schmitt', 'FontSize', textFontSize, 'callback', {@inferenceTraining, 'schmitt'});
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'oasis', 'FontSize', textFontSize, 'callback', {@inferenceTraining, 'oasis'});
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'MLspike', 'FontSize', textFontSize, 'callback', {@inferenceTraining, 'MLspike'});
%uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'Options', 'FontSize', textFontSize, 'callback', @inferenceOptions);
set(hs.mainWindowBottomButtons, 'ButtonSize', [125 15], 'Padding', 0, 'Spacing', 15);

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

%% Final init
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
set(hs.mainWindowGrid, 'Widths', [minGridBorder -1 minGridBorder], ...
  'Heights', [minGridBorder -1 125 100 minGridBorder]);
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
  selectedROI = ROIid == experiment.peelingOptionsCurrent.trainingROI;
  selectedTrace = find(selectedROI);
  currentTrace = experiment.traces(:, selectedTrace);
  inferenceTrainingData = experiment.inferenceTrainingData;
  exportData = [experiment.t(:), currentTrace(:), inferenceTrainingData.model(:)];
  exportDataSpikes = [experiment.t(1)+inferenceTrainingData.spikes(:)];
   
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
function inferenceTraining(hObject, eventData, mode)
  switch mode
    case 'peeling'
      [success, peelingOptionsCurrent] = preloadOptions(experiment, peelingOptions, gcbf, true, false);
      if(~success)
        return;
      end
      selectedTrace = find(ROIid == peelingOptionsCurrent.trainingROI);
      [experiment, inferenceTrainingData] = spikeInferencePeeling(experiment, peelingOptionsCurrent, 'subset', selectedTrace, 'training', true);
      experiment.inferenceTrainingData = inferenceTrainingData;

      experiment.peelingOptionsCurrent = peelingOptionsCurrent;
      setappdata(gui, 'peelingOptionsCurrent', peelingOptionsCurrent);
      trainingMode = 'peeling';
    case 'foopsi'
      [success, foopsiOptionsCurrent] = preloadOptions(experiment, foopsiOptions, gcbf, true, false);
      if(~success)
        return;
      end
      selectedTrace = find(ROIid == foopsiOptionsCurrent.trainingROI);
      [experiment, inferenceTrainingData] = spikeInferenceFoopsi(experiment, foopsiOptionsCurrent, 'subset', selectedTrace, 'training', true);
      experiment.inferenceTrainingData = inferenceTrainingData;
      
      experiment.foopsiOptionsCurrent = foopsiOptionsCurrent;
      setappdata(gui, 'foopsiOptionsCurrent', foopsiOptionsCurrent);
      trainingMode = 'foopsi';
    case 'schmitt'
      trainingMode = 'schmitt';
      [success, schmittOptionsCurrent] = preloadOptions(experiment, schmittOptions, gcbf, true, false);
      if(~success)
        return;
      end
      selectedTrace = find(ROIid == schmittOptionsCurrent.trainingROI);
      experiment = spikeInferenceSchmitt(experiment, schmittOptionsCurrent, 'subset', selectedTrace, 'training', true);

      experiment.schmittOptionsCurrent = schmittOptionsCurrent;
      setappdata(gui, 'schmittOptionsCurrent', schmittOptionsCurrent);
      trainingMode = 'schmitt';
    case 'oasis'
      [success, oasisOptionsCurrent] = preloadOptions(experiment, oasisOptions, gcbf, true, false);
      if(~success)
        return;
      end
      selectedTrace = find(ROIid == oasisOptionsCurrent.trainingROI);
      [experiment, inferenceTrainingData] = spikeInferenceOasis(experiment, oasisOptionsCurrent, 'subset', selectedTrace, 'training', true);
      experiment.inferenceTrainingData = inferenceTrainingData;
      
      experiment.oasisOptionsCurrent = oasisOptionsCurrent;
      setappdata(gui, 'oasisOptionsCurrent', oasisOptionsCurrent);
      trainingMode = 'oasis';
    case 'MLspike'
      [success, MLspikeOptionsCurrent] = preloadOptions(experiment, MLspikeOptions, gcbf, true, false);
      if(~success)
        return;
      end
      selectedTrace = find(ROIid == MLspikeOptionsCurrent.trainingROI);
      [experiment, inferenceTrainingData] = spikeInferenceMLspike(experiment, MLspikeOptionsCurrent, 'subset', selectedTrace, 'training', true);
      experiment.inferenceTrainingData = inferenceTrainingData;
      
      experiment.MLspikeOptionsCurrent = MLspikeOptionsCurrent;
      setappdata(gui, 'MLspikeOptionsCurrent', MLspikeOptionsCurrent);
      trainingMode = 'MLspike';
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
        selectedROI = ROIid == experiment.peelingOptionsCurrent.trainingROI;
        selectedTrace = find(selectedROI);
        currentTrace = experiment.traces(:, selectedTrace);

        plot(experiment.t, currentTrace);
        hold on;
        if(experiment.inferenceTrainingOptionsCurrent.showModelTrace)
          plot(experiment.t, inferenceTrainingData.model)  
        end
        yl = ylim;
        plot(experiment.t(1)+inferenceTrainingData.spikes, ones(size(inferenceTrainingData.spikes))*yl(2)*1.1, experiment.inferenceTrainingOptionsCurrent.symbol);
        Nspikes = length(inferenceTrainingData.spikes);
        peelingCorrelation = corr(inferenceTrainingData.model', experiment.traces(:, selectedTrace));
        title(sprintf('ROI: %d - Peeling correlation: %.3f - # spikes: %d', experiment.ROI{selectedROI}.ID, peelingCorrelation, Nspikes));

        ylim([yl(1) yl(2)*1.2]);
      else
        currentTrace = experiment.traces(:, selectedROI);
        plot(experiment.t, currentTrace);
        title(['Spike inference training on ROI: ' num2str(experiment.ROI{selectedROI}.ID)]);
      end
    case 'foopsi'
      inferenceTrainingData = experiment.inferenceTrainingData;
      %if(~isempty(inferenceTrainingData) && isfield(experiment, 'peelingOptionsCurrent'))
      if(~isempty(inferenceTrainingData))
        selectedROI = ROIid == experiment.foopsiOptionsCurrent.trainingROI;
        selectedTrace = find(selectedROI);
        switch experiment.foopsiOptionsCurrent.tracesType
            case 'raw'
                currentTrace = experiment.rawTraces(:, selectedTrace);
                plot(experiment.t, currentTrace);
                hold on;
                if(experiment.inferenceTrainingOptionsCurrent.showModelTrace)
                  plot(experiment.t, inferenceTrainingData.model+min(currentTrace))
                end
                plot(experiment.t(inferenceTrainingData.spikes), ones(size(inferenceTrainingData.spikes))*max(currentTrace)*1.001, experiment.inferenceTrainingOptionsCurrent.symbol);
            otherwise
                currentTrace = experiment.traces(:, selectedTrace);
                plot(experiment.t, currentTrace);
                hold on;
                if(experiment.inferenceTrainingOptionsCurrent.showModelTrace)
                  plot(experiment.t, inferenceTrainingData.model)
                end
                plot(experiment.t(inferenceTrainingData.spikes), ones(size(inferenceTrainingData.spikes))*max(currentTrace)*1.1, experiment.inferenceTrainingOptionsCurrent.symbol);
        end
        
        %plot(t(1)+data2.spikes, ones(length(data2.spikes))*ca_p2.amp1,'o');
        yl = ylim;
        %plot(experiment.t(1)+inferenceTrainingData.spikes, ones(size(inferenceTrainingData.spikes))*yl(2)*1.1, experiment.inferenceTrainingOptionsCurrent.symbol);
        

        Nspikes = length(inferenceTrainingData.spikes);
         switch experiment.foopsiOptionsCurrent.tracesType
            case 'raw'
                foopsiCorrelation = corr(inferenceTrainingData.model', experiment.rawTraces(:, selectedTrace));
                ylim([min(currentTrace), max(currentTrace)*1.1]);
            otherwise
                foopsiCorrelation = corr(inferenceTrainingData.model', experiment.traces(:, selectedTrace));
                ylim([yl(1) yl(2)*1.2]);
        end
        
        title(sprintf('ROI: %d - Foopsi correlation: %.3f - # spikes: %d', experiment.ROI{selectedROI}.ID, foopsiCorrelation, Nspikes));

        
      else
        currentTrace = experiment.traces(:, selectedROI);
        plot(experiment.t, currentTrace);
        title(['Spike inference training on ROI: ' num2str(experiment.ROI{selectedROI}.ID)]);
      end
    case 'oasis'
      inferenceTrainingData = experiment.inferenceTrainingData;
      
      if(~isempty(inferenceTrainingData))
        selectedROI = ROIid == experiment.oasisOptionsCurrent.trainingROI;
        selectedTrace = find(selectedROI);
          switch experiment.oasisOptionsCurrent.tracesType
            case 'raw'
                currentTrace = experiment.rawTraces(:, selectedTrace);
                plot(experiment.t, currentTrace);
                hold on;
                if(experiment.inferenceTrainingOptionsCurrent.showModelTrace)
                  plot(experiment.t, inferenceTrainingData.model+min(currentTrace))
                end
                plot(experiment.t(inferenceTrainingData.spikes), ones(size(inferenceTrainingData.spikes))*max(currentTrace)*1.001, experiment.inferenceTrainingOptionsCurrent.symbol);
            otherwise
                currentTrace = experiment.traces(:, selectedTrace);
                plot(experiment.t, currentTrace);
                hold on;
                if(experiment.inferenceTrainingOptionsCurrent.showModelTrace)
                  plot(experiment.t, inferenceTrainingData.model)
                end
                plot(experiment.t(inferenceTrainingData.spikes), ones(size(inferenceTrainingData.spikes))*max(currentTrace)*1.1, experiment.inferenceTrainingOptionsCurrent.symbol);
          end

        yl = ylim;
        Nspikes = length(inferenceTrainingData.spikes);
        oasisCorrelation = corr(inferenceTrainingData.model, experiment.traces(:, selectedTrace));
        title(sprintf('ROI: %d - Oasis correlation: %.3f - # spikes: %d', experiment.ROI{selectedROI}.ID, oasisCorrelation, Nspikes));

        ylim([yl(1) yl(2)*1.2]);
      else
        currentTrace = experiment.traces(:, selectedROI);
        plot(experiment.t, currentTrace);
        title(['Spike inference training on ROI: ' num2str(experiment.ROI{selectedROI}.ID)]);
      end
    case 'MLspike'
      inferenceTrainingData = experiment.inferenceTrainingData;
      
      if(~isempty(inferenceTrainingData))
        selectedROI = ROIid == experiment.MLspikeOptionsCurrent.trainingROI;
        selectedTrace = find(selectedROI);
          switch experiment.MLspikeOptionsCurrent.tracesType
            case 'raw'
                currentTrace = experiment.rawTraces(:, selectedTrace);
                plot(experiment.t, currentTrace);
                hold on;
                if(experiment.inferenceTrainingOptionsCurrent.showModelTrace)
                  plot(experiment.t, inferenceTrainingData.model)
                end
                plot(experiment.t(inferenceTrainingData.spikes), ones(size(inferenceTrainingData.spikes))*max(currentTrace)*1.001, experiment.inferenceTrainingOptionsCurrent.symbol);
            otherwise
                currentTrace = experiment.traces(:, selectedTrace);
                plot(experiment.t, currentTrace);
                hold on;
                if(experiment.inferenceTrainingOptionsCurrent.showModelTrace)
                  plot(experiment.t, inferenceTrainingData.model)
                end
                plot(experiment.t(inferenceTrainingData.spikes), ones(size(inferenceTrainingData.spikes))*max(currentTrace)*1.1, experiment.inferenceTrainingOptionsCurrent.symbol);
          end

        yl = ylim;
        Nspikes = length(inferenceTrainingData.spikes);
        MLspikeCorrelation = corr(inferenceTrainingData.model, experiment.traces(:, selectedTrace));
        title(sprintf('ROI: %d - MLspike correlation: %.3f - # spikes: %d', experiment.ROI{selectedROI}.ID, MLspikeCorrelation, Nspikes));

        ylim([yl(1) yl(2)*1.2]);
      else
        currentTrace = experiment.traces(:, selectedROI);
        plot(experiment.t, currentTrace);
        title(['Spike inference training on ROI: ' num2str(experiment.ROI{selectedROI}.ID)]);
      end
    case 'schmitt'
      if(isfield(experiment, 'schmittOptionsCurrent'))
        selectedROI = ROIid == experiment.schmittOptionsCurrent.trainingROI;
        selectedTrace = find(selectedROI);
        currentTrace = experiment.traces(:, selectedTrace);

        plot(experiment.t, currentTrace);
        hold on;
        yl = ylim;
        plot(experiment.t(1)+experiment.spikes{selectedTrace}, ones(size(experiment.spikes{selectedTrace}))*yl(2)*1.1, experiment.inferenceTrainingOptionsCurrent.symbol);
        xl = xlim;
        switch experiment.schmittOptionsCurrent.thresholdType
          case 'relative'
            plot(xl, mean(currentTrace)+std(currentTrace)*[1,1]*experiment.schmittOptionsCurrent.lowerThreshold, '--');
            plot(xl, mean(currentTrace)+std(currentTrace)*[1,1]*experiment.schmittOptionsCurrent.upperThreshold, '--');
          case 'absolute'
            plot(xl, [1,1]*experiment.schmittOptionsCurrent.lowerThreshold, '--');
            plot(xl, [1,1]*experiment.schmittOptionsCurrent.upperThreshold, '--');
        end
        Nspikes = length(experiment.spikes{selectedTrace});
        title(sprintf('ROI: %d - # spikes: %d', experiment.ROI{selectedROI}.ID, Nspikes));

        ylim([yl(1) yl(2)*1.2]);
      else
        currentTrace = experiment.traces(:, selectedROI);
        plot(experiment.t, currentTrace);
        title(['Spike inference training on ROI: ' num2str(experiment.ROI{selectedROI}.ID)]);
      end
  end
  xlim(round([experiment.t(1) experiment.t(end)]));

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
