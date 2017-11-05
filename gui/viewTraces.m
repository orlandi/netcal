function [hFigW, experiment] = viewTraces(experiment)
% VIEWTRACES plots the traces from a given experiment
%
% USAGE:
%    viewTraces(gui, experiment)
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
%    hFigW = viewTraces(gui, experiment)
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
hFigW = [];
if(~isempty(gui))
  project = getappdata(gui, 'project');
else
  project = [];
end

textFontSize = 10;
minGridBorder = 1;

originalExperiment = experiment;

[success, curOptions] = preloadOptions(experiment, viewTracesOptions, gui, false, false);
experiment.viewTracesOptionsCurrent = curOptions;

normalization = experiment.viewTracesOptionsCurrent.normalization;
numberTraces = experiment.viewTracesOptionsCurrent.numberTraces;
normalizationMultiplier = experiment.viewTracesOptionsCurrent.normalizationMultiplier;

ROIid = getROIid(experiment.ROI);
firstTrace = 1;
lastTrace = 1;

% if(~success)
%   logMsg('Consistency checks failed', 'e');
%   return;
% else
%   experiment = exp;
% end

cmapName = 'parula';
cmap = parula(numberTraces+1);
cmapFull = parula(256);
cmapStandard = cmapName;
cmapLearning = [];
cmapLearningEvent = [];
cmapLearningManual = [];
cmapPatterns = [];
learningMode = 'none'; % none/trace/event
traceHandles = [];
traceGuideHandles = [];
showSpikes = false;
showPatterns = false;
showBaseLine = false;
additionalExperiments = false;
additionalExperimentsList = {};
additionalExperimentsPanelList = [];
additionalAxesList = [];
additionalValidIdx = {};
additionalValidID = {};
rectangleStart = [];
rectangleEnd = [];
rectangleH = [];
movieLineH = [];
buttonDown = false;

selectedTraces = [];
selectedT = [];
currentOrder = [];
traces = [];
totalPages = 1;

[patterns, basePatternList] = generatePatternList(experiment);

% Some preloading
[success, ~, experiment] = preloadOptions(experiment, learningOptions, gui, false, false);
[success, ~, experiment] = preloadOptions(experiment, learningEventOptions, gui, false, false);
[success, ~, experiment] = preloadOptions(experiment, identifyHCGoptions, gui, false, false);

experiment = checkGroups(experiment);

lastID = 0;

% More handles
hs.wholeScreenSelectionWindow = [];
hs.wholeScreenSelectionWindowData = [];
hs.onScreenSelectionWindow = [];
hs.onScreenSelectionWindowData = [];
hs.onScreenSelectionMovieWindow = [];
hs.onScreenSelectionMovieWindowData = [];

%% Create components
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

hs.mainWindow = figure('Visible','off',...
                       'Resize','on',...
                       'Toolbar', 'figure',...
                       'Tag','viewTraces', ...
                       'DockControls','off',...
                       'NumberTitle', 'off',...
                       'MenuBar', 'none',...
                       'CloseRequestFcn', @closeCallback,...
                       'ResizeFcn', @resizeCallback, ...
                       'WindowButtonUpFcn', @rightClickUp, ...
                       'WindowButtonMotionFcn', @buttonMotion, ...
                       'WindowScrollWheelFcn', @wheelFcn, ...
                       'KeyPressFcn', @KeyPress, ...
                       'Name', ['Trace explorer: ' experiment.name]);
hFigW = hs.mainWindow;
hFigW.Position = setFigurePosition(gui, 'width', 1000, 'height', 650);
setappdata(hFigW, 'experiment', experiment);

resizeHandle = hFigW.ResizeFcn;
setappdata(hFigW, 'ResizeHandle', resizeHandle);
if(~isempty(gui))
  setappdata(hFigW, 'logHandle', getappdata(gui, 'logHandle'));
  setappdata(hFigW, 'gui', gui);
end


% Set the menu
hs.menu.file.root = uimenu(hs.mainWindow, 'Label', 'File');
uimenu(hs.menu.file.root, 'Label', 'Exit and discard changes', 'Callback', {@closeCallback, false});
uimenu(hs.menu.file.root, 'Label', 'Exit and save changes', 'Callback', {@closeCallback, true});
uimenu(hs.menu.file.root, 'Label', 'Exit (default)', 'Callback', @closeCallback);

hs.menu.traces.root = uimenu(hs.mainWindow, 'Label', 'Trace selection');
hs.menu.traces.type = uimenu(hs.menu.traces.root, 'Label', 'Type');
if(isfield(experiment, 'rawTraces'))
  hs.menu.traces.typeRaw = uimenu(hs.menu.traces.type, 'Label', 'Raw', 'Tag', 'traceSelection', 'Callback', {@menuTracesType, 'raw'});
end
if(isfield(experiment, 'rawTracesDenoised'))
  hs.menu.traces.typeRawDenoised = uimenu(hs.menu.traces.type, 'Label', 'Raw denoised', 'Tag', 'traceSelection', 'Callback', {@menuTracesType, 'rawDenoised'});
end
if(isfield(experiment, 'traces'))
  hs.menu.traces.typeSmoothed = uimenu(hs.menu.traces.type, 'Label', 'Smoothed', 'Tag', 'traceSelection', 'Callback', {@menuTracesType, 'smoothed'});
end


% This order due to cross references
hs.menu.sort.root = uimenu(hs.mainWindow, 'Label', 'Sort by', 'Tag', 'sort');
hs.menu.sort.ROI = uimenu(hs.menu.sort.root, 'Label', 'ROI',  'Checked', 'on');
if(isfield(experiment, 'similarityOrder'))
  hs.menu.sort.similarity = uimenu(hs.menu.sort.root, 'Label', 'similarity');
end
if(isfield(experiment, 'FCA'))
  hs.menu.sort.FCA = uimenu(hs.menu.sort.root, 'Label', 'FCA');
end
if(isfield(experiment, 'qCEC'))
  hs.menu.sort.entropy = uimenu(hs.menu.sort.root, 'Label', 'entropy');
  hs.menu.sort.complexity = uimenu(hs.menu.sort.root, 'Label', 'complexity');
  hs.menu.sort.qCEC = uimenu(hs.menu.sort.root, 'Label', 'qCEC');
end

% Finish the selection menus
hs.menu.traces.selection = generateSelectionMenu(experiment, hs.menu.traces.root);

% Assigning the callbacks
hs.menu.sort.ROI.Callback = {@updateSortingMethod, 'ROI', hFigW};
if(isfield(experiment, 'similarityOrder'))
  hs.menu.sort.similarity.Callback = {@updateSortingMethod, 'similarity', hFigW};
end
if(isfield(experiment, 'qCEC'))
  hs.menu.sort.entropy.Callback = {@updateSortingMethod, 'entropy', hFigW};
  hs.menu.sort.complexity.Callback = {@updateSortingMethod, 'complexity', hFigW};
  hs.menu.sort.qCEC.Callback = {@updateSortingMethod, 'qCEC', hFigW};
end


%hs.menuPreferences = uimenu(hs.mainWindow, 'Label', 'Preferences', 'Callback', @menuPreferences);
hs.menuPreferences = uimenu(hs.mainWindow, 'Label', 'Preferences');
hs.menuPreferencesColormap = uimenu(hs.menuPreferences, 'Label', 'Colormap');
%colormapList = {'parula', 'jet', 'hsv', 'hot', 'cool', 'gray', 'ametrine', 'morgenstemning', 'isolum', 'bone', 'colorcube'};

colormapList = getHtmlColormapNames({'parula', 'morgenstemning', 'jet', 'isolum'}, 150, 15);

hs.cmaps = [];
for i = 1:length(colormapList)
    hs.cmaps = [hs.cmaps; uimenu(hs.menuPreferencesColormap, 'Label', colormapList{i}, 'Callback', @changeColormap, 'Checked', 'off')];
end
hs.cmaps(1).Checked = 'on';

hs.menuPreferencesBackgroundColor = uimenu(hs.menuPreferences, 'Label', 'Background color');
hs.bgColor = [];
hs.bgColor = [hs.bgColor; uimenu(hs.menuPreferencesBackgroundColor, 'Label', 'white', 'Callback', @changeBackgroundColor, 'Checked', 'on')];
hs.bgColor = [hs.bgColor; uimenu(hs.menuPreferencesBackgroundColor, 'Label', 'black', 'Callback', @changeBackgroundColor)];
hs.bgColor = [hs.bgColor; uimenu(hs.menuPreferencesBackgroundColor, 'Label', 'grey', 'Callback', @changeBackgroundColor)];
hs.menuPreferencesDisplay = uimenu(hs.menuPreferences, 'Label', 'Display', 'Callback', @changeDisplay);
if(isfield(experiment, 'spikes'))
  hs.menuPreferencesShowSpikes = uimenu(hs.menuPreferences, 'Label', 'Show spikes', 'Callback', @menuPreferencesShowSpikes);
end
hs.menuPreferencesShowPatterns = uimenu(hs.menuPreferences, 'Label', 'Show patterns', 'Callback', @menuPreferencesShowPatterns);
if(isfield(experiment, 'validPatterns'))
  hs.menuPreferencesShowPatterns.Visible = 'on';
else
  hs.menuPreferencesShowPatterns.Visible = 'off';
end
if(isfield(experiment, 'baseLine'))
  hs.menuPreferencesShowBaseLine = uimenu(hs.menuPreferences, 'Label', 'Show baseline', 'Callback', @menuPreferencesShowBaseLine);
end

hs.menuView = uimenu(hs.mainWindow, 'Label', 'View');
hs.menuViewRaster = uimenu(hs.menuView, 'Label', 'Fluorescence raster', 'Callback', @menuViewRaster);
hs.menuViewRaster = uimenu(hs.menuView, 'Label', 'Fluorescence raster non-normalized', 'Callback', @menuViewRasterNonNormalized);
hs.menuViewAverageTrace = uimenu(hs.menuView, 'Label', 'Average trace');
hs.menuViewAverageTraceGlobal = uimenu(hs.menuViewAverageTrace, 'Label', 'Current selection', 'Callback', @menuViewAverageTraceGlobal);
hs.menuViewAverageTraceSubpopulations = uimenu(hs.menuViewAverageTrace, 'Label', 'Subpopulations', 'Callback', @menuViewAverageTraceSubpopulations);
hs.menuViewSpectrogram = uimenu(hs.menuView, 'Label', 'Spectrogram');
hs.menuViewSpectrogramGlobal = uimenu(hs.menuViewSpectrogram, 'Label', 'Current selection', 'Callback', {@menuViewSpectrogram, 'current'});
hs.menuViewSpectrogramSubpopulations = uimenu(hs.menuViewSpectrogram, 'Label', 'Subpopulations', 'Callback', {@menuViewSpectrogram, 'subpopulations'});
hs.menuViewSubpopulationStatistics = uimenu(hs.menuView, 'Label', 'Subpopulation statistics', 'Callback', @menuViewSubpopulationStatistics);
hs.menuViewPositions = uimenu(hs.menuView, 'Label', 'Positions');
hs.menuViewPositionsWholeSelection = uimenu(hs.menuViewPositions, 'Label', 'Full population', 'Callback', @viewPositionsWholeSelection);
hs.menuViewPositionsOnScreen = uimenu(hs.menuViewPositions, 'Label', 'Current traces', 'Callback', @viewPositionsOnScreen);
hs.menuViewPositionsOnScreenMovie = uimenu(hs.menuViewPositions, 'Label', 'Current traces (movie)', 'Callback', @viewPositionsOnScreenMovie);


hs.menuClassification = uimenu(hs.mainWindow, 'Label', 'Classification');
hs.menuClassificationFeatureSelection = uimenu(hs.menuClassification, 'Label', 'Feature Selection', 'Enable', 'on', 'Callback', @menuFeatureSelection);

hs.menuClassificationTrace = uimenu(hs.menuClassification, 'Label', 'By traces');
hs.menuClassificationLearning = uimenu(hs.menuClassificationTrace, 'Label', 'Learning');
hs.menuClassificationLearningStart = uimenu(hs.menuClassificationLearning, 'Label', 'Start', 'Callback', @learningStart);
hs.menuClassificationLearningReset = uimenu(hs.menuClassificationLearning, 'Label', 'Reset', 'Callback', {@learningReset, 'classifier'});
hs.menuClassificationLearningFinish = uimenu(hs.menuClassificationLearning, 'Label', 'Finish', 'Callback', @learningFinish);
hs.menuClassificationTrain = uimenu(hs.menuClassificationTrace, 'Label', 'Train & Classify', 'Callback', {@training, 'internal'});
hs.menuClassificationTrainExternal = uimenu(hs.menuClassificationTrace, 'Label', 'Classify with previous trainers', 'Callback', {@training, 'external'});

hs.menuClassificationEvent = uimenu(hs.menuClassification, 'Label', 'By events');
hs.menuClassificationEventPredefined = uimenu(hs.menuClassificationEvent, 'Label', 'Generate predefined patterns', 'Enable', 'on', 'Callback', @generatePredefinedPatternsMenu);
hs.menuClassificationEventLearning = uimenu(hs.menuClassificationEvent, 'Label', 'Generate custom patterns');
hs.menuClassificationEventLearningStart = uimenu(hs.menuClassificationEventLearning, 'Label', 'Start', 'Callback', @learningEventStart);
hs.menuClassificationEventLearningReset = uimenu(hs.menuClassificationEventLearning, 'Label', 'Reset', 'Callback', {@learningReset, 'event'});
hs.menuClassificationEventLearningFinish = uimenu(hs.menuClassificationEventLearning, 'Label', 'Finish', 'Callback', @learningFinish);
hs.menuClassificationEventView = uimenu(hs.menuClassificationEvent, 'Label', 'View Patterns', 'Callback', @menuViewPatterns);
hs.menuClassificationEventSelectionPatterns = uimenu(hs.menuClassificationEvent, 'Label', 'Detect patterns', 'Enable', 'on', 'Callback', {@menuDetectPatterns, false});
hs.menuClassificationEventSelectionPatternsParallel = uimenu(hs.menuClassificationEvent, 'Label', 'Detect patterns (parallel)', 'Enable', 'on', 'Callback', {@menuDetectPatterns, true});
hs.menuClassificationEventCountClassifier = uimenu(hs.menuClassificationEvent, 'Label', 'Pattern Count classifier', 'Callback', {@eventCountClassifier});

hs.menuClassificationManual = uimenu(hs.menuClassification, 'Label', 'Manual');
hs.menuClassificationManualStart = uimenu(hs.menuClassificationManual, 'Label', 'Start', 'Callback', @learningManualStart);
hs.menuClassificationManualReset = uimenu(hs.menuClassificationManual, 'Label', 'Reset', 'Callback', {@learningReset, 'manual'});
hs.menuClassificationManualFinish = uimenu(hs.menuClassificationManual, 'Label', 'Finish', 'Callback', @learningFinish);

hs.menuClassificationHCG = uimenu(hs.menuClassification, 'Label', 'Highly correlated groups', 'Callback', @menuIdentifyHCG);

hs.menuClassificationUnsupervised = uimenu(hs.menuClassification, 'Label', 'Unsupervised fuzzy sets', 'Callback', @fuzzyClassification);

hs.menuClassificationReset = uimenu(hs.menuClassification, 'Label', 'Reset ALL classifications', 'Separator', 'on', 'Callback', {@learningReset, 'all'});

hs.menuCompare = uimenu(hs.mainWindow, 'Label', 'Compare Experiments');
hs.menuCompareAdd = uimenu(hs.menuCompare, 'Label', 'Add Experiment', 'Callback', @menuPreferencesCompareExperiments);
hs.menuCompareTransitions = uimenu(hs.menuCompare, 'Label', 'Show population transitions (circular)', 'Callback', {@menuPreferencesCompareExperimentsTransitions, 'circular'});
hs.menuCompareTransitions = uimenu(hs.menuCompare, 'Label', 'Show population transitions (linear)', 'Callback', {@menuPreferencesCompareExperimentsTransitions, 'linear'});
hs.menuCompareReset = uimenu(hs.menuCompare, 'Label', 'Reset', 'Callback', @menuPreferencesCompareExperimentsReset, 'Separator', 'on');

hs.menu.modules.root = uimenu(hs.mainWindow, 'Label', 'Modules');
hs.menu.modules.KCl.root = uimenu(hs.menu.modules.root, 'Label', 'Acute KCl');
hs.menu.modules.KCl.define = uimenu(hs.menu.modules.KCl.root, 'Label', 'Analysis', 'Callback', @KClAnalysisMenu);
hs.menu.modules.KCl.define = uimenu(hs.menu.modules.KCl.root, 'Label', 'Plot reaction times', 'Callback', {@KClPlot, 'reaction'});
hs.menu.modules.KCl.define = uimenu(hs.menu.modules.KCl.root, 'Label', 'Plot maximum times', 'Callback', {@KClPlot, 'maxTime'});

hs.menuExport = uimenu(hs.mainWindow, 'Label', 'Export');
hs.menuExportFigure = uimenu(hs.menuExport, 'Label', 'Figure', 'Callback', @exportTraces);

hs.menu.groups = uimenu(hs.mainWindow, 'Label', 'Groups');
hs.menu.export = uimenu(hs.menu.groups, 'Label', 'Export', 'Callback', @exportGroups);
hs.menu.import = uimenu(hs.menu.groups, 'Label', 'Import from file', 'Callback', {@importGroups, 'file'});
hs.menu.importProject = uimenu(hs.menu.groups, 'Label', 'Import from another experiment', 'Callback', {@importGroups, 'project'});

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
hs.mainWindowPlotsHBox = uix.HBox('Parent', hs.mainWindowGrid);
hs.mainWindowFramesPanel = uix.Panel('Parent', hs.mainWindowPlotsHBox, 'Padding', 5, 'BorderType', 'none');
%hs.mainWindowFramesAxes = axes('Parent', hs.mainWindowFramesPanel);
hs.mainWindowFramesAxes = axes('Parent', uicontainer('Parent', hs.mainWindowFramesPanel));
set(hs.mainWindowPlotsHBox, 'Widths', -1, 'Padding', 0, 'Spacing', 0);


% Pages buttons -----------------------------------------------------------
hs.mainWindowBottom = uix.VBox( 'Parent', hs.mainWindowGrid);
hs.mainWindowBottomButtons = uix.HBox( 'Parent', hs.mainWindowBottom);
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', '< Previous traces', 'FontSize', textFontSize, 'callback', @previousTracesButton);
uix.Empty('Parent', hs.mainWindowBottomButtons);

hs.mainWindowBottomButtonsCurrentPage = uix.HBox( 'Parent', hs.mainWindowBottomButtons);
uicontrol('Parent', hs.mainWindowBottomButtonsCurrentPage, 'Style', 'text', 'String', 'Current page:', 'FontSize', textFontSize, 'HorizontalAlignment', 'right');

hs.currentPageText = uicontrol('Parent', hs.mainWindowBottomButtonsCurrentPage, 'Style','edit',...
          'String', '1', 'FontSize', textFontSize, 'HorizontalAlignment', 'left', 'Callback', @currentPageChange);
hs.totalPagesText = uicontrol('Parent', hs.mainWindowBottomButtonsCurrentPage, 'Style', 'text', 'String', ['/' num2str(totalPages)], 'FontSize', textFontSize, 'HorizontalAlignment', 'left');
set(hs.mainWindowBottomButtonsCurrentPage, 'Widths', [120 35 100], 'Spacing', 5, 'Padding', 0);


uix.Empty('Parent', hs.mainWindowBottomButtons);
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'Next traces >', 'FontSize', textFontSize, 'callback', @nextTracesButton);
set(hs.mainWindowBottomButtons, 'Widths', [150 -1 250 -1 150], 'Padding', 0, 'Spacing', 15);

% Learning module ---------------------------------------------------------
hs.mainWindowLearningPanel = uix.Panel( 'Parent', hs.mainWindowBottom, 'Title', 'Learning module', 'Padding', 5, 'TitlePosition', 'centertop', 'Visible', 'off');

hs.mainWindowLearningButtons = uix.HBox( 'Parent', hs.mainWindowLearningPanel);
uicontrol('Parent', hs.mainWindowLearningButtons, 'Style', 'text', 'String', 'Current group:', 'FontSize', textFontSize, 'HorizontalAlignment', 'left');
hs.mainWindowLearningGroupSelection = uicontrol('Parent', hs.mainWindowLearningButtons, 'Style', 'popup', 'String', {'Pop 1', 'Pop 2'}, 'Callback', @learningGroupChange);
hs.mainWindowLearningGroupSelectionNtraces = uicontrol('Parent', hs.mainWindowLearningButtons, 'Style', 'text', 'String', 'X traces assigned', 'FontSize', textFontSize, 'HorizontalAlignment', 'left');

uix.Empty('Parent', hs.mainWindowLearningButtons);
hs.eventButtonLengthText = uicontrol('Parent', hs.mainWindowLearningButtons, 'Style', 'text', 'String', 'Event sampling length (s):', 'FontSize', textFontSize, 'HorizontalAlignment', 'left', 'Visible', 'off');
hs.eventButtonLengthEdit = uicontrol('Parent', hs.mainWindowLearningButtons, 'Style', 'edit', 'String', '1', 'Callback', @eventLengthChange, 'Visible', 'off');

hs.eventButtonSizeText = uicontrol('Parent', hs.mainWindowLearningButtons, 'Style', 'text', 'String', 'Minimum event size (s)', 'FontSize', textFontSize, 'HorizontalAlignment', 'left', 'Visible', 'off');
hs.eventButtonSizeEdit = uicontrol('Parent', hs.mainWindowLearningButtons, 'Style', 'edit', 'String', '1', 'Callback', @eventMinSizeChange, 'Visible', 'off');

hs.eventButtonThresholdText = uicontrol('Parent', hs.mainWindowLearningButtons, 'Style', 'text', 'String', 'Event threshold:', 'FontSize', textFontSize, 'HorizontalAlignment', 'left', 'Visible', 'off');
hs.eventButtonThresholdEdit = uicontrol('Parent', hs.mainWindowLearningButtons, 'Style', 'edit', 'String', '1', 'Callback', @eventThresholdChange, 'Visible', 'off');

uix.Empty('Parent', hs.mainWindowLearningButtons);
hs.mainWindowLearningFinish = uicontrol('Parent', hs.mainWindowLearningButtons, 'Style', 'pushbutton', 'String', 'Finish', 'Callback', @learningFinish, 'Visible', 'on');

set(hs.mainWindowLearningButtons, 'Widths', [100 125 125 10 100 50 100 50 100 50 -1 100], 'Padding', 0, 'Spacing', 15);

set(hs.mainWindowBottom, 'Heights', [35 70], 'Padding', 5, 'Spacing', 10);

%set(hs.mainWindowBottomButtons, 'ButtonSize', [150 15], 'Padding', 0, 'Spacing', 15);

% Now the log panel
hs.logPanelParent = uix.Panel('Parent', hs.mainWindowGrid, ...
                               'BorderType', 'none');
hs.logPanel = uicontrol('Parent', hs.logPanelParent, ...
                      'style', 'edit', 'max', 5, 'Background','w', 'Tag', 'logPanel');
                    
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
  'Heights', [minGridBorder -1 135 125 minGridBorder]);
cleanMenu();
updateButtons();
updateMenu();

setappdata(hFigW, 'currentOrder', currentOrder);

if(isfield(experiment, 'traces'))
  menuTracesType([], [], 'smoothed');
  hs.menu.traces.typeSmoothed.Checked = 'on';
else
  menuTracesType([], [], 'raw');
  hs.menu.traces.typeRaw.Checked = 'on';
end


hs.mainWindow.Visible = 'on';
figure(hFigW);

selectGroup([], [], 'everything', 1, [], hFigW);
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

if(~isempty(gui))
  parentHandle = getappdata(hFigW, 'logHandle');
  setappdata(hFigW, 'logHandle', [parentHandle hs.logPanelEditBox]);
else
  setappdata(hs.mainWindow, 'logHandle', hs.logPanelEditBox);
end

%hs.mainWindowFramesAxes.ButtonDownFcn = @rightClick;

updateImage();

resizeHandle = getappdata(hs.mainWindow, 'ResizeHandle');
if(isa(resizeHandle,'function_handle'))
  resizeHandle([], []);
end

consistencyChecks(experiment);

if(isempty(gui))
  waitfor(hFigW);
end

%% Callbacks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------------------------------------------------------------
function previousTracesButton(~, ~, jump)
  if(nargin < 3)
    jump = 1;
  end
  currentPage = str2double(hs.currentPageText.String);
  pageChange(currentPage-jump);
  viewPositionsOnScreenUpdate();
end

%--------------------------------------------------------------------------
function nextTracesButton(~, ~, jump)
  if(nargin < 3)
    jump = 1;
  end
  currentPage = str2double(hs.currentPageText.String);
  pageChange(currentPage+jump);
  viewPositionsOnScreenUpdate();
end

%--------------------------------------------------------------------------
function menuTracesType(hObject, ~, type)
  if(~isempty(hObject))
    menuList = findobj(gcf, '-regexp','Tag', 'traceSelection');
    % Uncheck all
    for i = 1:length(menuList)
      menuList(i).Checked = 'off';
    end
    % Turn current selection on
    hObject.Checked = 'on';
  end
  
  switch type
    case 'raw'
      if(ischar(experiment.rawTraces))
        ncbar.automatic('Loading raw traces');
        [experiment, success] = loadTraces(experiment, 'raw');
        ncbar.close();
      end
      selectedTraces = experiment.rawTraces;
      selectedT = experiment.rawT;
    case 'rawDenoised'
      if(ischar(experiment.rawTracesDenoised))
        ncbar.automatic('Loading rawDenoised traces');
        [experiment, success] = loadTraces(experiment, 'rawTracesDenoised');
        ncbar.close();
      end
      selectedTraces = experiment.rawTracesDenoised;
      selectedT = experiment.rawTDenoised;
    case 'smoothed'
      if(ischar(experiment.traces))
        ncbar.automatic('Loading smoothed traces');
        [experiment, success] = loadTraces(experiment, 'smoothed');
        ncbar.close();
      end
      selectedTraces = experiment.traces;
      selectedT = experiment.t;
  end
  if(isempty(currentOrder) || length(currentOrder) ~= size(selectedTraces, 1))
    currentOrder = 1:size(selectedTraces, 1);
  end
  totalPages = ceil(length(currentOrder)/numberTraces);
  updateImage(true);
end

%--------------------------------------------------------------------------
function currentPageChange(hObject, ~)
  input = round(str2double(get(hObject,'string')));
  if isnan(input)
    errordlg('You must enter a numeric value','Invalid Input','modal')
    uicontrol(hObject)
    return;
  end
  pageChange(input);
  viewPositionsOnScreenUpdate();
end

%--------------------------------------------------------------------------
function closeCallback(~, ~, varargin)
  % Since the bigFields might have been loaded (but shouldn't have changed), let's reassign them
  bigFields = {'rawTraces', 'traces', 'baseLine', 'modelTraces', 'denoisedData', 'rawTracesDenoised', 'validPatterns'};
  for i = 1:length(bigFields)
    if(isfield(experiment, bigFields{i}) && ~ischar(experiment.(bigFields{i})))
      originalExperiment.(bigFields{i}) = experiment.(bigFields{i});
    end
  end
  
  if(isequaln(originalExperiment, experiment))
    experimentChanged = false;
  else
    experimentChanged = true;
  end
  
  guiSave(experiment, experimentChanged, varargin{:});
  
  delete(hFigW);
end

%--------------------------------------------------------------------------
function changeDisplay(~, ~)
  currentOrder = getappdata(hFigW, 'currentOrder');
  [success, viewTracesOptionsCurrent] = preloadOptions(experiment, viewTracesOptions, gui, true, false);
  if(success)
    normalization = viewTracesOptionsCurrent.normalization;
    numberTraces = viewTracesOptionsCurrent.numberTraces;
    normalizationMultiplier = viewTracesOptionsCurrent.normalizationMultiplier;
    cmap = parula(numberTraces+1);
    totalPages = ceil(length(currentOrder)/numberTraces);
    experiment.viewTracesOptionsCurrent = viewTracesOptionsCurrent;
    setappdata(gui, 'viewTracesOptionsCurrent', viewTracesOptionsCurrent);
    updateImage(false);
  end
end

%--------------------------------------------------------------------------
function resizeCallback(~, ~)
  updateImage();
end

%--------------------------------------------------------------------------
function menuPreferencesShowSpikes(~, ~, ~)
  if(strcmp(hs.menuPreferencesShowSpikes.Checked,'on'))
    hs.menuPreferencesShowSpikes.Checked = 'off';
    showSpikes = false;
    updateImage(true);
  else
    hs.menuPreferencesShowSpikes.Checked = 'on';
    if(isfield(experiment,'spikes') && ~isempty(experiment.spikes))
      showSpikes = true;
    end
    updateImage(true);
  end
end

%--------------------------------------------------------------------------
function menuPreferencesShowPatterns(~, ~)
  if(strcmp(hs.menuPreferencesShowPatterns.Checked,'on'))
    hs.menuPreferencesShowPatterns.Checked = 'off';
    showPatterns = false;
    updateImage(true);
  else
    experiment = loadTraces(experiment, 'validPatterns');
    hs.menuPreferencesShowPatterns.Checked = 'on';
    if(isfield(experiment,'validPatterns') && ~isempty(experiment.validPatterns))
    % Generate the appropiate color code
%     for i = 1:size(traces, 2)
%       curNeuron = currentOrder(firstTrace+i-1);
%       patterns = experiment.validPatterns{curNeuron};
%       for j = 1:length(patterns)
%         plot(hs.mainWindowFramesAxes, t(patterns{j}.frames), traces(patterns{j}.frames, i), 'HitTest', 'off');
%       end
      showPatterns = true;
      [patterns, basePatternList] = generatePatternList(experiment);
      % Generate the appropiate color code
      cmapPatterns = lines(length(basePatternList));
    end
    updateImage(true);
  end
end

%--------------------------------------------------------------------------
function exportTraces(~, ~)
  [fileName, pathName] = uiputfile({'*.png'; '*.tiff'; '*.pdf'; '*.eps'}, 'Save figure', [experiment.folder 'traces']); 
  if(fileName ~= 0)
    if(~isempty(additionalAxesList))
      export_fig([pathName fileName], '-r300', gcf);
    else
      export_fig([pathName fileName], '-r300', hs.mainWindowFramesAxes);
    end
  end
end

%--------------------------------------------------------------------------
function menuPreferencesShowBaseLine(~, ~)
  if(strcmp(hs.menuPreferencesShowBaseLine.Checked,'on'))
    hs.menuPreferencesShowBaseLine.Checked = 'off';
    showBaseLine = false;
    updateImage(true);
  else
    if(ischar(experiment.baseLine))
      ncbar.automatic('Loading baselines');
      [experiment, success] = loadTraces(experiment, 'baseLine');
      ncbar.close();
    end
    hs.menuPreferencesShowBaseLine.Checked = 'on';
    showBaseLine = true;
    updateImage(true);
  end
end

%--------------------------------------------------------------------------
function menuViewRaster(~, ~, ~)
  currentOrder = getappdata(hFigW, 'currentOrder');
  ncbar.automatic('Genarting raster...');
  h = plotFluoresenceRaster(experiment, selectedTraces(:, currentOrder), selectedT, 'cmap', cmapFull, 'savePlot', false);
  uimenu(h, 'Label', 'Export',  'Callback', {@exportFigCallback, {'*.png';'*.tiff';'*.pdf'}, [experiment.folder 'raster']});
  ncbar.close();
end

%--------------------------------------------------------------------------
function menuViewRasterNonNormalized(~, ~, ~)
  currentOrder = getappdata(hFigW, 'currentOrder');
  ncbar.automatic('Genarting raster...');
  h = plotFluoresenceRaster(experiment, selectedTraces(:, currentOrder), selectedT, 'cmap', cmapFull, 'savePlot', false, 'normalization', false);
  uimenu(h, 'Label', 'Export',  'Callback', {@exportFigCallback, {'*.png';'*.tiff'; '*.pdf'; '*.eps'}, [experiment.folder 'rasterNonNormalized']});
  ncbar.close();
end

%--------------------------------------------------------------------------
function menuPreferencesCompareExperiments(~, ~, ~)
  [selection, ok] = listdlg('PromptString', 'Select experiment to compare to', 'ListString', namesWithLabels(), 'SelectionMode', 'single');
  if(~ok)
    return;
  end
  experimentFile = [project.folderFiles project.experiments{selection} '.exp'];
  newExperiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
  % Only allo to compare experiments with the same number of ROIs
  %if(length(experiment.ROI) ~= length(newExperiment.ROI))
  %  logMsg('Number of ROI between the 2 experiments differ. Cannot compare them', 'e');
  %  return;
  %end

  newExperiment = checkGroups(newExperiment);
  newExperiment = loadTraces(newExperiment, 'all');
  [additionalValidIdx, additionalValidID, success] = findValidROI(experiment, additionalExperimentsList{:}, newExperiment);
  if(~success)
    return;
  end
  additionalExperimentsList(end+1) = {newExperiment};
  additionalExperiments = true;
  
  updateImage();
end

%--------------------------------------------------------------------------
function menuPreferencesCompareExperimentsReset(~, ~, ~)
  if(additionalExperiments)
     additionalExperiments = false;
     for i = 1:length(additionalExperimentsList)
       if(~isempty(additionalAxesList))
         delete(additionalAxesList(i));
         delete(additionalExperimentsPanelList(i));
       end
     end
     additionalExperimentsList = {};
     additionalExperimentsPanelList = [];
     additionalAxesList = [];
     updateImage();
  end
end

%--------------------------------------------------------------------------
function menuPreferencesCompareExperimentsTransitions(~, ~, type)

  if(length(additionalExperimentsList) > 1 || isempty(additionalExperimentsList))
    logMsg('Flow only possible with 1 additional experiment', 'e');
    return;
  end
  populationsBefore = zeros(size(experiment.traceGroups.classifier))';
  for i = 1:length(experiment.traceGroups.classifier)
    populationsBefore(i) = numel(intersect(additionalValidIdx{1},experiment.traceGroups.classifier{i}));
  end
  populationsAfter = zeros(size(additionalExperimentsList{1}.traceGroups.classifier))';
  for i = 1:length(additionalExperimentsList{1}.traceGroups.classifier)
    populationsAfter(i) = numel(intersect(additionalValidIdx{2},additionalExperimentsList{1}.traceGroups.classifier{i}));
  end
  populationsTransitions = zeros(numel(populationsBefore), numel(populationsAfter));
  for i = 1:length(experiment.traceGroups.classifier)
    for j= 1:length(additionalExperimentsList{1}.traceGroups.classifier)
      groupPrev = intersect(additionalValidIdx{1},experiment.traceGroups.classifier{i});
      groupAfter = intersect(additionalValidIdx{2},additionalExperimentsList{1}.traceGroups.classifier{j});
      repeats = ismember(groupPrev, groupAfter);
      populationsTransitions(i,j) = sum(repeats);
    end
  end

  switch type
    case 'circular'
      [success, circularTransitionsOptionsCurrent] = preloadOptions(experiment, circularTransitionsOptions, gui, true, false);
      if(success)
        experiment.circularTransitionsOptionsCurrent = circularTransitionsOptionsCurrent;
        hFig = plotCircularTransitions(populationsBefore, populationsTransitions, circularTransitionsOptionsCurrent);
        ui = uimenu(hFig, 'Label', 'Export');
        uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.png';'*.tiff';'*.pdf'}, [experiment.folder 'circular']});
      end
    case 'linear'
      [success, linearTransitionsOptionsCurrent] = preloadOptions(experiment, linearTransitionsOptions, gui, true, false);
      if(success)
        experiment.linearTransitionsOptionsCurrent = linearTransitionsOptionsCurrent;
        hFig = plotLinearTransitions(populationsBefore, populationsTransitions, linearTransitionsOptionsCurrent);
        ui = uimenu(hFig, 'Label', 'Export');
        uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.png';'*.tiff';'*.pdf'}, [experiment.folder 'linear']});
      end
  end
end

%--------------------------------------------------------------------------
function KClAnalysisMenu(~, ~)
  [success, ~, experiment] = preloadOptions(experiment, KClProtocolOptions, gui, true, false);
  if(~success)
    return;
  end
  % Do something (in case you need to)
  experiment = KClAnalysis(experiment, experiment.KClProtocolOptionsCurrent);
  updateImage(true);
end

%--------------------------------------------------------------------------
function KClPlot(~, ~, type)
  if(~isfield(experiment, 'KClProtocolData') || isempty(experiment.KClProtocolData))
    logMsg('Protocol data not found', 'e');
    return;
  end
  timeList = zeros(length(experiment.ROI), 1);
  for it = 1:length(experiment.KClProtocolData)
    if(isempty(experiment.KClProtocolData{it}))
      continue;
    end
    curData = experiment.KClProtocolData{it};
    switch type
      case 'reaction'
        timeList(it) = curData.reactionTime;
      case 'maxTime'
        timeList(it) = curData.maxResponseTime;
    end
  end
  valid = find(timeList);
  x = cellfun(@(x)x.center(1), experiment.ROI);
  y = cellfun(@(x)x.center(2), experiment.ROI);
  
  currFrame = experiment.avgImg;
  pos = hs.mainWindow.Position;
  ratio = experiment.width/experiment.height;
  hs.protocolWindow = figure('Visible','on',...
                     'Resize','on',...
                     'Toolbar', 'figure',...
                     'Tag','viewTraces', ...
                     'DockControls','off',...
                     'NumberTitle', 'off',...
                     'MenuBar', 'none',...
                     'Name', 'KCl acute protocol',...
                     'Position', [pos(1)+pos(3)+1 pos(2) 600 600/ratio]);
  hs.protocolWindow.Position = setFigurePosition(gcbf, 'width', 600, 'height', 600/ratio);
  superBox = uix.VBox('Parent', hs.protocolWindow);
  figPanel = uix.Panel('Parent', superBox, 'Padding', 5, 'BorderType', 'none');
  h = axes('Parent', uicontainer('Parent', figPanel));

  set(superBox, 'Heights', [-1], 'Padding', 0, 'Spacing', 0);

  cleanMenu(hs.protocolWindow);
  a = findall(hs.protocolWindow);
  b = findall(a, 'ToolTipString', 'Data Cursor');
  set(b,'Visible','on');
  
  figure(hs.protocolWindow);
  imData = imagesc(currFrame);
  hold on;
  axis equal tight;
  set(h, 'XTick', []);
  set(h, 'YTick', []);
  set(h, 'LooseInset', [0,0,0,0]);
  box on;

  [minIntensity, maxIntensity] = autoLevelsFIJI(currFrame, experiment.bpp, true);

  caxis([minIntensity/1.1 maxIntensity]);
  colormap(gray(256));

  ROI = experiment.ROI;
  ccmap = eval([cmapName '(256)']);
  ccmap = [0, 0, 0; ccmap];
  % Now I need to map the time to color value
  minT = min(timeList);
  maxT = max(timeList);
  newIdx = 1+round((timeList-minT)/(maxT-minT)*(256-1)+1);
  newIdx(timeList < minT) = 1;
  newIdx(isnan(timeList)) = 1;

  ccmap = ccmap(newIdx, :);
  %ccmap = eval([cmapName '(length(ROI)+1)']);
  
  imData2 = imagesc(ones(size(currFrame)), 'HitTest', 'on');
  
  ROIimg = visualizeROI(zeros(size(experiment.avgImg)), ROI, 'plot', false, 'color', true, 'mode', 'fast', 'cmap', ccmap);

  invalid = (ROIimg(:,:,1) == 0 & ROIimg(:,:,2) == 0 & ROIimg(:,:,3) == 0);

  alpha = ones(size(ROIimg,1), size(ROIimg,2))*0.75;
  alpha(invalid) = 0;

  set(imData2, 'CData', ROIimg);
  set(imData2, 'AlphaData', alpha);
  
  %scatter(x(valid), y(valid), 16, timeList(valid));
  
  switch type
    case 'reaction'
      title('Reaction time');
    case 'maxTime'
      title('Time maximum fluorescence');
  end
end

%--------------------------------------------------------------------------
% Pass false as the 4th argument to avoid replacing the standard colormap
% (useful for training)
function changeColormap(hObject, ~ ,~, varargin)
    cmapName = hObject.Label;
    
    % In case it comes from the menu
    mapNamePosition = strfind(cmapName, 'png">');
    if(~isempty(mapNamePosition))
        cmapName = cmapName(mapNamePosition+5:end);
    end
    
    if(length(varargin) == 1 && ~varargin{1})
    else
        cmapStandard = cmapName;
    end
    
    cmap = eval([cmapName '(numberTraces+1)']);
    cmapFull = eval([cmapName '(256)']);
    if(isfield(experiment, 'traceGroupsNames') && isfield(experiment.traceGroupsNames, 'classifier'))
      N = length(experiment.traceGroupsNames.classifier);
      cmapLearning = eval([cmapName '(N+1)']);
    end
    if(isfield(experiment, 'trainingEventGroups'))
        cmapLearningEvent = eval([cmapName '(experiment.trainingEventGroups+1)']);
    end
    if(isfield(experiment, 'traceGroups') && isfield(experiment.traceGroups, 'manual'))
      N = length(experiment.traceGroups.manual);
      cmapLearningManual = eval([cmapName '(N+1)']);
    end
    for i = 1:length(hs.cmaps)
        hs.cmaps(i).Checked = 'off';
    end
    hObject.Checked = 'on';
    if(~strcmp(learningMode, 'none'))
        cmap = zeros(size(cmap));
    end
    
    updateImage(true);
    %viewPositionsWholeScreenUpdate();
    viewPositionsOnScreenUpdate();
end

%--------------------------------------------------------------------------
function changeBackgroundColor(hObject, ~ ,~)    
    for i = 1:length(hs.bgColor)
        hs.bgColor(i).Checked = 'off';
    end
    hObject.Checked = 'on';
    if(strcmp(hObject.Label, 'grey'))
        set(hs.mainWindowFramesAxes, 'Color', [1 1 1]*0.94);
    else
        set(hs.mainWindowFramesAxes, 'Color', hObject.Label);
    end
end

%--------------------------------------------------------------------------
function KeyPress(hObject, eventData)

  switch eventData.Key
    case {'rightarrow', 'd'}
      nextTracesButton(hObject, eventData);
    case {'leftarrow', 'a'}
      previousTracesButton(hObject, eventData);
    case {'uparrow', 'w'}
      nextTracesButton(hObject, eventData, 5);
    case {'downarrow', 's'}
      previousTracesButton(hObject, eventData, 5);
    case {'1', '2', '3', '4', '5', '6', '7', '8', '9'}
      selGroup = str2num(eventData.Key);
      if(selGroup == hs.mainWindowLearningGroupSelection.Value)
        return;
      end
      switch learningMode
        case 'trace'
          if(selGroup <= length(experiment.traceGroupsNames.classifier))
            hs.mainWindowLearningGroupSelection.Value = selGroup;
          end
        case 'event'
          if(selGroup <= length(experiment.learningEventOptionsCurrent.groupNames))
            hs.mainWindowLearningGroupSelection.Value = selGroup;
          end
        case 'manual'
          if(selGroup <= length(experiment.traceGroupsNames.manual))
            hs.mainWindowLearningGroupSelection.Value = selGroup;
          end
      end
      updateImage(true);
  end
end

%--------------------------------------------------------------------------
function menuFeatureSelection(~, ~)
  if(~isfield(experiment, 'traces') && ~ischar(experiment.traces))
    logMsg('No smoothed traces found. Do that first');
    return;
  end
  [success, obtainFeaturesOptionsCurrent] = preloadOptions(experiment, obtainFeaturesOptions, gui, true, false);
  if(success)
    experiment = obtainFeatures(experiment, obtainFeaturesOptionsCurrent);
    experiment.obtainFeaturesOptionsCurrent = obtainFeaturesOptionsCurrent;
    if(~isempty(gui))
      setappdata(gui, 'obtainFeaturesOptionsCurrent', obtainFeaturesOptionsCurrent);
    end
    updateMenu();
  end
end

%--------------------------------------------------------------------------
function generatePredefinedPatternsMenu(~, ~)
  optionsClass = predefinedPatternsOptions;
  [success, optionsClassCurrent] = preloadOptions(experiment, optionsClass, gui, true, false);
  if(success)
    experiment = generatePredefinedPatterns(experiment, optionsClassCurrent);
    experiment.([class(optionsClassCurrent) 'Current']) = optionsClassCurrent;
    if(~isempty(gui))
      setappdata(gui, [class(optionsClassCurrent) 'Current'], optionsClassCurrent);
    end
    updateMenu();
  end
end

%--------------------------------------------------------------------------
function menuDetectPatterns(~, ~, parallelMode)
  [success, tracePatternDetectionOptionsCurrent] = preloadOptions(experiment, tracePatternDetectionOptions, gui, true, false);
  
  if(success)
    experiment.tracePatternDetectionOptionsCurrent = tracePatternDetectionOptionsCurrent;
    experiment = tracePatternDetection(experiment, tracePatternDetectionOptionsCurrent, 'parallelMode', parallelMode);
    if(~isempty(gui))
      setappdata(gui, 'obtainPatternBasedFeaturesOptionsCurrent', tracePatternDetectionOptionsCurrent);
    end
    updateMenu();
    updateImage(true);
    if(strcmpi(hs.menuPreferencesShowPatterns.Checked, 'on'))
      hs.menuPreferencesShowPatterns.Checked = 'off';
      menuPreferencesShowPatterns([], []);
    end
  end
end
    
%--------------------------------------------------------------------------
function learningStart(~, ~, ~)
  [success, ~, experiment] = preloadOptions(experiment, learningOptions, gui, true, false);
  if(success)
    experiment.traceGroupsNames.classifier = experiment.learningOptionsCurrent.groupNames;
    if(~isempty(gui))
      setappdata(gui, 'learningOptionsCurrent', experiment.learningOptionsCurrent);
    end
    if(~isfield(experiment, 'learningGroup') || numel(experiment.learningGroup) ~= size(selectedTraces, 2))
      experiment.learningGroup = nan(size(selectedTraces,2), 1);
    end
    learningMode = 'trace';

    h.Label = 'hsv';
    changeColormap(h, [], [], false);
    cmap = zeros(size(cmap));
    updateButtons();
    updateImage(true);
    updateMenu();
    N = length(experiment.traceGroupsNames.classifier);
    cmapLearning = eval([cmapName '(N+1)']);
  end
end

%--------------------------------------------------------------------------
function learningManualStart(~, ~, ~)
  [success, learningManualOptionsCurrent] = preloadOptions(experiment, learningManualOptions, gui, true, false);
  if(success)
    experiment.traceGroupsNames.manual = learningManualOptionsCurrent.groupNames;
    experiment.learningManualOptionsCurrent = learningManualOptionsCurrent;
    if(~isfield(experiment, 'traceGroups'))
      experiment.traceGroups = struct;
    end
    if(~isfield(experiment.traceGroups, 'manual'))
        experiment.traceGroups.manual = cell(length(experiment.traceGroupsNames.manual), 1);
    end

    setappdata(gui, 'learningManualOptionsCurrent', learningManualOptionsCurrent);
    learningMode = 'manual';

    h.Label = 'hsv';
    cmap = zeros(size(cmap));
    N = length(experiment.traceGroupsNames.manual);
    cmapLearning = eval([cmapName '(N+1)']);
    changeColormap(h, [], [], false);
    updateButtons();
    updateImage(true);
    updateMenu();
  end
end

%--------------------------------------------------------------------------
function learningReset(~, ~, type)
  choice = questdlg('Are you sure you want to reset all classifications?', 'Reset classification', ...
                       'Yes', 'No', 'Cancel', 'Cancel');
  if(~strcmpi(choice, 'Yes'))
    return;
  end
  switch type
    case 'all'
      categories = fieldnames(experiment.traceGroups);
      for it = 1:length(categories)
        % Remove all but category everything
        if(~strcmpi(categories{it}, 'everything'))
          if(isfield(experiment.traceGroups, categories{it}))
            experiment.traceGroups = rmfield(experiment.traceGroups, categories{it});
          end
          if(isfield(experiment.traceGroupsNames, categories{it}))
            experiment.traceGroupsNames = rmfield(experiment.traceGroupsNames, categories{it});
          end
          orderCategories = fieldnames(experiment.traceGroupsOrder);
          for itt = 1:length(orderCategories)
            if(isfield(experiment.traceGroupsOrder.(orderCategories{itt}), categories{it}))
              try
                experiment.traceGroupsOrder.(orderCategories{it}) = rmfield(experiment.traceGroupsOrder.(orderCategories{itt}), categories{it});
              end
            end
          end
        end
      end
      if(isfield(experiment, 'validPatterns'))
        experiment.validPatterns = cell(size(experiment.validPatterns));
      end
    otherwise
      categories = type;
      % Remove all but category everything
        if(~strcmpi(categories, 'everything'))
          if(isfield(experiment.traceGroups, categories))
            experiment.traceGroups = rmfield(experiment.traceGroups, categories);
          end
          if(isfield(experiment.traceGroupsNames, categories))
            experiment.traceGroupsNames = rmfield(experiment.traceGroupsNames, categories);
          end
          orderCategories = fieldnames(experiment.traceGroupsOrder);
          for itt = 1:length(orderCategories)
            if(isfield(experiment.traceGroupsOrder.(orderCategories{itt}), categories))
              experiment.traceGroupsOrder.(orderCategories{itt}) = rmfield(experiment.traceGroupsOrder.(orderCategories{itt}), categories);
            end
          end
        end
        % Specific
        if(strcmpi(categories, 'classifier'))
          experiment.learningGroup = NaN(size(experiment.learningGroup));
        end
        % Specific
        if(strcmpi(categories, 'event'))
          if(isfield(experiment, 'learningEventGroupCount'))
            experiment = rmfield(experiment, 'learningEventGroupCount');
          end
          if(isfield(experiment, 'learningEventListPerTrace'))
            experiment = rmfield(experiment, 'learningEventListPerTrace');
          end
        end
  end
    learningMode = 'none';
    h.Label = cmapStandard;
    changeColormap(h);
    setappdata(hFigW, 'experiment', experiment);
    hs.menu.traces.selection = redoSelectionMenu(experiment, hs.menu.traces);
    updateButtons();
    updateImage(true);
    updateMenu();
end

%--------------------------------------------------------------------------
function learningFinish(~, ~, ~)
    if(strcmpi(learningMode, 'manual'))
      % Update selection lists      
      experiment.traceGroupsOrder.ROI.manual = cell(length(experiment.traceGroups.manual), 1);
      experiment.traceGroupsOrder.similarity.manual = cell(length(experiment.traceGroups.manual), 1);
      for it = 1:length(experiment.traceGroups.manual)
        experiment.traceGroupsOrder.ROI.manual{it} = sort(experiment.traceGroups.manual{it});
        % Now do the similarities
        if(length(experiment.traceGroupsOrder.ROI.manual{it}) > 2)
          [~, order, ~] = identifySimilaritiesInTraces(experiment, experiment.traces(:, experiment.traceGroups.manual{it}), 'saveSimilarityMatrix', false, 'showSimilarityMatrix', false, 'verbose', true);
        else
          order = 1:length(experiment.traceGroupsOrder.ROI.manual{it});
        end
        experiment.traceGroupsOrder.similarity.manual{it} = experiment.traceGroupsOrder.ROI.manual{it}(order);
      end
      setappdata(hFigW, 'experiment', experiment);
      hs.menu.traces.selection = redoSelectionMenu(experiment, hs.menu.traces);
    end
    
    learningMode = 'none';
    h.Label = cmapStandard;
    changeColormap(h);
    updateButtons();
    updateImage(true);
    updateMenu();
end

%--------------------------------------------------------------------------
function exportGroups(~, ~)
  [selectedPopulations, groupsStruct] = treeGroupsSelection(experiment, 'Select groups to export', true, true);
  
  if(isempty(selectedPopulations) || isempty(groupsStruct))
    return;
  end

  defaultFile = [experiment.folder filesep 'groups.json'];
  [fileName, pathName] = uiputfile('*.json','Save group file as', defaultFile);
  fileName = [pathName fileName];
 
  try
    fileData = savejson([], groupsStruct, 'ParseLogical', true, 'SingletCell', 1, 'ArrayToStruct', 1);
  catch ME
    if(strcmpi(ME.identifier, 'MATLAB:UndefinedFunction'))
      errMsg = {'jsonlab toolbox missing. Please install it from the installDependencies folder'};
      uiwait(msgbox(errMsg,'Error','warn'));
    else
      logMsg('Something went wrong with json. Is jsonlab toolbox installed?', 'e');
    end
    return;
  end
  fID = fopen(fileName, 'w');
  fprintf(fID, '%s', fileData);
  fclose(fID);
  logMsg('Groups successfully exported');

end

%--------------------------------------------------------------------------
function importGroups(~, ~, type)
  switch type
    case 'file'
      defaultFile = [experiment.folder filesep 'groups.json'];
      [fileName, pathName] = uigetfile('*.json','Load group file as', defaultFile);
      if(isempty(fileName) || fileName(1) == 0)
        return;
      end
      fileName = [pathName fileName];
      try
        groupsStruct = loadjson(fileName, 'SimplifyCell', 0);
      catch ME
         if(strcmpi(ME.identifier, 'MATLAB:UndefinedFunction'))
           errMsg = {'jsonlab toolbox missing. Please install it from the installDependencies folder'};
           uiwait(msgbox(errMsg,'Error','warn'));
         else
          logMsg('Something went wrong with json. Is jsonlab toolbox installed?', 'e');
         end
         return;
      end
    case 'project'
      [selection, ok] = listdlg('PromptString', 'Select experiment to compare to', 'ListString', namesWithLabels(), 'SelectionMode', 'single');
      if(~ok)
        return;
      end
      experimentFile = [project.folderFiles project.experiments{selection} '.exp'];
      newExperiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
      groupsStruct = newExperiment;
  end
  [selectedPopulations, groupsStruct] = treeGroupsSelection(groupsStruct, 'Select groups to import', true, true);
  
  % Do a first pass to check that the top idx are valid and not out of bounds
  maxIdx = -inf;
  namesGroups = fieldnames(groupsStruct.traceGroups);
  for it = 1:length(namesGroups)
    for it2 = 1:length(groupsStruct.traceGroups.(namesGroups{it}))
      maxIdx = max([maxIdx; groupsStruct.traceGroups.(namesGroups{it}){it2}(:)]);
    end
  end
  if(maxIdx > length(experiment.ROI))
    logMsg('Cannot import these groups. There are more ROI than in the original experiment', 'e');
    return;
  end
  
  % Let's import everything
  tmpExperiment = experiment;
  % First make sure the structure exists
  namesGroups = fieldnames(groupsStruct.traceGroups);
  if(~isfield(tmpExperiment, 'traceGroups'))
    tmpExperiment.traceGroups = struct;
  end
  if(~isfield(tmpExperiment, 'traceGroupsNames'))
    tmpExperiment.traceGroupsNames = struct;
  end
  for it = 1:length(namesGroups)
    if(~isfield(tmpExperiment.traceGroups, namesGroups{it}))
      tmpExperiment.traceGroups.(namesGroups{it}) = {};
    end
    if(~isfield(tmpExperiment.traceGroupsNames, namesGroups{it}))
      tmpExperiment.traceGroupsNames.(namesGroups{it}) = {};
    end
  end
  orderNames = fieldnames(groupsStruct.traceGroupsOrder);
  if(~isfield(tmpExperiment, 'traceGroupsOrder'))
    tmpExperiment.traceGroupsOrder = struct;
  end
  for it = 1:length(orderNames)
    if(~isfield(tmpExperiment.traceGroupsOrder, (orderNames{it})))
      tmpExperiment.traceGroupsOrder.(orderNames{it}) = struct;
    end
    for it2 = 1:length(namesGroups)
      if(~isfield(tmpExperiment.traceGroupsOrder.(orderNames{it}), namesGroups{it2}))
        tmpExperiment.traceGroupsOrder.(orderNames{it}).namesGroups{it2} = {};
      end
    end
  end
  
  % Now we should have the correct structure, migth be empty or not
  for it = 1:length(orderNames) % iteratres ROI/sim
    orderNamesGroups = fieldnames(groupsStruct.traceGroupsOrder.(orderNames{it}));
    for it2 = 1:length(orderNamesGroups) % Iterates classifier / HCG
      for it3 = 1:length(groupsStruct.traceGroupsOrder.(orderNames{it}).(orderNamesGroups{it2})) % Iterates classifier elements
        % Look if there already is a group with the same name, if so, get its index and overwrite
        repeated = false;
        for it4 = 1:length(tmpExperiment.traceGroupsNames.(orderNamesGroups{it2}))
          if(strcmpi(tmpExperiment.traceGroupsNames.(orderNamesGroups{it2}){it4}, groupsStruct.traceGroupsNames.(orderNamesGroups{it2}){it3}))
            tmpExperiment.traceGroupsOrder.(orderNames{it}).(orderNamesGroups{it2}){it4} = groupsStruct.traceGroupsOrder.(orderNames{it}).(orderNamesGroups{it2}){it3};
            repeated = true;
            break;
          end
        end
        if(~repeated)
          if(~isfield(tmpExperiment.traceGroupsOrder, orderNames{it}))
            tmpExperiment.traceGroupsOrder.(orderNames{it}) = struct;
          end
          if(~isfield(tmpExperiment.traceGroupsOrder.(orderNames{it}),orderNamesGroups{it2}))
            tmpExperiment.traceGroupsOrder.(orderNames{it}).(orderNamesGroups{it2}) = {};
          end
          tmpExperiment.traceGroupsOrder.(orderNames{it}).(orderNamesGroups{it2}){end+1} = groupsStruct.traceGroupsOrder.(orderNames{it}).(orderNamesGroups{it2}){it3};
        end
      end
    end
  end
  % Now for the other structures
  namesGroups = fieldnames(groupsStruct.traceGroups);
  for it2 = 1:length(namesGroups) % Iterates classifier / HCG
    for it3 = 1:length(groupsStruct.traceGroups.(namesGroups{it2})) % Iterates classifier names
      repeated = false;
      for it4 = 1:length(tmpExperiment.traceGroupsNames.(namesGroups{it2}))
        if(strcmpi(tmpExperiment.traceGroupsNames.(namesGroups{it2}){it4}, groupsStruct.traceGroupsNames.(namesGroups{it2}){it3}))
          tmpExperiment.traceGroups.(namesGroups{it2}){it4} = groupsStruct.traceGroups.(namesGroups{it2}){it3};
          tmpExperiment.traceGroupsNames.(namesGroups{it2}){it4} = groupsStruct.traceGroupsNames.(namesGroups{it2}){it3};
          repeated = true;
          logMsg(['Found repeated group: ' orderNamesGroups{it2} ' - ' groupsStruct.traceGroupsNames.(namesGroups{it2}){it3} ' will overwrite'], 'w');
          break;
        end
      end
      if(~repeated)
        if(~isfield(tmpExperiment.traceGroups, namesGroups{it2}))
          tmpExperiment.traceGroups.(namesGroups{i2}) = {};
        end
        if(~isfield(tmpExperiment.traceGroupsNames, namesGroups{it2}))
          tmpExperiment.traceGroupsNames.(namesGroups{i2}) = {};
        end
        tmpExperiment.traceGroups.(namesGroups{it2}){end+1} = groupsStruct.traceGroups.(namesGroups{it2}){it3};
        tmpExperiment.traceGroupsNames.(namesGroups{it2}){end+1} = groupsStruct.traceGroupsNames.(namesGroups{it2}){it3};
      end
    end
  end
  logMsg('Groups successfully imported');
  experiment = tmpExperiment;
  setappdata(hFigW, 'experiment', experiment);
  hs.menu.traces.selection = redoSelectionMenu(tmpExperiment, hs.menu.traces);
  updateMenu();
  
end

%--------------------------------------------------------------------------
function buttonMotion(hObject, eventData)
  
  if((strcmp(learningMode, 'trace') || strcmp(learningMode, 'manual')) && ~isempty(buttonDown) && buttonDown)
    % get bottom right corner of rectangle
    rectangleEnd = get(gca,'CurrentPoint');

    % get the top left corner and width and height of 
    % rectangle (note the absolute value forces it to "open"
    % from left to right - need smarter logic for other direction)

    corners = [rectangleStart(1,1:2);
               rectangleEnd(1,1:2);
               rectangleStart(1,1) rectangleEnd(1,2);
               rectangleEnd(1,1) rectangleStart(1,2)];

    topLeft = find(corners(:,1) == min(corners(:,1)) & corners(:,2) == min(corners(:,2)));
    bottomRight = find(corners(:,1) == max(corners(:,1)) & corners(:,2) == max(corners(:,2)));

    x = corners(topLeft, 1);
    y = corners(topLeft, 2);
    w = abs(x-corners(bottomRight, 1));
    h = abs(y-corners(bottomRight, 2));
    
    if(isempty(w) || isempty(h) || w(1) == 0 || h(1) == 0)
      return;
    end

    % only draw the rectangle if the width and height are positive
    if(w>0 && h>0)
      % rectangle drawn in white (better colour needed for different
      % images?)
      currentColor = cmapLearning(hs.mainWindowLearningGroupSelection.Value, :);
      if isempty(rectangleH)
        % empty so rectangle not yet drawn
        rectangleH = rectangle('Position',[x,y,w,h],'EdgeColor', currentColor, 'LineStyle', '--', 'LineWidth', 2);
      else
        % need to redraw
        set(rectangleH,'Position',[x,y,w,h],'EdgeColor', currentColor, 'LineStyle', '--', 'LineWidth', 2);
      end
    end
  elseif(strcmp(learningMode, 'event') && ~isempty(buttonDown) && buttonDown)
    % get bottom right corner of rectangle
    rectangleEnd = get(gca,'CurrentPoint');

    % get the top left corner and width and height of 
    % rectangle (note the absolute value forces it to "open"
    % from left to right - need smarter logic for other direction)

    corners = [rectangleStart(1,1:2);
               rectangleEnd(1,1:2);
               rectangleStart(1,1) rectangleEnd(1,2);
               rectangleEnd(1,1) rectangleStart(1,2)];

    topLeft = find(corners(:,1) == min(corners(:,1)) & corners(:,2) == min(corners(:,2)));
    bottomRight = find(corners(:,1) == max(corners(:,1)) & corners(:,2) == max(corners(:,2)));

    x = corners(topLeft, 1);
    y = corners(topLeft, 2);
    w = abs(x-corners(bottomRight, 1));
    h = abs(y-corners(bottomRight, 2));
    
    if(isempty(w) || isempty(h) || w(1) == 0 || h(1) == 0)
      return;
    end

    % only draw the rectangle if the width and height are positive
    if(w>0 && h>0)
      % rectangle drawn in white (better colour needed for different
      % images?)
      currentColor = cmapLearning(hs.mainWindowLearningGroupSelection.Value, :);
      if(isempty(rectangleH) | ~ishandle(rectangleH))
        % empty so rectangle not yet drawn
        %rectangleH = rectangle('Position',[x,y,w,h],'EdgeColor', currentColor, 'LineStyle', '--', 'LineWidth', 2);
        rectangleH = line([x, x+w], [y y], 'Color', currentColor, 'LineStyle', '-', 'LineWidth', 2);
      else
        set(rectangleH, 'XData', [x, x+w]);
        % need to redraw
        %set(rectangleH,'Position',[x,y,w,h],'EdgeColor', currentColor, 'LineStyle', '--', 'LineWidth', 2);
      end
    end
  end
end

%--------------------------------------------------------------------------
function rightClickUp(hObject, eventData, ~)
  if(~buttonDown)
    return;
  end
  if(strcmp(learningMode, 'trace'))
    buttonDown = false;
    % delete the rectangle from the figure
    delete(rectangleH);

    % clear the handle
    rectangleH = [];

    corners = [rectangleStart(1,1:2);
               rectangleEnd(1,1:2);
               rectangleStart(1,1) rectangleEnd(1,2);
               rectangleEnd(1,1) rectangleStart(1,2)];

    topLeft = find(corners(:,1) == min(corners(:,1)) & corners(:,2) == min(corners(:,2)));
    bottomRight = find(corners(:,1) == max(corners(:,1)) & corners(:,2) == max(corners(:,2)));

    cp = round(corners(topLeft, 2)):round(corners(bottomRight, 2));
    lineChanged = [];
    for itt = 1:length(cp)
      closestHandle = cp(itt);
      
      if(closestHandle >= 1 && closestHandle <= min(numberTraces, length(currentOrder)-firstTrace+1))
        if(experiment.learningGroup(currentOrder(firstTrace+closestHandle-1)) == hs.mainWindowLearningGroupSelection.Value)
          %experiment.learningGroup(currentOrder(firstTrace+closestHandle-1)) = NaN;
          lineChanged = [lineChanged; [1 currentOrder(firstTrace+closestHandle-1)]]; % We want to remove this handle
        else
          %experiment.learningGroup(currentOrder(firstTrace+closestHandle-1)) = hs.mainWindowLearningGroupSelection.Value;
          %lineChanged = true;
          lineChanged = [lineChanged; [2 currentOrder(firstTrace+closestHandle-1)]]; % We want to remove this handle
        end
      end
    end
    if(~isempty(lineChanged))
      if(all(lineChanged(:,1) == 1))
        % If all handles need to be removed, do so
        for itt = 1:size(lineChanged, 1)
          experiment.learningGroup(lineChanged(itt, 2)) = NaN;
        end
          updateImage(true);
      else
        % Else, add all the handles
        for itt = 1:size(lineChanged, 1)
          experiment.learningGroup(lineChanged(itt, 2)) = hs.mainWindowLearningGroupSelection.Value;
        end
        updateImage(true);
      end
    end
  elseif(strcmp(learningMode, 'manual'))
    buttonDown = false;
    % delete the rectangle from the figure
    delete(rectangleH);

    % clear the handle
    rectangleH = [];

    corners = [rectangleStart(1,1:2);
               rectangleEnd(1,1:2);
               rectangleStart(1,1) rectangleEnd(1,2);
               rectangleEnd(1,1) rectangleStart(1,2)];

    topLeft = find(corners(:,1) == min(corners(:,1)) & corners(:,2) == min(corners(:,2)));
    bottomRight = find(corners(:,1) == max(corners(:,1)) & corners(:,2) == max(corners(:,2)));

    cp = round(corners(topLeft, 2)):round(corners(bottomRight, 2));
    lineChanged = [];
    for itt = 1:length(cp)
      closestHandle = cp(itt);
      if(closestHandle >= 1 && closestHandle <= numberTraces)
        curIdx = currentOrder(firstTrace+closestHandle-1);
        found = [];
        for it = 1:length(experiment.traceGroups.manual)
          % Check if that trace was already assigned
          idxPos = find(experiment.traceGroups.manual{it} == curIdx);
          if(idxPos)
            found = it;
            break;
          end
        end
        if(found)
          % If it is found in the current group, disable, if not, move it
          if(found == hs.mainWindowLearningGroupSelection.Value)
            lineChanged = [lineChanged; [1 currentOrder(firstTrace+closestHandle-1) found]]; % We want to remove this handle
          else
            lineChanged = [lineChanged; [3 currentOrder(firstTrace+closestHandle-1) found]]; % We want to reassign
          end
        else
          lineChanged = [lineChanged; [2 currentOrder(firstTrace+closestHandle-1) 0]]; % We want to add
        end
      end
    end
    if(~isempty(lineChanged))
      if(all(lineChanged(:,1) == 1))
        % If all handles need to be removed, do so
        for itt = 1:size(lineChanged, 1)
          found = lineChanged(itt,3);
          valid = find(experiment.traceGroups.manual{found} == lineChanged(itt, 2));
          experiment.traceGroups.manual{found}(valid) = [];
        end
          updateImage(true);
      else
        % Else, add all the handles
        for itt = 1:size(lineChanged, 1)
          % Check if we need to reassign
          if(lineChanged(itt, 1) == 3)
            found = lineChanged(itt, 3);
            valid = find(experiment.traceGroups.manual{found} == lineChanged(itt, 2));
            experiment.traceGroups.manual{found}(valid) = [];
          end
          % Now we can safely add
          experiment.traceGroups.manual{hs.mainWindowLearningGroupSelection.Value} = ...
                sort([experiment.traceGroups.manual{hs.mainWindowLearningGroupSelection.Value}; lineChanged(itt, 2)]);
        end
        updateImage(true);
      end
    end
  elseif(strcmp(learningMode, 'event'))
    buttonDown = false;
    if(~ishandle(rectangleH))
      return;
    end
    range = get(rectangleH, 'XData');
    rangeY = get(rectangleH, 'YData');
    % delete the rectangle from the figure
    delete(rectangleH);
    
    % clear the handle
    rectangleH = [];
    if(isempty(range))
      return;
    end
    [~, frameMin] = min(abs(selectedT-range(1)));
    [~, frameMax] = min(abs(selectedT-range(2)));
    frameRange = frameMin:frameMax;
    
    closestHandle = round(rangeY(1));
    if(closestHandle >= 1 && closestHandle <= numberTraces)
      
      eventTraceF = selectedTraces(:, currentOrder(firstTrace+closestHandle-1));
      % Only use part of the trace around closestT
      range = frameRange;
      %[~, closestT] = max(eventTraceF(range));
      %closestT = closestT + range(1) - 1;
      closestT = round(mean(range));
      meanF = mean(eventTraceF(range));
      stdF = std(eventTraceF(range));
      threshold = meanF+stdF*experiment.learningEventOptionsCurrent.eventLearningThreshold;
      aboveThreshold = eventTraceF >= threshold;
      for i = closestT-1:-1:1
        if(~aboveThreshold(i))
            i = i+1;
            break;
        end
      end
      lowerLimit = i;
      for i = closestT+1:length(aboveThreshold)
        if(~aboveThreshold(i))
            i = i-1;
            break;
        end
      end
      upperLimit = i;
     
      eventList = experiment.learningEventListPerTrace{currentOrder(firstTrace+closestHandle-1)};

      % Check if the event already exists
      for i = 1:length(eventList)
        if(~isempty(intersect(eventList{i}.x', range)))
          oldGroup = eventList{i}.group;
          % If it is in the current group remove it
          if(oldGroup == hs.mainWindowLearningGroupSelection.Value) 
            eventList(i) = [];
            experiment.learningEventListPerTrace{currentOrder(firstTrace+closestHandle-1)} = eventList;
            experiment.learningEventGroupCount(hs.mainWindowLearningGroupSelection.Value) = experiment.learningEventGroupCount(hs.mainWindowLearningGroupSelection.Value) - 1;
            updateImage(true);
            return;
            % Else, delete it and break (so it is added to the current group)
          else
            eventList(i) = [];
            experiment.learningEventListPerTrace{currentOrder(firstTrace+closestHandle-1)} = eventList;
            experiment.learningEventGroupCount(oldGroup) = experiment.learningEventGroupCount(oldGroup) - 1;
            break;
          end
        end
      end
      if(length(lowerLimit:upperLimit) <= experiment.learningEventOptionsCurrent.minEventSize*experiment.fps)
        logMsg(sprintf('Event too small at t=%.2f s', selectedT(closestT)), 'w');
        return;
      end
      
      lastID = lastID + 1;
      eventList{length(eventList)+1}.id = lastID;
      eventList{end}.x = (lowerLimit:upperLimit);
      eventList{end}.y = eventTraceF(lowerLimit:upperLimit);
      eventList{end}.group = hs.mainWindowLearningGroupSelection.Value;
      eventList{end}.basePattern = experiment.trainingEventGroupNames{eventList{end}.group};
      %eventList{end}.group = hs.mainWindowLearningGroupSelection.Value;
      experiment.learningEventListPerTrace{currentOrder(firstTrace+closestHandle-1)} = eventList;
      experiment.learningEventGroupCount(hs.mainWindowLearningGroupSelection.Value) = experiment.learningEventGroupCount(hs.mainWindowLearningGroupSelection.Value) + 1;

      updateImage(true);
    end
  end
end
  
%--------------------------------------------------------------------------
function rightClick(hObject, eventData, ~)
  currentOrder = getappdata(hFigW, 'currentOrder');
  % If show patterns is on, check if we are clicking on a pattern, then display its properties
  if(showPatterns)
    clickedPoint = get(hs.mainWindowFramesAxes,'currentpoint');
    closestHandle = round(clickedPoint(3));
    if(closestHandle >= 1 && closestHandle <= numberTraces)
        [~, closestT] = min(abs(selectedT-clickedPoint(1)));
        curNeuron = currentOrder(firstTrace+closestHandle-1);
        cpatterns = experiment.validPatterns{curNeuron};
        for j = 1:length(cpatterns)
          if(any(cpatterns{j}.frames == closestT))
            %[patterns, basePatternList] = generatePatternList(experiment);
            logMsg(sprintf('ROI: %d - Pattern: %s - basePattern: %s - correlation: %.3f', ROIid(curNeuron), patterns{cpatterns{j}.pattern}.fullName, patterns{cpatterns{j}.pattern}.basePattern, cpatterns{j}.coeff), 'w');
          end
        end
    end
  end
  if(strcmp(learningMode, 'trace') && eventData.Button == 1)
    hFig = ancestor(hObject, 'Figure');
    if(strcmpi(hFig.SelectionType, 'extend'))
      % get top left corner of rectangle
      buttonDown = true;
      rectangleStart = get(gca,'CurrentPoint');
      return;
    end
    
    clickedPoint = get(hs.mainWindowFramesAxes,'currentpoint');
    closestHandle = round(clickedPoint(3));

    if(closestHandle >= 1 && closestHandle <= numberTraces)
        if(experiment.learningGroup(currentOrder(firstTrace+closestHandle-1)) == hs.mainWindowLearningGroupSelection.Value)
            experiment.learningGroup(currentOrder(firstTrace+closestHandle-1)) = NaN;
        else
            experiment.learningGroup(currentOrder(firstTrace+closestHandle-1)) = hs.mainWindowLearningGroupSelection.Value;
        end
        updateImage(true);
    end
  elseif(strcmp(learningMode, 'manual') && eventData.Button == 1)
    hFig = ancestor(hObject, 'Figure');
    if(strcmpi(hFig.SelectionType, 'extend'))
      % get top left corner of rectangle
      buttonDown = true;
      rectangleStart = get(gca,'CurrentPoint');
      return;
    end
    clickedPoint = get(hs.mainWindowFramesAxes,'currentpoint');
    closestHandle = round(clickedPoint(3));
    if(closestHandle >= 1 && closestHandle <= numberTraces)
      curIdx = currentOrder(firstTrace+closestHandle-1);
      found = [];
      for it = 1:length(experiment.traceGroups.manual)
        % Check if that trace was already assigned
        idxPos = find(experiment.traceGroups.manual{it} == curIdx);
        if(idxPos)
          found = it;
          break;
        end
      end
      if(found)
        % If it is found in the current group, disable, if not, move it
          if(found == hs.mainWindowLearningGroupSelection.Value)
            experiment.traceGroups.manual{found}(idxPos) = [];
          else
            experiment.traceGroups.manual{found}(idxPos) = [];
            experiment.traceGroups.manual{hs.mainWindowLearningGroupSelection.Value} = ...
              sort([experiment.traceGroups.manual{hs.mainWindowLearningGroupSelection.Value}; curIdx]);
          end
      else
        experiment.traceGroups.manual{hs.mainWindowLearningGroupSelection.Value} = ...
              sort([experiment.traceGroups.manual{hs.mainWindowLearningGroupSelection.Value}; curIdx]);
      end
      updateImage(true);
    end
  elseif(strcmp(learningMode, 'event') && eventData.Button == 1)
    hFig = ancestor(hObject, 'Figure');
    if(strcmpi(hFig.SelectionType, 'extend'))
      % get top left corner of rectangle
      buttonDown = true;
      rectangleStart = get(gca,'CurrentPoint');
      return;
    end
    clickedPoint = get(hs.mainWindowFramesAxes,'currentpoint');
    closestHandle = round(clickedPoint(3));
    if(closestHandle >= 1 && closestHandle <= numberTraces)
      [~, closestT] = min(abs(selectedT-clickedPoint(1)));
      eventTraceF = selectedTraces(:, currentOrder(firstTrace+closestHandle-1));
      % Only use part of the trace around closestT
      range = round(closestT+[-1, 1]*experiment.learningEventOptionsCurrent.samplingSize/2*experiment.fps);
      range(1) = max(1, range(1));
      range(2) = min(length(eventTraceF), range(2));
      range = range(1):range(2);
      meanF = mean(eventTraceF(range));
      stdF = std(eventTraceF(range));
      threshold = meanF+stdF*experiment.learningEventOptionsCurrent.eventLearningThreshold;
      aboveThreshold = eventTraceF >= threshold;
      for i = closestT-1:-1:1
        if(~aboveThreshold(i))
            i = i+1;
            break;
        end
      end
      lowerLimit = i;
      for i = closestT+1:length(aboveThreshold)
        if(~aboveThreshold(i))
            i = i-1;
            break;
        end
      end
      upperLimit = i;
      if(length(lowerLimit:upperLimit) <= experiment.learningEventOptionsCurrent.minEventSize*experiment.fps)
        logMsg(sprintf('Event too small at t=%.2f s', selectedT(closestT)), 'w');
        return;
      end
      eventList = experiment.learningEventListPerTrace{currentOrder(firstTrace+closestHandle-1)};

      % Check if the event already exists
      for i = 1:length(eventList)
          if(~isempty(intersect(eventList{i}.x', (lowerLimit:upperLimit))))

              oldGroup = eventList{i}.group;
              % If it is in the current group remove it
              if(oldGroup == hs.mainWindowLearningGroupSelection.Value) 
                  eventList(i) = [];
                  experiment.learningEventListPerTrace{currentOrder(firstTrace+closestHandle-1)} = eventList;
                  experiment.learningEventGroupCount(hs.mainWindowLearningGroupSelection.Value) = experiment.learningEventGroupCount(hs.mainWindowLearningGroupSelection.Value) - 1;
                  updateImage(true);
                  return;
                  % Else, delete it and break (so it is added to the current group)
              else
                  eventList(i) = [];
                  experiment.learningEventListPerTrace{currentOrder(firstTrace+closestHandle-1)} = eventList;
                  experiment.learningEventGroupCount(oldGroup) = experiment.learningEventGroupCount(oldGroup) - 1;
                  break;
              end
          end
      end
      lastID = lastID + 1;
      eventList{length(eventList)+1}.id = lastID;
      eventList{end}.x = (lowerLimit:upperLimit);
      eventList{end}.y = eventTraceF(lowerLimit:upperLimit);
      eventList{end}.group = hs.mainWindowLearningGroupSelection.Value;
      eventList{end}.basePattern = experiment.trainingEventGroupNames{eventList{end}.group};
      %eventList{end}.group = hs.mainWindowLearningGroupSelection.Value;
      experiment.learningEventListPerTrace{currentOrder(firstTrace+closestHandle-1)} = eventList;
      experiment.learningEventGroupCount(hs.mainWindowLearningGroupSelection.Value) = experiment.learningEventGroupCount(hs.mainWindowLearningGroupSelection.Value) + 1;

      updateImage(true);
    end
  end
end

%--------------------------------------------------------------------------
function wheelFcn(hObject, eventData)
  currObj = gco;
  % If we are on the logPanel, do nothing
  if(isa(currObj, 'matlab.ui.control.UIControl'))
    if(strcmpi(currObj.Tag, 'logPanel'))
      return;
    end
  end
  % Else, move through the traces!
  if(eventData.VerticalScrollCount > 0)
    previousTracesButton(hObject, eventData, abs(eventData.VerticalScrollCount));
  elseif(eventData.VerticalScrollCount < 0)
    nextTracesButton(hObject, eventData, abs(eventData.VerticalScrollCount));
  end

%   currPoint = get(hs.mainWindow, 'CurrentPoint');
%   logPos = hs.logPanel.Position;
%   if(currPoint(1) >= logPos(1) && currPoint(1) <= logPos(1)+logPos(3) && currPoint(2) >= logPos(2) && currPoint(2) <= logPos(2)+logPos(4))
%     %currPoint
%   end
end

%--------------------------------------------------------------------------
function learningGroupChange(~, ~, ~)
  updateImage(true);
end

%--------------------------------------------------------------------------
function eventLengthChange(hObject, ~)
  experiment.learningEventOptionsCurrent.samplingSize = str2double(hObject.String);
end

%--------------------------------------------------------------------------
function eventMinSizeChange(hObject, ~)
  experiment.learningEventOptionsCurrent.minEventSize = str2double(hObject.String);
end

%--------------------------------------------------------------------------
function eventThresholdChange(hObject, ~)
  experiment.learningEventOptionsCurrent.eventLearningThreshold = str2double(hObject.String);
end

%--------------------------------------------------------------------------
function eventCountClassifier(~, ~)
  [success, ~, experiment] = preloadOptions(experiment, patternCountClassifierOptions, gui, true, false);
  if(success)
    experiment = patternCountClassification(experiment, experiment.patternCountClassifierOptionsCurrent);
    setappdata(hFigW, 'experiment', experiment);
    hs.menu.traces.selection = redoSelectionMenu(experiment, hs.menu.traces);
    updateMenu();  
  end
end

%--------------------------------------------------------------------------
function training(~, ~, type)
  if(strcmp(learningMode, 'trace'))
    learningMode = 'none';
    h.Label = cmapStandard;
    changeColormap(h);
    updateButtons();
    updateImage();
  end
  logMsgHeader('Starting training and classification', 'start');
  switch type % Using a new internal classifier
    case {'internal'}
      if(all(isnan(experiment.learningGroup)))
        logMsg('There are no samples to train with. Run learning first', 'e');
        return;
      end

      % Consistency checks
      if(~isfield(experiment, 'features'))
        logMsg('No features found. Run them in Population Analysis menu', 'e');
        return;
      else
        if(size(experiment.features,1) ~= length(experiment.ROI))
          logMsg('Number of features elements and ROI does not match', 'e');
          return;
        end
      end

      ncbar.automatic('Training...');
      trainingGroups = length(experiment.traceGroupsNames.classifier);
      trainingTraces = cell(trainingGroups, 1);
      for i = 1:numel(trainingTraces)
        trainingTraces{i} = find(experiment.learningGroup == i)';
      end

      % Create the response vector
      response = [];
      trainingTracesVector = [];
      for i = 1:length(trainingTraces)
        response = [response, i*ones(1,length(trainingTraces{i}))];
        trainingTracesVector = [trainingTracesVector, trainingTraces{i}];
       end
      trainingTraces = trainingTracesVector;

      % Training phase - no need to save the classifier
      %if(length(unique(response)) == 2)
      %  classifier = fitensemble(experiment.features(trainingTraces, :), response, 'RobustBoost', learningOptionsCurrent.numberTrees, 'Tree');
      %else
      newFeatures = getFeatures(experiment.learningOptionsCurrent.featureType);
      classifier = fitensemble(newFeatures(trainingTraces, :), response, experiment.learningOptionsCurrent.trainer, experiment.learningOptionsCurrent.numberTrees, 'Tree');
      %end

      % Prediction phase
      classificationGroups = predict(classifier, newFeatures);
      % Check what happened with the trainingTraces
      mismatch = length(response)-sum(classificationGroups(trainingTraces) == response');
      if(mismatch > 0)
        logMsg(sprintf('%d training traces were not assigned to their group. Fixing...', mismatch));
        classificationGroups(trainingTraces) = response;
      end
    case 'event'
      experiment = loadTraces(experiment, 'validPatterns');
      [patterns, basePatternList] = generatePatternList(experiment);
      experiment.traceGroupsNames.classifier = experiment.learningOptionsCurrent.groupNames;
      countList = zeros(size(selectedTraces, 2), length(basePatternList)*3);
      for it = 1:size(selectedTraces, 2)
        if(isempty(experiment.validPatterns{it}))
          continue;
        end
        patternList = cellfun(@(x)x.basePattern, experiment.validPatterns{it}, 'UniformOutput', false);
        coeffList = cellfun(@(x)x.coeff, experiment.validPatterns{it}, 'UniformOutput', false);
        coeffList = cell2mat(coeffList);
        count = zeros(length(basePatternList), 1);
        avgCorr = zeros(length(basePatternList), 1);
        stdCorr = zeros(length(basePatternList), 1);
        for it2 = 1:length(basePatternList)
          valid = find(strcmp(patternList, basePatternList{it2}));
          count(it2) = length(valid);
          avgCorr(it2) = nanmean(coeffList(valid));
          stdCorr(it2) = nanstd(coeffList(valid));
        end
        countList(it, 1:length(basePatternList)) = count;
        countList(it, (length(basePatternList)+1):(2*length(basePatternList))) = avgCorr;
        countList(it, (2*length(basePatternList)+1):end) = stdCorr;
      end
     
      if(all(isnan(experiment.learningGroup)))
        logMsg('There are no samples to train with. Run learning first', 'e');
        return;
      end

      ncbar.automatic('Training...');
      trainingGroups = length(experiment.traceGroupsNames.classifier);
      trainingTraces = cell(trainingGroups, 1);
      for i = 1:trainingGroups
        trainingTraces{i} = find(experiment.learningGroup == i)';
      end

      % Create the response vector
      response = [];
      trainingTracesVector = [];
      for i = 1:trainingGroups
        response = [response, i*ones(1,length(trainingTraces{i}))];
        trainingTracesVector = [trainingTracesVector, trainingTraces{i}];
       end
      trainingTraces = trainingTracesVector;

      % Training phase - no need to save the classifier
      %if(length(unique(response)) == 2)
      %  classifier = fitensemble(experiment.features(trainingTraces, :), response, 'RobustBoost', learningOptionsCurrent.numberTrees, 'Tree');
      %else
      newFeatures = countList;
      newFeatures(isnan(newFeatures)) = 0;
       % Z-norm features
      for i = 1:size(newFeatures,2)
        newFeatures(:, i) = (newFeatures(:, i)-nanmean(newFeatures(:, i)))/nanstd(newFeatures(:,i));
      end
      classifier = fitensemble(newFeatures(trainingTraces, :), response, experiment.learningOptionsCurrent.trainer, experiment.learningOptionsCurrent.numberTrees, 'Tree');
      %end

      % Prediction phase
      classificationGroups = predict(classifier, newFeatures);
      % Check what happened with the trainingTraces
      mismatch = length(response)-sum(classificationGroups(trainingTraces) == response');
      if(mismatch > 0)
        logMsg(sprintf('%d training traces were not assigned to their group. Fixing...', mismatch));
        classificationGroups(trainingTraces) = response;
      end
    case 'external' % Using an external classifier - I decided not to store the classifier because there were some issues when saving the MAT files
      [selection, ok] = listdlg('PromptString', 'Select experiment to train from', 'ListString', namesWithLabels(), 'SelectionMode', 'multiple');
      if(~ok)
        return;
      end
      fullFeatureList = [];
      fullTrainingTraces = [];
      fullResponse = [];
      ncbar.automatic('Training...');
      for it = 1:length(selection)
        experimentFile = [project.folderFiles project.experiments{selection(it)} '.exp'];
        externalExperiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
        externalExperiment = checkGroups(externalExperiment);
        if(all(isnan(externalExperiment.learningGroup)))
          logMsg('There are no samples to train with in the other experiment. Run learning first', 'e');
          return;
        end
        % Consistency checks
        if(~isfield(experiment, 'features'))
          logMsg('No features found. Run them in Population Analysis menu', 'e');
          ncbar.close();
          return;
        end
        if(~isfield(externalExperiment, 'features'))
          logMsg('No features found in the external experiment. Run them in Population Analysis menu', 'e');
          ncbar.close();
          return;
        end
        if(size(experiment.features, 2) ~= size(externalExperiment.features, 2))
          logMsg('Number of features differs between the two experiments','e');
        end
        
        trainingGroups = length(externalExperiment.traceGroupsNames.classifier);
        trainingTraces = cell(trainingGroups, 1);
        for i = 1:numel(trainingTraces)
          trainingTraces{i} = find(externalExperiment.learningGroup == i)';
        end
        % Create the response vector
        response = [];
        trainingTracesVector = [];
        for i = 1:length(trainingTraces)
          response = [response, i*ones(1,length(trainingTraces{i}))];
          trainingTracesVector = [trainingTracesVector, trainingTraces{i}];
         end
        trainingTraces = trainingTracesVector;
        % Now concatenate
        fullFeatureList = [fullFeatureList; externalExperiment.features];
        fullTrainingTraces = [fullTrainingTraces; trainingTraces(:)];
        fullResponse = [fullResponse, response];
      end
      experiment.traceGroupsNames.classifier = externalExperiment.traceGroupsNames.classifier;
      % Training phase - no need to save the classifier
      %if(length(unique(response)) == 2)
      %  classifier = fitensemble(fullFeatureList(fullTrainingTraces, :), fullResponse, 'RobustBoost', learningOptionsCurrent.numberTrees, 'Tree');
      %else
        classifier = fitensemble(fullFeatureList(fullTrainingTraces, :), fullResponse, experiment.learningOptionsCurrent.trainer, experiment.learningOptionsCurrent.numberTrees, 'Tree');
      %end
      % Prediction phase
      classificationGroups = predict(classifier, experiment.features);
  end
    experiment.traceGroups.classifier = cell(trainingGroups, 1);
    for i = 1:trainingGroups
        experiment.traceGroups.classifier{i} = find(classificationGroups == i);
        experiment.traceGroupsOrder.ROI.classifier{i} = find(classificationGroups == i);
    end
    for i = 1:trainingGroups
        logMsg(sprintf('%d traces belong to population %s', length(experiment.traceGroups.classifier{i}), experiment.traceGroupsNames.classifier{i}));
    end
    
    % Now the similarity stuff
    logMsg(sprintf('Obtaining similarities'));
    experiment.traceGroupsOrder.similarity.classifier = cell(trainingGroups, 1);
    for i = 1:trainingGroups
        if(~isempty(experiment.traceGroups.classifier{i}))
          try
            [~, order, ~] = identifySimilaritiesInTraces(...
              experiment, experiment.traces(:, experiment.traceGroups.classifier{i}), ...
              'showSimilarityMatrix', false, ...
              'similarityMatrixTag', ...
              ['_traceSimilarity_' experiment.traceGroupsNames.classifier{i}], 'verbose', false, 'pbar', 1);
            experiment.traceGroupsOrder.similarity.classifier{i} = experiment.traceGroups.classifier{i}(order);
          catch ME
            logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
          end
        end
    end
    logMsgHeader('Training and classification completed', 'finish');
    ncbar.close();
    setappdata(hFigW, 'experiment', experiment);
    hs.menu.traces.selection = redoSelectionMenu(experiment, hs.menu.traces);
    updateMenu();
    
end

%--------------------------------------------------------------------------
function fuzzyClassification(~, ~)
  [success, fuzzyOptionsCurrent] = preloadOptions(experiment, fuzzyOptions, gui, true, false);
  if(~success)
    return;
  end
  logMsgHeader('Starting fuzzy classification', 'finish');
  ncbar.automatic('Fuzzy classification...');
  experiment.fuzzyOptionsCurrent = fuzzyOptionsCurrent;
  trainingGroups = experiment.fuzzyOptionsCurrent.numberGroups;
  % The actual fuzzy classification
  switch experiment.fuzzyOptionsCurrent.featureType 
    case 'fluorescence'
      data = experiment.features;
      data(isnan(data))=0;
    case 'simplifiedPatterns'
      [patterns, basePatternList] = generatePatternList(experiment);
      experiment = loadTraces(experiment, 'validPatterns');
      countList = zeros(size(selectedTraces, 2), length(basePatternList));
      for it = 1:size(selectedTraces, 2)
        if(isempty(experiment.validPatterns{it}))
          continue;
        end
        patternList = cellfun(@(x)x.basePattern, experiment.validPatterns{it}, 'UniformOutput', false);

        count = zeros(length(basePatternList), 1);
        for it2 = 1:length(basePatternList)
          count(it2) = sum(strcmp(patternList, basePatternList{it2}));
        end
        countList(it, :) = count;
      end
    data = countList;
    case 'fullPatterns'
     [patterns, basePatternList] = generatePatternList(experiment);

      countList = zeros(size(selectedTraces, 2), length(patterns));
      for it = 1:size(selectedTraces, 2)
        if(isempty(experiment.validPatterns{it}))
          continue;
        end
        patternList = cellfun(@(x)x.pattern, experiment.validPatterns{it}, 'UniformOutput', false);
        patternList = cell2mat(patternList);
        count = zeros(length(patterns), 1);
        for it2 = 1:length(patterns)
          count(it2) = sum(patternList == it2);
        end
        countList(it, :) = count;
      end
    data = countList; 
  end

  [centers,U] = fcm(data, trainingGroups);
  if(ischar(experiment.fuzzyOptionsCurrent.fuzzyThreshold) && strcmpi(experiment.fuzzyOptionsCurrent.fuzzyThreshold, 'max'))
    [~,clusterIdx] = max(U);
    classificationGroups = clusterIdx;
  elseif(isnumeric(experiment.fuzzyOptionsCurrent.fuzzyThreshold))
    [maxU,clusterIdx] = max(U);
    valid = find(maxU >= experiment.fuzzyOptionsCurrent.fuzzyThreshold);
    % Generate 1 more cluster than defined
    classificationGroups = ones(1, size(U,2))*(trainingGroups+1);
    % Set the members above threshold to the correct cluster idx
    classificationGroups(valid) = clusterIdx(valid);
  else
    logMsg('Invalid fuzzy threshold,' ,'e');
    return;
  end
  % Plot
  switch experiment.fuzzyOptionsCurrent.numberGroups
    case 2
      hf = figure;
      scatter(U(1, :), U(2, :), 32, classificationGroups, 'o');
      xlabel('Cluster 1 fuzzy score');
      ylabel('Cluster 2 fuzzy score');
    case 3
      hf = figure;
      scatter3(U(1, :), U(2, :), U(3, :), 32, classificationGroups, 'o');
      xlabel('Cluster 1 fuzzy score');
      ylabel('Cluster 2 fuzzy score');
      zlabel('Cluster 3 fuzzy score');
  end
  
  % Now create the new groups
  for i = 1:(trainingGroups+1)
    if(i <= trainingGroups)
      experiment.traceGroupsNames.classifier{i} = num2str(i);
    else
      experiment.traceGroupsNames.classifier{i} = 'unclassified';
    end
    experiment.traceGroups.classifier{i} = find(classificationGroups == i);
    experiment.traceGroupsOrder.ROI.classifier{i} = find(classificationGroups == i);
  end
  for i = 1:(trainingGroups+1)
    logMsg(sprintf('%d traces belong to population %s', length(experiment.traceGroups.classifier{i}), experiment.traceGroupsNames.classifier{i}));
  end
    
  % Now the similarity stuff
  logMsg(sprintf('Obtaining similarities'));
  experiment.traceGroupsOrder.similarity.classifier = cell(trainingGroups+1, 1);
  for i = 1:(trainingGroups+1)
    if(~isempty(experiment.traceGroups.classifier{i}))
      [~, order, ~] = identifySimilaritiesInTraces(...
        experiment, experiment.traces(:, experiment.traceGroups.classifier{i}), ...
        'showSimilarityMatrix', false, ...
        'similarityMatrixTag', ...
        ['_traceSimilarity_' experiment.traceGroupsNames.classifier{i}], 'verbose', false);
      experiment.traceGroupsOrder.similarity.classifier{i} = experiment.traceGroups.classifier{i}(order);
    end
  end
  logMsgHeader('Fuzzy classification completed', 'finish');
  ncbar.close();
  setappdata(hFigW, 'experiment', experiment);
  figure(hFigW);
  hs.menu.traces.selection = redoSelectionMenu(experiment, hs.menu.traces);
  updateMenu();
 
end

%--------------------------------------------------------------------------
function learningEventStart(~, ~, ~)
  % Make a check on what already exists
  basePatternList = {};
  if(isfield(experiment, 'learningEventListPerTrace'))
    for it1 = 1:length(experiment.learningEventListPerTrace)
      for it2 = 1:length(experiment.learningEventListPerTrace{it1})
        basePatternList{end+1} = experiment.learningEventListPerTrace{it1}{it2}.basePattern;
      end
    end
    [basePatternList, ia, ic] = unique(basePatternList);
    [hits, ~] = hist(ic, 1:length(basePatternList));
    experiment.learningEventGroupCount = hits;
    if(~isempty(basePatternList))
      experiment.learningEventOptionsCurrent.groupNames = basePatternList';
    end
  end
  [success, ~, experiment] = preloadOptions(experiment, learningEventOptions, gui, true, false);
  
  if(success)
    basePatternList = experiment.learningEventOptionsCurrent.groupNames;
    hs.eventButtonLengthEdit.String = num2str(experiment.learningEventOptionsCurrent.samplingSize);
    hs.eventButtonSizeEdit.String = num2str(experiment.learningEventOptionsCurrent.minEventSize);
    hs.eventButtonThresholdEdit.String = num2str(experiment.learningEventOptionsCurrent.eventLearningThreshold);
    if(length(experiment.learningEventOptionsCurrent.groupNames) == 1)
      experiment.learningEventOptionsCurrent.groupNames = strsplit(experiment.learningEventOptionsCurrent.groupNames{1},' ');
    end
    experiment.trainingEventGroupNames = experiment.learningEventOptionsCurrent.groupNames;
    experiment.trainingEventGroups = length(experiment.trainingEventGroupNames);
    if(~isfield(experiment, 'learningEventListPerTrace'))
        experiment.learningEventListPerTrace = cell(size(selectedTraces,2), 1);
    end
    if(~isfield(experiment, 'learningEventGroupCount'))
        experiment.learningEventGroupCount = zeros(experiment.trainingEventGroups, 1);
    end
    if(length(experiment.learningEventOptionsCurrent.groupNames) > length(experiment.learningEventGroupCount))
      experiment.learningEventGroupCount(length(experiment.learningEventOptionsCurrent.groupNames)) = 0;
    end
    setappdata(gui, 'learningEventOptionsCurrent', experiment.learningEventOptionsCurrent);
    learningMode = 'event';
    hs.mainWindowLearningGroupSelection.Value = 1;
    h.Label = 'hsv';
    changeColormap(h, [], [], false);
    cmap = zeros(size(cmap));
    N = length(basePatternList);
    cmapLearning = eval([cmapName '(N+1)']);
    updateButtons();
    updateImage();
    updateMenu();
  end
end

%--------------------------------------------------------------------------
function menuViewPatterns(~, ~)
  [~, experiment] = viewPatterns(experiment);
end

%--------------------------------------------------------------------------
function trainingEvent(~, ~, ~)
    corrThreshold = 0.9;
    
    if(strcmp(learningMode, 'event'))
        learningMode = 'none';
        h.Label = cmapStandard;
        changeColormap(h);
        updateButtons();
        updateImage();
    end
    
    logMsgHeader('Starting event based training and classification', 'start');
    
    if(sum(experiment.learningEventGroupCount) == 0)
        logMsg('There are no samples to train with. Run learning first', 'e');
        return;
    end
    
    % Get all the events together
    fullEventList = cell(experiment.trainingEventGroups, 1);
    for g = 1:experiment.trainingEventGroups
        fullEventList{g} = cell(experiment.learningEventGroupCount(g), 1);
        currentEvent = 0;
        % Iterate through all events
        for i = 1:size(selectedTraces, 2)
            if(~isempty(experiment.learningEventListPerTrace{i}))
                eventList = experiment.learningEventListPerTrace{i};
                for j = 1:length(eventList)
                    % If its the correct group
                    if(eventList{j}.group == g)
                        currentEvent = currentEvent + 1;
                        fullEventList{g}{currentEvent} = eventList{j}.y; % Only care about the fluorescence values
                    end
                end
            end
        end
    end
    % Start checking events 1 by 1
    eventHitList = cell(size(traces, 2), length(fullEventList{g}), length(fullEventList));
    for g = 1:length(fullEventList)
        for j = 1:size(traces, 2)
            for i = 1:length(fullEventList{g})
                eventTrace = fullEventList{g}{i};
                eventSize = size(eventTrace, 1);
                simRes = zeros(size(traces, 1), 1);
                for k = 1:(size(traces,1)-size(eventTrace,1))
                    R = corrcoef(traces(k:k+size(eventTrace,1)-1, j), eventTrace);
                    simRes(k) = R(1,2);
                end
                validPoints = find(simRes > corrThreshold);
                if(~isempty(validPoints))
                    %validValid = find(diff(validPoints) > experiment.fps); % Also store the raw correlation value
                    out = SplitVec(validPoints, 'consecutive');
                    eventOnsetList = zeros(size(out));
                    eventCorrList = zeros(size(out));
                    for k = 1:length(out)
                        [maxCorr, maxCorrPoint] = max(simRes(out{k}(:)));
                        eventOnsetList(k) = out{k}(maxCorrPoint);
                        eventCorrList(k) = maxCorr;
                    end
                    eventHitList{j, i, g} = [eventOnsetList, eventOnsetList+eventSize-1, eventCorrList];
                end
                %[i j length(validPoints)]
            end

            figure;
            plot(traces(:, j), 'k-');
            hold on;
            for i = 1:length(fullEventList{g})
                events = eventHitList{j, i, g};
                for z = 1:size(events,1)
                    plot(eventHitList{j, i, g}(z, 1):eventHitList{j, i, g}(z, 2), traces(eventHitList{j, i, g}(z, 1):eventHitList{j, i, g}(z, 2), j), '-');
                end
            end
        end
    end
    logMsgHeader('Done', 'finish');
    
end


%--------------------------------------------------------------------------
function viewPositionsOnScreen(~, ~, ~)
  currentOrder = getappdata(hFigW, 'currentOrder');
  pos = hs.mainWindow.Position;
  ratio = experiment.width/experiment.height;
  hs.onScreenSelectionWindow = figure('Visible','on',...
                     'Resize','on',...
                     'Toolbar', 'figure',...
                     'Tag','viewTraces', ...
                     'DockControls','off',...
                     'NumberTitle', 'off',...
                     'MenuBar', 'none',...
                     'Name', 'Current selection positions',...
                     'Position', [pos(1)+pos(3)+1 pos(2) 600 600/ratio]);
  hs.onScreenSelectionWindow.Position = setFigurePosition(gcbf, 'width', 600, 'height', 600/ratio);
  superBox = uix.VBox('Parent', hs.onScreenSelectionWindow);
  figPanel = uix.Panel('Parent', superBox, 'Padding', 5, 'BorderType', 'none');
  h = axes('Parent', uicontainer('Parent', figPanel));
  lowerPanel = uix.Panel('Parent', superBox, 'Padding', 5, 'BorderType', 'none');
  lowerPanelSlider  = uicontrol('Style', 'slider', 'Parent', lowerPanel,...
                                     'Min', 0, 'Max', 1, 'Value', 0.5, ...
                                     'SliderStep', [0.01 0.1], 'Callback', @sliderChange);
  addlistener(lowerPanelSlider, 'Value' , 'PostSet', @sliderChange);

  set(superBox, 'Heights', [-1 30], 'Padding', 0, 'Spacing', 0);

  cleanMenu(hs.onScreenSelectionWindow);
  a = findall(hs.onScreenSelectionWindow);
  b = findall(a, 'ToolTipString', 'Data Cursor');
  set(b,'Visible','on');
  
  figure(hs.onScreenSelectionWindow);
  %h = axes('Parent', figPanel);
  currFrame = experiment.avgImg;
  %me = mean(double(currFrame(:)));
  %se = std(double(currFrame(:)));
  imagesc(currFrame);
  axis equal tight;
  set(h, 'XTick', []);
  set(h, 'YTick', []);
  set(h, 'LooseInset', [0,0,0,0]);
  box on;

  [minIntensity, maxIntensity] = autoLevelsFIJI(currFrame, experiment.bpp, true);

  caxis([minIntensity/1.1 maxIntensity]);
  colormap(gray(256));

  hold on;

  ROI = experiment.ROI(currentOrder(firstTrace:lastTrace));
  hs.onScreenSelectionWindowData = imagesc(ones(size(currFrame)));
  ROIimg = visualizeROI(zeros(size(experiment.avgImg)), ROI, 'plot', false, 'color', true, 'mode','full', 'cmap', cmap);

  invalid = (ROIimg(:,:,1) == 0 & ROIimg(:,:,2) == 0 & ROIimg(:,:,3) == 0);

  alpha = ones(size(ROIimg,1), size(ROIimg,2));
  alpha(invalid) = 0;

  set(hs.onScreenSelectionWindowData, 'CData', ROIimg);
  set(hs.onScreenSelectionWindowData, 'AlphaData', alpha);

  dcm_obj = datacursormode(hs.onScreenSelectionWindow);
  set(dcm_obj,'UpdateFcn', @cursorText)
  setappdata(hs.onScreenSelectionWindow, 'ROI', ROI);
  
  hold off;
  function sliderChange(~, ~)
    opacityLevel = lowerPanelSlider.Value;
    % Completely arbitrary function - but looks good enough
    if(opacityLevel > 0.5)
      % Touch max at fixed min
      %caxis(h, [minIntensity, 0.0001+max(minIntensity,maxIntensity+2*(0.5-opacityLevel)*(maxIntensity-minIntensity))]);
      caxis(h, [minIntensity, maxIntensity]*(1*(opacityLevel+0.5))^3);
    else
      %caxis(h, [min(maxIntensity,minIntensity-2*(opacityLevel-0.5)*(maxIntensity-minIntensity))-0.0001, maxIntensity]);
      caxis(h, [minIntensity, maxIntensity]*(1*(opacityLevel+0.5))^3);
      % Touch min at fixed max
    end
    
    %[max(minIntensity,min(maxIntensity,minIntensity+(1-opacityLevel)*(maxIntensity-minIntensity))), maxIntensity]
    %caxis(h, [max(minIntensity,min(maxIntensity,minIntensity+(1-opacityLevel)*(maxIntensity-minIntensity))), maxIntensity]);
        %caxis(h, [minIntensity, maxIntensity]*(1-opacityLevel));
  end
  
  
end

%--------------------------------------------------------------------------
function viewPositionsOnScreenMovie(~, ~)
  %%% Preinitialize the video
  [fID, experiment] = openVideoStream(experiment);
  currFrame = getFrame(experiment, 1, fID);
  
  currentOrder = getappdata(hFigW, 'currentOrder');
  pos = hs.mainWindow.Position;
  ratio = experiment.width/experiment.height;
  hs.onScreenSelectionMovieWindow = figure('Visible','on',...
                     'Resize','on',...
                     'Toolbar', 'figure',...
                     'Tag','viewTraces', ...
                     'DockControls','off',...
                     'NumberTitle', 'off',...
                     'MenuBar', 'none',...
                     'Name', 'Current selection positions',...
                     'CloseRequestFcn', @closeCallback, ...
                     'KeyPressFcn', @KeyPress, ...
                     'Position', [pos(1)+pos(3)+1 pos(2) 600 600/ratio]);
  hs.onScreenSelectionMovieWindow.Position = setFigurePosition(gcbf, 'width', 600, 'height', 600/ratio);
  superBox = uix.VBox('Parent', hs.onScreenSelectionMovieWindow);
  figPanel = uix.Panel('Parent', superBox, 'Padding', 5, 'BorderType', 'none');
  h = axes('Parent', uicontainer('Parent', figPanel));
  lowerPanel = uix.Panel('Parent', superBox, 'Padding', 5, 'BorderType', 'none');
  lowerPanelSlider  = uicontrol('Style', 'slider', 'Parent', lowerPanel,...
                                     'Min', 0, 'Max', 1, 'Value', 0.5, ...
                                     'SliderStep', [0.01 0.1], 'Callback', @sliderChange);
  lowerPanelMovie = uix.Panel('Parent', superBox, 'Padding', 5, 'BorderType', 'none');
  lowerPanelMovieSlider  = uicontrol('Style', 'slider', 'Parent', lowerPanelMovie,...
                                     'Min', 1, 'Max', experiment.numFrames, 'Value', 1, ...
                                     'SliderStep', [1 100]/(experiment.numFrames-1), 'Callback', @sliderChange);

  addlistener(lowerPanelSlider, 'Value' , 'PostSet', @sliderChange);
  addlistener(lowerPanelMovieSlider, 'Value' , 'PostSet', @sliderMovieChange);

  set(superBox, 'Heights', [-1 30 30], 'Padding', 0, 'Spacing', 0);

  cleanMenu(hs.onScreenSelectionMovieWindow);
  a = findall(hs.onScreenSelectionMovieWindow);
  b = findall(a, 'ToolTipString', 'Data Cursor');
  set(b,'Visible','on');
  
  figure(hs.onScreenSelectionMovieWindow);
  imData = imagesc(currFrame);
  axis equal tight;
  set(h, 'XTick', []);
  set(h, 'YTick', []);
  set(h, 'LooseInset', [0,0,0,0]);
  box on;

  [minIntensity, maxIntensity] = autoLevelsFIJI(currFrame, experiment.bpp, true);

  caxis([minIntensity/1.1 maxIntensity]);
  colormap(gray(256));

  hold on;

  ROI = experiment.ROI(currentOrder(firstTrace:lastTrace));
  hs.onScreenSelectionMovieWindowData = imagesc(ones(size(currFrame)), 'HitTest', 'on');
  
  ROIimg = visualizeROI(zeros(size(experiment.avgImg)), ROI, 'plot', false, 'color', true, 'mode','edgeHard', 'cmap', cmap);

  invalid = (ROIimg(:,:,1) == 0 & ROIimg(:,:,2) == 0 & ROIimg(:,:,3) == 0);

  alpha = ones(size(ROIimg,1), size(ROIimg,2));
  alpha(invalid) = 0;

  set(hs.onScreenSelectionMovieWindowData, 'CData', ROIimg);
  set(hs.onScreenSelectionMovieWindowData, 'AlphaData', alpha);

  dcm_obj = datacursormode(hs.onScreenSelectionMovieWindow);
  set(dcm_obj,'UpdateFcn', @cursorText);
  setappdata(hs.onScreenSelectionMovieWindow, 'ROI', ROI);
  setappdata(hs.onScreenSelectionMovieWindow, 't', lowerPanelMovieSlider.Value);
  hold off;
  
  hs.onScreenSelectionMenu.root = uicontextmenu;
  hs.onScreenSelectionMenu.sortROI = uimenu(hs.onScreenSelectionMenu.root, 'Label','Sort ROI by distance', 'Callback', @rightClickMovie);
  %h.UIContextMenu = hs.onScreenSelectionMenu.root;
  hs.onScreenSelectionMovieWindowData.UIContextMenu = hs.onScreenSelectionMenu.root;
  
  %------------------------------------------------------------------------
  function updateMovieImage()
    ROI = getappdata(hs.onScreenSelectionMovieWindow, 'ROI');
    ROIimg = visualizeROI(zeros(size(experiment.avgImg)), ROI, 'plot', false, 'color', true, 'mode','edgeHard', 'cmap', cmap);

    set(imData, 'CData', currFrame);
    invalid = (ROIimg(:,:,1) == 0 & ROIimg(:,:,2) == 0 & ROIimg(:,:,3) == 0);

    alpha = ones(size(ROIimg,1), size(ROIimg,2));
    alpha(invalid) = 0;

    set(hs.onScreenSelectionMovieWindowData, 'CData', ROIimg);
    set(hs.onScreenSelectionMovieWindowData, 'AlphaData', alpha);

    dcm_obj = datacursormode(hs.onScreenSelectionMovieWindow);
    set(dcm_obj,'UpdateFcn', @cursorText)
    setappdata(hs.onScreenSelectionMovieWindow, 't', lowerPanelMovieSlider.Value);
  end
  
  %------------------------------------------------------------------------
  function rightClickMovie(hObject, ~)
    ax = findall(hObject, 'Type', 'Axes');
    currentOrder = getappdata(hFigW, 'currentOrder');
    clickedPoint = get(h,'currentpoint');
    xy = clickedPoint([1,3]);
    dist = cellfun(@(x)(sum((x.center-xy).^2)), experiment.ROI(currentOrder));
    [~, newOrder] = sort(dist);
    currentOrder = currentOrder(newOrder);
    setappdata(hFigW, 'currentOrder', currentOrder);
    pageChange(1);
%     dist = zeros(size(currentOrder));
%     for it = 1:length(currentOrder)
%       ROIxy = experiment.ROI{currentOrder(it)}.center;
%       dist(it) = sum((ROIxy-xy).^2);
%     end
      %hFigW
      
    resizeHandle = getappdata(hFigW, 'ResizeHandle');
    if(isa(resizeHandle,'function_handle'))
      resizeHandle([], []);
    end
  end
  
  %------------------------------------------------------------------------
  function closeCallback(~, ~)
    if(~isempty(fID))
      try
        closeVideoStream(fID);
      catch ME
        logMsg(ME.message, 'e');
      end
    end

    delete(hs.onScreenSelectionMovieWindow);
  end
  
  %------------------------------------------------------------------------
  function sliderChange(~, ~)
    opacityLevel = lowerPanelSlider.Value;
    % Completely arbitrary function - but looks good enough
    if(opacityLevel > 0.5)
      % Touch max at fixed min
      caxis(h, [minIntensity, maxIntensity]*(1*(opacityLevel+0.5))^3);
    else
      % Touch min at fixed max
      caxis(h, [minIntensity, maxIntensity]*(1*(opacityLevel+0.5))^3);
    end
  end
  
  %------------------------------------------------------------------------
  function KeyPress(~, eventData)
    switch eventData.Key
      case {'rightarrow', 'd'}
        lowerPanelMovieSlider.Value = lowerPanelMovieSlider.Value + 1;
        sliderMovieChange([],[]);
      case {'leftarrow', 'a'}
        lowerPanelMovieSlider.Value = lowerPanelMovieSlider.Value - 1;
        sliderMovieChange([],[]);
      case {'uparrow', 'w'}
        lowerPanelMovieSlider.Value = lowerPanelMovieSlider.Value + 10;
        sliderMovieChange([],[]);
      case {'downarrow', 's'}
        lowerPanelMovieSlider.Value = lowerPanelMovieSlider.Value - 10;
        sliderMovieChange([],[]);
    end
  end

  %------------------------------------------------------------------------
  function sliderMovieChange(~, ~)
    if(lowerPanelMovieSlider.Value < 1)
      lowerPanelMovieSlider.Value = 1;
    elseif(lowerPanelMovieSlider.Value > experiment.numFrames)
      lowerPanelMovieSlider.Value = experiment.numFrames;
    end
    lowerPanelMovieSlider.Value = round(lowerPanelMovieSlider.Value);
    currFrame = getFrame(experiment, lowerPanelMovieSlider.Value, fID);
    updateMovieImage();
    %
    if(~isempty(movieLineH) && ishandle(movieLineH))
      delete(movieLineH);
    end
    yl = ylim(hs.mainWindowFramesAxes);
    frameT = lowerPanelMovieSlider.Value;
    movieLineH = plot(hs.mainWindowFramesAxes, [1 1]*frameT/experiment.fps, yl, 'k--');
    
    opacityLevel = lowerPanelSlider.Value;
    % Completely arbitrary function - but looks good enough
    if(opacityLevel > 0.5)
      % Touch max at fixed min
      caxis(h, [minIntensity, maxIntensity]*(1*(opacityLevel+0.5))^3);
    else
      caxis(h, [minIntensity, maxIntensity]*(1*(opacityLevel+0.5))^3);
      % Touch min at fixed max
    end
  end
end
%--------------------------------------------------------------------------
function txt = cursorText(~, event_obj)
  
  hf = ancestor(event_obj.Target, 'figure');
  ROI = getappdata(hf, 'ROI');
  
  
  pos = get(event_obj,'Position');
  currPixel = sub2ind([experiment.height, experiment.width], pos(2), pos(1));
  currROI =[];
  for it = 1:length(ROI)
    if(any(ROI{it}.pixels == currPixel))
      currROI = num2str(ROI{it}.ID);
      break;
    end
  end
  if(isempty(currROI))
    txt = {['[X, Y]: [' num2str(pos(1)) ' ' num2str(pos(2)) ']']};
  else
    txt = {['[X, Y]: [' num2str(pos(1)) ' ' num2str(pos(2)) ']'];...
          ['ROI: ' currROI]};
  end
end

%--------------------------------------------------------------------------
function viewPositionsWholeSelection(~, ~, ~)
  currentOrder = getappdata(hFigW, 'currentOrder');
  pos = hs.mainWindow.Position;
  ratio = experiment.width/experiment.height;
  hs.wholeScreenSelectionWindow = figure('Visible','on',...
                     'Resize','on',...
                     'Toolbar', 'figure',...
                     'Tag','viewTraces', ...
                     'DockControls','off',...
                     'NumberTitle', 'off',...
                     'MenuBar', 'none',...
                     'Name', 'Whole selection positions',...
                     'Position', [pos(1)+pos(3)+1 pos(2) 600 600/ratio]);
  hs.wholeScreenSelectionWindow.Position = setFigurePosition(gcbf, 'width', 600, 'height', 600/ratio);
  cleanMenu(hs.wholeScreenSelectionWindow);
  figure(hs.wholeScreenSelectionWindow);
  h = axes;
  currFrame = experiment.avgImg;
  imagesc(currFrame);
  axis equal tight;
  set(h, 'XTick', []);
  set(h, 'YTick', []);
  set(h, 'LooseInset', [0,0,0,0]);
  box on;

  [minIntensity, maxIntensity] = autoLevelsFIJI(currFrame, experiment.bpp);

  caxis([minIntensity/1.1 maxIntensity]);
  colormap(gray(256));

  hold on;

  ROI = experiment.ROI(currentOrder(:));
  hs.wholeScreenSelectionWindowData = imagesc(ones(size(currFrame)));
  ccmap = eval([cmapName '(length(ROI)+1)']);
  ncbar.automatic('Please wait...');
  ROIimg = visualizeROI(zeros(size(experiment.avgImg)), ROI, 'plot', false, 'color', true, 'mode','full', 'cmap', ccmap);
  ncbar.close();
  invalid = (ROIimg(:,:,1) == 0 & ROIimg(:,:,2) == 0 & ROIimg(:,:,3) == 0);

  alpha = ones(size(ROIimg,1), size(ROIimg,2));
  alpha(invalid) = 0;

  set(hs.wholeScreenSelectionWindowData, 'CData', ROIimg);
  set(hs.wholeScreenSelectionWindowData, 'AlphaData', alpha);
  hold off;
end

%--------------------------------------------------------------------------
function menuViewAverageTraceGlobal(~, ~)
  currentOrder = getappdata(hFigW, 'currentOrder');
  hfig = figure;
  plot(selectedT, mean(selectedTraces(:, currentOrder),2));
  xlabel('time (s)');
  ylabel('average fluorescence (a.u.)');
  box on;
  title('Average fluorescence trace');
  set(gcf,'Color','w');
  ui = uimenu(hfig, 'Label', 'Export');
  uimenu(ui, 'Label', 'Image',  'Callback', {@exportFigCallback, {'*.png'; '*.tiff'; '*.pdf'; '*.eps'}, [experiment.folder 'avgTraceGlobal']});
end

%--------------------------------------------------------------------------
function menuViewSpectrogram(~, ~, param)
  h = figure;
  hold on;
  switch param
    case 'current'
      currentOrder = getappdata(hFigW, 'currentOrder');
      avgTrace = mean(selectedTraces(:, currentOrder), 2);
%      [pxx, f, pxxc] = pwelch(avgTrace, [], [], [], experiment.fps, 'ConfidenceLevel', 0.95);
      [pxx,f, pxxc] = periodogram(avgTrace,[],length(avgTrace),experiment.fps, 'ConfidenceLevel', 0.95);
      plot(f, 10*log10(pxx));
      xlabel('Frequency (Hz)');
      ylabel('Magnitude (dB)');
    case 'subpopulations'
    if(~isfield(experiment.traceGroups, 'classifier'))
      logMsg('Subpopulations not found', 'e');
      return;
    end
    trainingGroups = length(experiment.traceGroups.classifier);
    for i = 1:trainingGroups
      subplot(trainingGroups, 1, i);
      avgTrace = mean(selectedTraces(:, experiment.traceGroups.classifier{i}),2);
      [pxx, f, pxxc] = periodogram(avgTrace,[],length(avgTrace),experiment.fps, 'ConfidenceLevel', 0.95);
      plot(f, 10*log10(pxx));
      xlabel('Frequency (Hz)');
      ylabel('Magnitude (dB)');
    end
    experiment.spectrogramOptionsCurrent = spectrogramOptionsCurrent;
  end

  box on;
  set(h,'Color','w');
  ui = uimenu(h, 'Label', 'Export');
  uimenu(ui, 'Label', 'Image',  'Callback', {@exportFigCallback, {'*.png'; '*.tiff'; '*.pdf'; '*.eps'}, [experiment.folder 'spectrogram']});
end


%--------------------------------------------------------------------------
function menuViewAverageTraceSubpopulations(~, ~)
    if(~isfield(experiment.traceGroups, 'classifier'))
      logMsg('Subpopulations not found', 'e');
      return;
    end
    hfig = figure;
    yextremes = [nan nan];
    h = [];
    trainingGroups = length(experiment.traceGroups.classifier);
    for i = 1:trainingGroups
      h = [h; subplot(trainingGroups, 1, i)];
      plot(experiment.t, mean(selectedTraces(:, experiment.traceGroups.classifier{i}),2));
      ylabel('avg F (a.u.)');

      title(sprintf('Type: %s', experiment.traceGroupsNames.classifier{i}));

      xlim([min(experiment.t) max(experiment.t)]);
      yl = ylim;
      yextremes(1) = min([yl(1) yextremes(1)]);
      yextremes(2) = max([yl(2) yextremes(2)]);
    end
    
    for i = 1:trainingGroups
        axes(h(i));
        ylim(yextremes);
    end
    
    set(gcf,'Color','w');
    uimenu(hfig, 'Label', 'Export',  'Callback', {@exportFigCallback, {'*.png'; '*.tiff'; '*.pdf'; '*.eps'}, [experiment.folder 'avgTraceSubpopulations']});
end

%--------------------------------------------------------------------------
function menuViewSubpopulationStatistics(~, ~)
    if(~isfield(experiment, 'traceGroups'))
        logMsg('Subpopulations not found', 'e');
        return;
    end
    trainingGroups = length(experiment.traceGroups.classifier);
    figure;
    b = 1:trainingGroups;
    a = zeros(size(b));
    for i = 1:length(a)
        a(i) = size(experiment.traceGroups.classifier{i},1);
    end
    groupPercentage = a/sum(a)*100;
    bar(b, groupPercentage);
    box on;

    set(gca,'XTick', 1:length(experiment.traceGroupsNames.classifier));
    set(gca,'XTickLabel', experiment.traceGroupsNames.classifier);

    for i = 1:trainingGroups
        text(i, groupPercentage(i),[num2str(groupPercentage(i),'%0.1f') '%'],...
                   'HorizontalAlignment','center',...
                   'VerticalAlignment','bottom', 'FontSize', 12);
    end

    xlabel('Type');
    ylabel('Percentage');
    title('ROI classification based on activity');
    ylim([0 100])

end



function menuIdentifyHCG(~, ~, ~)
  currentOrder = getappdata(hFigW, 'currentOrder');
  
  [groupType, groupIdx] = getCurrentGroup();
  curName = getExperimentGroupsNames(experiment, groupType, groupIdx);
  oldGroup = experiment.identifyHCGoptionsCurrent.group;
  experiment.identifyHCGoptionsCurrent.group = {curName{:}, ''};
  
  [success, ~, experiment] = preloadOptions(experiment, identifyHCGoptions, gui, true, false);
  if(success)
    experiment = identifyHCG(experiment, experiment.identifyHCGoptionsCurrent);
    updateImage(true);
    setappdata(hFigW, 'experiment', experiment);
    hs.menu.traces.selection = redoSelectionMenu(experiment, hs.menu.traces);
    updateMenu();
  else
    experiment.identifyHCGoptionsCurrent.group = oldGroup;
  end
end

%% Utility functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------------------------------------------------------------
function viewPositionsOnScreenUpdate()
    if(~isempty(hs.onScreenSelectionWindow) && ishandle(hs.onScreenSelectionWindow))
      currentOrder = getappdata(hFigW, 'currentOrder');
      ROI = experiment.ROI(currentOrder(firstTrace:lastTrace));
      ROIimg = visualizeROI(zeros(size(experiment.avgImg)), ROI, 'plot', false, 'color', true, 'mode','full', 'cmap', cmap);


      invalid = (ROIimg(:,:,1) == 0 & ROIimg(:,:,2) == 0 & ROIimg(:,:,3) == 0);

      alpha = ones(size(ROIimg,1), size(ROIimg,2));
      alpha(invalid) = 0;

      set(hs.onScreenSelectionWindowData, 'CData', ROIimg);
      set(hs.onScreenSelectionWindowData, 'AlphaData', alpha);

      setappdata(hs.onScreenSelectionWindow, 'ROI', ROI);
    end
   if(~isempty(hs.onScreenSelectionMovieWindow) && ishandle(hs.onScreenSelectionMovieWindow))
      currentOrder = getappdata(hFigW, 'currentOrder');
      ROI = experiment.ROI(currentOrder(firstTrace:lastTrace));
      ROIimg = visualizeROI(zeros(size(experiment.avgImg)), ROI, 'plot', false, 'color', true, 'mode','edgeHard', 'cmap', cmap);


      invalid = (ROIimg(:,:,1) == 0 & ROIimg(:,:,2) == 0 & ROIimg(:,:,3) == 0);

      alpha = ones(size(ROIimg,1), size(ROIimg,2));
      alpha(invalid) = 0;

      set(hs.onScreenSelectionMovieWindowData, 'CData', ROIimg);
      set(hs.onScreenSelectionMovieWindowData, 'AlphaData', alpha);
      setappdata(hs.onScreenSelectionMovieWindow, 'ROI', ROI);
    end
end

%--------------------------------------------------------------------------
function viewPositionsWholeScreenUpdate()
  currentOrder = getappdata(hFigW, 'currentOrder');
    if(isempty(hs.wholeScreenSelectionWindow) || ~ishandle(hs.wholeScreenSelectionWindow))
        return;
    end
    %currFrame = experiment.avgImg;
    %me = mean(double(currFrame(:)));
    %se = std(double(currFrame(:)));
    %currFrame(currFrame > me+10*se) = NaN;
    
    ROI = experiment.ROI(currentOrder(:));
    ccmap = eval([cmapName '(length(ROI)+1)']);
    ncbar.automatic('Please wait...');
    ROIimg = visualizeROI(zeros(size(experiment.avgImg)), ROI, 'plot', false, 'color', true, 'mode','full', 'cmap', ccmap);
    ncbar.close();

    invalid = (ROIimg(:,:,1) == 0 & ROIimg(:,:,2) == 0 & ROIimg(:,:,3) == 0);

    alpha = ones(size(ROIimg,1), size(ROIimg,2));
    alpha(invalid) = 0;

    set(hs.wholeScreenSelectionWindowData, 'CData', ROIimg);
    set(hs.wholeScreenSelectionWindowData, 'AlphaData', alpha);
end

%--------------------------------------------------------------------------
function updateSelection()
  % Do some update
    pageChange(1);
    viewPositionsWholeScreenUpdate();
    viewPositionsOnScreenUpdate();
end

%--------------------------------------------------------------------------
function updateButtons()
  
  hs.eventButtonLengthText.Visible = 'off';
  hs.eventButtonLengthEdit.Visible = 'off';
  hs.eventButtonSizeText.Visible = 'off';
  hs.eventButtonSizeEdit.Visible = 'off';
  hs.eventButtonThresholdText.Visible = 'off';
  hs.eventButtonThresholdEdit.Visible = 'off';

  if(strcmp(learningMode, 'trace'))
    hs.mainWindowLearningPanel.Visible = 'on';
    fullString = experiment.traceGroupsNames.classifier;
    for i = 1:numel(fullString)
        fullString{i} = sprintf('%d. %s', i, fullString{i});
    end
    hs.mainWindowLearningGroupSelection.String = fullString;
    hs.mainWindowLearningGroupSelection.Value = 1;
    hs.mainWindowLearningGroupSelectionNtraces.String = sprintf('%d traces assigned', sum(experiment.learningGroup == hs.mainWindowLearningGroupSelection.Value));
  elseif(strcmp(learningMode, 'manual'))
    hs.mainWindowLearningPanel.Visible = 'on';
    fullString = experiment.traceGroupsNames.manual;
    for i = 1:numel(fullString)
        fullString{i} = sprintf('%d. %s', i, fullString{i});
    end
    hs.mainWindowLearningGroupSelection.String = fullString;
    hs.mainWindowLearningGroupSelection.Value = 1;
    hs.mainWindowLearningGroupSelectionNtraces.String = sprintf('%d traces assigned', length(experiment.traceGroups.manual{hs.mainWindowLearningGroupSelection.Value}));
  elseif(strcmp(learningMode, 'event'))
    hs.mainWindowLearningPanel.Visible = 'on';
    fullString = experiment.trainingEventGroupNames;
    for i = 1:numel(fullString)
        fullString{i} = sprintf('%d. %s', i, fullString{i});
    end
    hs.mainWindowLearningGroupSelection.String = fullString;
    hs.mainWindowLearningGroupSelection.Value = 1;
    hs.mainWindowLearningGroupSelectionNtraces.String = sprintf('%d events assigned', experiment.learningEventGroupCount(hs.mainWindowLearningGroupSelection.Value));
    hs.eventButtonLengthText.Visible = 'on';
    hs.eventButtonLengthEdit.Visible = 'on';
    hs.eventButtonSizeText.Visible = 'on';
    hs.eventButtonSizeEdit.Visible = 'on';
    hs.eventButtonThresholdText.Visible = 'on';
    hs.eventButtonThresholdEdit.Visible = 'on';
  else
    hs.mainWindowLearningPanel.Visible = 'off';        
  end
end

%--------------------------------------------------------------------------
function updateMenu()
    
  if(strcmp(learningMode, 'trace'))
      hs.menuClassificationLearningFinish.Enable = 'on';
  else
      hs.menuClassificationLearningFinish.Enable = 'off';
  end
  if(strcmp(learningMode, 'event'))
      hs.menuClassificationEventLearningFinish.Enable = 'on';
  else
      hs.menuClassificationEventLearningFinish.Enable = 'off';
  end
  if(strcmp(learningMode, 'manual'))
      hs.menuClassificationManualFinish.Enable = 'on';
  else
      hs.menuClassificationManualFinish.Enable = 'off';
  end
  if(isfield(experiment, 'features') && ~isempty(experiment.features))
    hs.menuClassificationFeatureSelection.Checked = 'on';
  end
  if(isfield(experiment, 'patternFeatures') && ~isempty(experiment.patternFeatures))
    hs.menuClassificationEventPredefined.Checked = 'on';
  else
    hs.menuClassificationEventPredefined.Checked = 'off';
  end
  if(isfield(experiment, 'validPatterns'))
    hs.menuPreferencesShowPatterns.Visible = 'on';
  end
end


%--------------------------------------------------------------------------
function pageChange(input)
    % Fix the bounds
    input = max(min(input, totalPages), 1);
    
    hs.currentPageText.String = num2str(input);
    firstTrace = 1+numberTraces*(input-1);
    updateImage(true);
end

%--------------------------------------------------------------------------
function [traces, valSubs, valMult, valAdd] = alignTraces(originalTraces, norm)
  traces = originalTraces;
  if(ischar(norm) && (strcmp(norm, 'global') || strcmp(norm, 'global2x')))
    maxF = max(traces(:))*1.1;
    minF = min(traces(:))*0.9;
  end
  if(ischar(norm) && (strcmp(norm, 'globalMax')))
    maxF = max(traces(:))*1.1;
  end
  mult = normalizationMultiplier;
  valSubs = zeros(size(traces, 2), 1);
  valMult = zeros(size(traces, 2), 1);
  valAdd = zeros(size(traces, 2), 1);
  for it = 1:size(traces,2)
    if(ischar(norm))
      switch(norm)
        case 'std'
          if(mult == 0)
            mult = 1/4;
          end
          valSubs(it) = mean(traces(:, it));
          valMult(it) = mult/std(traces(:, it));
          valAdd(it) = it;
        case 'std2'
          if(mult == 0)
            mult = 1/8;
          end
          valSubs(it) = mean(traces(:, it));
          valMult(it) = mult/std(traces(:, it));
          valAdd(it) = it;
        case 'mean'
          if(mult == 0)
            mult = 1/10;
          end
          valSubs(it) = mean(traces(:, it));
          valMult(it) = mult/mean(traces(:, it));
          valAdd(it) = it;
        case 'global'
          if(mult == 0)
            mult = 1;
          end
          valSubs(it) = minF;
          valMult(it) = mult/(maxF-minF);
          %valAdd(it) = it-0.5;
          valAdd(it) = it;
        case 'global2x'
          if(mult == 0)
            mult = 2;
          end
          valSubs(it) = minF;
          valMult(it) = mult/(maxF-minF);
          %valAdd(it) = it-1;
          valAdd(it) = it;
        case 'globalMax'
          if(mult == 0)
            mult = 1;
          end
          valSubs(it) = 0;
          valMult(it) = mult/maxF;
          %valAdd(it) = it-1;
          valAdd(it) = it;
        case 'max'
          if(mult == 0)
            mult = 1;
          end
          valSubs(it) = 0;
          valMult(it) = mult/max(traces(:,it));
          valAdd(it) = it;
        otherwise
          if(mult == 0)
            mult = 1;
          end
          valSubs(it) = 0;
          valMult(it) = 1/str2double(norm);
          valAdd(it) = it;
      end
    else
      valSubs(it) = 0;
      valMult(it) = 1/double(norm);
      valAdd(it) = it;
    end
    traces(:, it) = (traces(:, it)-valSubs(it))*valMult(it)+valAdd(it);
  end
end

%--------------------------------------------------------------------------
function updateImage(varargin)
  if(nargin < 1)
    keepAxis = false;
  else
    keepAxis = varargin{1};
  end
  axes(hs.mainWindowFramesAxes);
  
  if(keepAxis)
    oldXL = hs.mainWindowFramesAxes.XLim;
    oldYL = hs.mainWindowFramesAxes.YLim;
  end
  currentOrder = getappdata(hFigW, 'currentOrder');
  if(additionalExperiments)
    ROIid = getROIid(experiment.ROI);
    originalOrder = currentOrder;
    currentOrder = intersect(originalOrder, additionalValidIdx{1});
    currentOrderAdditional = cell(length(additionalExperimentsList), 1);
    for i = 1:length(additionalExperimentsList)
      currentOrderAdditional{i} = intersect(originalOrder, additionalValidIdx{1+i});
    end
  end
    
  totalPages = ceil(length(currentOrder)/numberTraces);
  %hs.totalPagesText.String = ['/' num2str(totalPages)];
  hs.totalPagesText.String = sprintf('/%d (%d ROI)', totalPages, length(currentOrder));
  traceHandles = [];
  traceGuideHandles = [];
  % Delete everything
  if(additionalExperiments)
    for i = 1:length(additionalAxesList)
      if(~isempty(additionalAxesList))
        delete(additionalAxesList(i));
        delete(additionalExperimentsPanelList(i));
      end
    end
    delete(hs.mainWindowFramesAxes);
    delete(hs.mainWindowFramesPanel);
    hs.mainWindowFramesPanel = uix.Panel('Parent', hs.mainWindowPlotsHBox, 'Padding', 0, 'BorderType', 'none');
    %hs.mainWindowFramesAxes = axes('Parent', hs.mainWindowFramesPanel);
    hs.mainWindowFramesAxes = axes('Parent', uicontainer('Parent', hs.mainWindowFramesPanel));
  end
  
  hs.mainWindowFramesAxes.Units = 'normalized';
  hs.mainWindowFramesAxes.OuterPosition = [0 0 1 1];
  
  if(additionalExperiments)
    additionalAxesList = [];
    additionalExperimentsPanelList = [];
    for i = 1:length(additionalExperimentsList)
      additionalExperimentsPanelList = [additionalExperimentsPanelList; uix.Panel('Parent', hs.mainWindowPlotsHBox, 'Padding', 0, 'BorderType', 'none')];
      additionalAxesList = [additionalAxesList; axes('Parent', additionalExperimentsPanelList(i), 'Units', 'normalized')];
      cla(additionalAxesList(i),'reset');
      axis(additionalAxesList(i), 'manual');
      additionalAxesList(i).Units = 'normalized';
      additionalAxesList(i).OuterPosition = [0 0 1 1];
    end
    for i = 1:length(additionalExperimentsList)
      additionalAxesList(i).Units = 'normalized';
    end
    %hs.mainWindowPlotsHBox.Children
    set(hs.mainWindowPlotsHBox, 'Widths', -1*ones(1,1+length(additionalAxesList)), 'Padding', 0, 'Spacing', 0);
  else
    set(hs.mainWindowPlotsHBox, 'Widths', -1, 'Padding', 0, 'Spacing', 0);
  end
  if(~keepAxis)
    cla(hs.mainWindowFramesAxes,'reset');
  else
    cla(hs.mainWindowFramesAxes);
  end
  hs.mainWindowFramesAxes.Units = 'normalized';
  hs.mainWindowFramesAxes.OuterPosition = [0 0 1 1];
  
  
  set(hs.mainWindow,'CurrentAxes', hs.mainWindowFramesAxes)
  hs.mainWindowFramesAxes.ButtonDownFcn = @rightClick;
  
  if(firstTrace > length(currentOrder))
    firstTrace = 1;
    hs.currentPageText.String = num2str(1);
  end
  lastTrace = firstTrace+numberTraces-1;
  if(lastTrace > length(currentOrder))
      lastTrace = length(currentOrder);
  end
  if(firstTrace > lastTrace)
      firstTrace = 1;
      lastTrace = firstTrace+numberTraces-1;
      hs.currentPageText.String = num2str(1);
  end
  xlabel(hs.mainWindowFramesAxes, 'time (s)');
  ylabel(hs.mainWindowFramesAxes, 'Fluorescence (a.u.)');
  box(hs.mainWindowFramesAxes, 'on');
  hold(hs.mainWindowFramesAxes, 'on');
  if(isempty(currentOrder))
    return;
  end
  
  [traces, valSubs, valMult, valAdd] = alignTraces(selectedTraces(:, currentOrder(firstTrace:lastTrace)), normalization);
  t = selectedT;
  
  % Only show guides for less than 25 traces
  if(length(firstTrace:lastTrace) <= 25)
    if(strcmp(hs.menu.traces.typeRaw.Checked, 'on'))
      traceGuideHandles = [traceGuideHandles; plot(hs.mainWindowFramesAxes, t, repmat(1:size(traces,2), [length(t) 1])','k--', 'HitTest', 'off')];
    else
      traceGuideHandles = [traceGuideHandles; plot(hs.mainWindowFramesAxes, t, repmat(valAdd'-valSubs'.*valMult', [length(t) 1])','k--', 'HitTest', 'off')];
    end
  end

  traceHandles = [traceHandles; plot(hs.mainWindowFramesAxes, t, traces, 'HitTest', 'on')];
  for i = 1:length(traceHandles)
    traceHandles(i).ButtonDownFcn = @rightClick;
      currentColor = cmap(i, :);
      % Trace based
      if(strcmp(learningMode, 'trace') && ~isnan(experiment.learningGroup(currentOrder(firstTrace+i-1))))
          currentColor = cmapLearning(experiment.learningGroup(currentOrder(firstTrace+i-1)), :);
      end
      % Manual
      if(strcmp(learningMode, 'manual'))
        curTrace = currentOrder(firstTrace+i-1);
          for itt = 1:length(experiment.traceGroups.manual)
            if(find(experiment.traceGroups.manual{itt} == curTrace))
              currentColor = cmapLearningManual(itt, :);
            end
          end
      end
      % Event based
      if(strcmp(learningMode, 'event') && ~isempty(experiment.learningEventListPerTrace{currentOrder(firstTrace+i-1)}))
          eventList = experiment.learningEventListPerTrace{currentOrder(firstTrace+i-1)};
          for j = 1:length(eventList)
              %size(traces)
              %eventList{j}
              plot(hs.mainWindowFramesAxes, t(eventList{j}.x), traces(eventList{j}.x, i),'-', 'Color', cmapLearningEvent(eventList{j}.group, :));
          end
      end

      set(traceHandles(i), 'Color', currentColor);
      if(length(firstTrace:lastTrace) <= 25)
        set(traceGuideHandles(i), 'Color', get(traceHandles(i), 'Color'));
      end
  end
  if(showSpikes)
   for i = 1:size(traces, 2)
     curNeuron = currentOrder(firstTrace+i-1);
     spikeTimes = experiment.spikes{curNeuron}(:)';

     %plot(hs.mainWindowFramesAxes, spikeTimes, ones(size(spikeTimes))*i+0.5,'*', 'Color', get(traceHandles(i), 'Color'));
     %plot(hs.mainWindowFramesAxes, repmat(spikeTimes,2,1), cat(1,zeros(size(spikeTimes)),ones(size(spikeTimes)))+i-0.5, 'LineWidth', 2, 'Color', get(traceHandles(i), 'Color'));
%      if(isfield(experiment, 'burstSpikes'))
%        if(~isempty(experiment.burstSpikes{curNeuron}))
%          %continue;
%        %end
%            burstSpikes = experiment.burstSpikes{curNeuron}(:, 1);
%            burstSpikesIdx = experiment.burstSpikes{curNeuron}(:, 2);
%            burstSpikesTimes = spikeTimes(burstSpikes);
%            nonBurstSpikesTimes = spikeTimes;
%            nonBurstSpikesTimes(burstSpikes) = [];
%            % Plot non burst spikes
%            plot(hs.mainWindowFramesAxes, repmat(nonBurstSpikesTimes,2,1), cat(1,zeros(size(nonBurstSpikesTimes)),ones(size(nonBurstSpikesTimes)))+i-0.5, 'LineWidth', 1, 'Color', 'k');
%            % Plot burst spikes
%            burstIdxList = unique(burstSpikesIdx);
%            %colList = lines(length(burstIdxList));
%            colList = prism(length(burstIdxList));
%            for j = 1:length(burstIdxList)
%              valid = find(burstSpikesIdx == burstIdxList(j));
%              plot(hs.mainWindowFramesAxes, repmat(burstSpikesTimes(valid),2,1), cat(1,zeros(size(burstSpikesTimes(valid))),ones(size(burstSpikesTimes(valid))))+i-0.5, 'LineWidth', 1, 'Color', colList(j, :));
%            end
%        end
%      end
     
     plot(hs.mainWindowFramesAxes, repmat(spikeTimes,2,1), ...
          cat(1,ones(size(spikeTimes))*0.9,ones(size(spikeTimes)))+i-0.5, ...,
          'LineWidth', 1, 'Color', 'k');

     if(isfield(experiment, 'spikesBurstsTimes') && experiment.spikeFeaturesOptionsCurrent.fBurstLengthFluorescence)
       colList = prism(length(experiment.spikesBurstsTimes{curNeuron}));
       for j = 1:size(experiment.spikesBurstsTimes{curNeuron},1)
        valid = experiment.spikesBurstsTimes{curNeuron}(j,1):experiment.spikesBurstsTimes{curNeuron}(j,2);
        if(~isempty(valid) & ~isnan(valid))
          % Plot burst length
          %plot(hs.mainWindowFramesAxes, t(valid), traces(valid, i), 'HitTest', 'off', 'Color', colList(j, :));
        end
       end
     end
   end
  end
  if(showPatterns)
    for i = 1:size(traces, 2)
      curNeuron = currentOrder(firstTrace+i-1);
      cpatterns = experiment.validPatterns{curNeuron};
      for j = 1:length(cpatterns)
        plot(hs.mainWindowFramesAxes, t(cpatterns{j}.frames), traces(cpatterns{j}.frames, i), 'HitTest', 'off', 'Color', cmapPatterns(find(strcmp(cpatterns{j}.basePattern, basePatternList)), :));
      end
    end
  end
  if(showBaseLine && ~strcmpi(hs.menu.traces.typeSmoothed.Checked,'on'))
    for i = 1:size(traces, 2)
      curNeuron = currentOrder(firstTrace+i-1);
      baseline = (experiment.baseLine(:, curNeuron)-valSubs(i))*valMult(i)+valAdd(i);
      plot(hs.mainWindowFramesAxes, t, baseline, 'k', 'HitTest', 'off');
    end
  end
  xlim(hs.mainWindowFramesAxes, [t(1) t(end)]);
  ylim(hs.mainWindowFramesAxes, [0 numberTraces+1]);
  set(hs.mainWindowFramesAxes, 'YTick', 1:size(traces,2));
  if(iscell(ROIid))
      set(hs.mainWindowFramesAxes, 'YTickLabel', ROIid(currentOrder(firstTrace:lastTrace)));
  else
      set(hs.mainWindowFramesAxes, 'YTickLabel', num2str(ROIid(currentOrder(firstTrace:lastTrace))));
  end
  xl = xlim;
  for i = 1:length(firstTrace:lastTrace)
    val = max(selectedTraces(:, currentOrder(firstTrace+i-1)))-min(selectedTraces(:, currentOrder(firstTrace+i-1)));
    text(xl(2)*1.01, i, sprintf('%.0f', val));
  end
  if(~isempty(hs.onScreenSelectionMovieWindow) && ishandle(hs.onScreenSelectionMovieWindow))
    if(~isempty(movieLineH) && ishandle(movieLineH))
      delete(movieLineH);
    end
    yl = ylim;
    frameT = getappdata(hs.onScreenSelectionMovieWindow, 't');
    movieLineH = plot([1 1]*frameT/experiment.fps, yl, 'k--');
  end

  if(additionalExperiments)
    %hs.mainWindowFramesAxes.Position(1) = hs.mainWindowFramesAxes.TightInset(1);
    %hs.mainWindowFramesAxes.Position(3) = 1-hs.mainWindowFramesAxes.Position(1)-hs.mainWindowFramesAxes.TightInset(3);
    defaultPosition = hs.mainWindowFramesAxes.Position;
    for it = 1:length(additionalAxesList)
      set(hs.mainWindow,'CurrentAxes', additionalAxesList(it));
      %selectedTraces2 = additionalExperimentsList{it}.traces(:, 1:size(selectedTraces,2));
      selectedTraces2 = additionalExperimentsList{it}.traces;

      [traces2, valSubs2, valMult2, valAdd2] = alignTraces(selectedTraces2(:, currentOrderAdditional{it}(firstTrace:lastTrace)), normalization);
      t = additionalExperimentsList{it}.t;
      ROIid = getROIid(additionalExperimentsList{it}.ROI);
      traceGuideHandles2 = [];
      traceHandles2 = [];
      if(strcmp(hs.menu.traces.typeRaw.Checked, 'on'))
        traceGuideHandles2 = [traceGuideHandles2; plot(additionalAxesList(it), t, repmat(1:size(traces2,2), [length(t) 1])','k--', 'HitTest', 'off')];
      else
        traceGuideHandles2 = [traceGuideHandles2; plot(additionalAxesList(it), t, repmat(valAdd2'-valSubs2'.*valMult2', [length(t) 1])','k--', 'HitTest', 'off')];
      end
      hold(additionalAxesList(it), 'on');
      traceHandles2 = [traceHandles2; plot(additionalAxesList(it), t, traces2, 'HitTest', 'off')];

      for j = 1:length(traceHandles2)
          currentColor = cmap(j, :);
          set(traceHandles2(j), 'Color', currentColor, 'Visible', 'on');
          set(traceGuideHandles2(j), 'Color', get(traceHandles2(j), 'Color'));
      end
      box(additionalAxesList(it), 'on');
      %axis(additionalAxesList(it), 'tight');

      xlim(additionalAxesList(it), [t(1) t(end)]);
      ylim(additionalAxesList(it), [0 numberTraces+1]);
      set(additionalAxesList(it), 'YTick', 1:size(traces2,2));

      %set(additionalAxesList(it),'YTickLabel', []);
      if(iscell(ROIid))
        set(additionalAxesList(it), 'YTickLabel', ROIid(currentOrderAdditional{it}(firstTrace:lastTrace)));
      else
        set(additionalAxesList(it), 'YTickLabel', num2str(ROIid(currentOrderAdditional{it}(firstTrace:lastTrace))));
      end
      xlabel(additionalAxesList(it), 'time (s)');
      ylabel(additionalAxesList(it), 'Fluorescence (a.u.)');
      %additionalAxesList(it).YAxisLocation = 'right';
      title(hs.mainWindowFramesAxes, strrep(experiment.name,'_','\_'));
      title(additionalAxesList(it), strrep(additionalExperimentsList{it}.name,'_','\_'));
      %additionalAxesList(it).Parent =  hs.mainWindowFramesPanel;
      additionalAxesList(it).Visible = 'on';
      additionalAxesList(it).Position = defaultPosition;
    end
    if(all(isvalid(additionalAxesList(:))) && isvalid(hs.mainWindowFramesAxes))
      try
        linkaxes([hs.mainWindowFramesAxes additionalAxesList(:)']);
      end
    end
  end
  set(hs.mainWindow,'CurrentAxes', hs.mainWindowFramesAxes);
  if(strcmp(learningMode, 'trace'))
    hs.mainWindowLearningGroupSelectionNtraces.String = sprintf('%d traces assigned', sum(experiment.learningGroup == hs.mainWindowLearningGroupSelection.Value));
  end
  if(strcmp(learningMode, 'manual'))
    hs.mainWindowLearningGroupSelectionNtraces.String = sprintf('%d traces assigned', length(experiment.traceGroups.manual{hs.mainWindowLearningGroupSelection.Value}));
  end
  if(strcmp(learningMode, 'event'))
    hs.mainWindowLearningGroupSelectionNtraces.String = sprintf('%d events assigned', experiment.learningEventGroupCount(hs.mainWindowLearningGroupSelection.Value));
  end  

  viewPositionsOnScreenUpdate();
  if(keepAxis)
    xlim(oldXL);
    ylim(oldYL);
  end
  
  % Now the protocols part
  if(isfield(experiment, 'KClProtocolOptionsCurrent') && experiment.KClProtocolOptionsCurrent.showProtocol)
    % Do the plots
    %xl = xlim;
    yl = ylim;
    p = plot([1, 1]*experiment.KClProtocolOptionsCurrent.startTime, yl, '--', 'Color', [0.7 0 0], 'LineWidth', 2);
    legendText = {'protocol start'};
    if(~isinf(experiment.KClProtocolOptionsCurrent.endTime))
      p = [p; plot([1, 1]*experiment.KClProtocolOptionsCurrent.endTime, yl, '--', 'Color', [0.7 0 0.8], 'LineWidth', 2)];
      legendText{end+1} = 'protocol end';
    end
    if(~isinf(experiment.KClProtocolOptionsCurrent.windowOfInterest))
      p = [p; plot([1, 1]*(experiment.KClProtocolOptionsCurrent.startTime+experiment.KClProtocolOptionsCurrent.windowOfInterest), yl, '--', 'Color', [0.9 0.4 1], 'LineWidth', 2)];
      legendText{end+1} = 'window of interest end';
    end
   
    %% Now for each trace
    
    for it = 1:size(traces, 2)
      curNeuron = currentOrder(firstTrace+it-1);
      if(isempty(experiment.KClProtocolData{curNeuron}))
        continue;
      end
      curData = experiment.KClProtocolData{curNeuron};
      % From protocol start to reaction time
      plot(t(curData.baseLineFrame:curData.reactionTimeIdx), traces(curData.baseLineFrame:curData.reactionTimeIdx, it), 'k');
      % From reaction time to maximum
      plot(t(curData.reactionTimeIdx:curData.maxResponseTimeIdx), traces(curData.reactionTimeIdx:curData.maxResponseTimeIdx, it), 'b');
      % From maximum to decay
      plot(t(curData.maxResponseTimeIdx:curData.decayTimeIdx), traces(curData.maxResponseTimeIdx:curData.decayTimeIdx, it), 'g');
      % From decay time to recovery
      plot(t(curData.decayTimeIdx:curData.recoveryTimeIdx), traces(curData.decayTimeIdx:curData.recoveryTimeIdx, it), 'r');
      
      plot(t(curData.reactionTimeIdx), traces(curData.reactionTimeIdx, it), 'ko', 'MarkerSize', 8, 'MarkerFaceColor', 'k');
      plot(t(curData.maxResponseTimeIdx), traces(curData.maxResponseTimeIdx, it), 'bo', 'MarkerSize', 8, 'MarkerFaceColor', 'b');
      plot(t(curData.decayTimeIdx), traces(curData.decayTimeIdx, it), 'go', 'MarkerSize', 8, 'MarkerFaceColor', 'g');
      plot(t(curData.recoveryTimeIdx), traces(curData.recoveryTimeIdx, it), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
      plot(t(curData.lastResponseFrame), traces(curData.lastResponseFrame, it), 'mo', 'MarkerSize', 8, 'MarkerFaceColor', 'm');
      plot(t(curData.protocolEndFrame), traces(curData.protocolEndFrame, it), 'co', 'MarkerSize', 8, 'MarkerFaceColor', 'c');
      
      
      %% Now the fits
      if(~isempty(curData.fitRiseCurve))
        x = curData.fitRiseCurve(:, 1);
        y = curData.fitRiseCurve(:, 2);
        plot(x, (y-valSubs(it))*valMult(it)+valAdd(it), 'b');
      end
      if(~isempty(curData.fitDecayCurve))
        x = curData.fitDecayCurve(:, 1);
        y = curData.fitDecayCurve(:, 2);
        plot(x, (y-valSubs(it))*valMult(it)+valAdd(it), 'r');
      end
    end
    %legend(p, legendText);
  else
    %legend('off');
  end
  
  %hs.mainWindowFramesAxes.Position([2,4]) = hs.mainWindowFramesAxes.OuterPosition([2, 4]);
  
  
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

function fullNames = namesWithLabels(varargin)
    % Varargin 1: selection (if 0, everything)
    if(length(varargin) >= 1)
        selection = varargin{1};
    else
        selection = 1:length(project.experiments);
    end
    
    fullNames = cell(length(project.experiments(selection)), 1);

    for n = 1:length(fullNames)
        name = project.experiments{selection(n)};
        if(isfield(project, 'labels') && length(project.labels) >= selection(n) && ~isempty(project.labels{selection(n)}))
            name = [name ' (' project.labels{selection(n)} ')'];
        end
        fullNames{n} = name;
    end
end

%--------------------------------------------------------------------------
% Soft checks
function [exp, success] = consistencyChecks(exp)
  success = false;
  if(isfield(exp, 'rawTraces') && ~ischar(exp.rawTraces) && (size(exp.rawTraces, 1) ~= length(exp.rawT)))
    logMsg(sprintf('Number of frames in time axis inconsistent. You might want to rebase time'), 'e');
  end
  if(isfield(exp, 'traces') && ~ischar(exp.traces) && (size(exp.traces, 1) ~= length(exp.t)))
    logMsg(sprintf('Number of frames in time axis inconsistent. You might want to rebase time'), 'e');
  end
  if(isfield(exp, 'rawTraces') && ~ischar(exp.rawTraces)  && isfield(exp, 'traces') && ~ischar(exp.traces) && size(exp.traces,2) ~= size(exp.rawTraces,2))
    logMsg(sprintf('Number of raw and smoothed traces differ (%d vs %d). Perform a new smoothing', size(exp.rawTraces, 2), size(exp.traces, 2)), 'e');
  end
  if(isfield(exp, 'rawTraces') && ~ischar(exp.rawTraces)  && isfield(exp, 'ROI') && size(exp.ROI,1) ~= size(exp.rawTraces,2))
    logMsg(sprintf('Number of raw traces and ROI differ (%d vs %d). Extract traces again', length(exp.ROI), size(exp.rawTraces, 2)), 'e');
  end
  if(isfield(exp, 'traces') && ~ischar(exp.traces) && isfield(exp, 'ROI') && size(exp.ROI,1) ~= size(exp.traces,2))
    logMsg(sprintf('Number of smoothed traces and ROI differ (%d vs %d). Perform a new smoothing', size(exp.traces, 2), length(exp.ROI)), 'e');
  end 
  if(isfield(exp, 'traces') && ~ischar(exp.traces) && isfield(exp, 'similarityOrder') && size(exp.similarityOrder,1) ~= size(exp.traces,2))
    logMsg(sprintf( 'Number of smoothed traces and similarityOrder differ (%d vs %d). Perform a new similarity analysis', size(exp.traces, 2), length(exp.similarityOrder)), 'e');
  end 

  if(isfield(exp, 'learningGroup') && (~isfield(exp, 'traces') || size(exp.learningGroup, 1) ~= size(exp.traces, 2)))
    [exp, success] = resetAllTraining(exp, 'Number of traces and learning elements differ. Reset all training?');
  end
  if(isfield(exp, 'learningGroup') && ~ischar(exp.rawTraces) && size(exp.learningGroup, 1) ~= size(exp.rawTraces, 2))
    [exp, success] = resetAllTraining(exp, 'Number of raw traces and learning elements differ. Reset all training?');
  end
  if(isfield(exp, 'trainingGroupNames') && ~iscell(exp.trainingGroupNames))
    logMsg('There is a problem with the training group names. Please update them', 'e');
    if(isfield(exp, 'learningOptionsCurrent') && iscell(exp.learningOptionsCurrent.groupNames))
      exp.trainingGroupNames = exp.learningOptionsCurrent.groupNames;
      exp.trainingGroups = length(exp.trainingGroupNames);
    else
      defOptions = learningOptions;
      exp.trainingGroupNames = defOptions.groupNames;
      if(isfield(exp, 'groupTraces') && ~isempty(exp.groupTraces) && length(exp.trainingGroupNames) > length(exp.groupTraces))
        exp.trainingGroupNames = exp.trainingGroupNames(1:length(exp.groupTraces));
      end
      exp.trainingGroups = length(exp.trainingGroupNames);
    end
  end
  if(isfield(exp, 'groupTraces') && ~isempty(exp.groupTraces) && length(exp.trainingGroupNames) > length(exp.groupTraces))
    logMsg('There is a problem with the training groups. Please update them', 'e');
    exp.trainingGroupNames = exp.trainingGroupNames(1:length(exp.groupTraces));
    exp.trainingGroups = length(exp.trainingGroupNames);
  end
  success = true;
end


%--------------------------------------------------------------------------
function [exp, success] = resetAllTraining(exp, msg)
    fieldList = {'trainingGroups','trainingEventGroups',...
        'trainingGroupNames','manualGroups','manualGroupNames',...
        'learningGroup','manualGroup','learningEventListPerTrace',...
        'learningEventGroupCount','classificationGroups','groupTraces',...
        'groupTracesSimilarityOrder','HCG', 'learningEventGroup'};
    
    choice = questdlg(msg, 'Reset training', ...
                       'Yes', 'No', 'Cancel', 'Cancel');
    switch choice
        case 'Yes'
            for it = 1:length(fieldList)
                if(isfield(exp, fieldList{it}))
                    exp = rmfield(exp, fieldList{it});
                end
            end
            success = true;
        case 'No'
            success = false;
        case 'Cancel'
            success = false;
        otherwise
            success = false;
    end
    
end

function data = getFeatures(featureType)
  switch featureType 
    case 'fluorescence'
      data = experiment.features;
      data(isnan(data))=0;
    case {'simplifiedPatterns','fullPatterns'}
      simplifiedFeatureList = zeros(length(experiment.patternFeatures), 1);
      for it = 1:length(experiment.patternFeatures)
        switch experiment.patternFeatures{it}.basePattern
          case 'exponential'
            simplifiedFeatureList(it) = 1;
          case 'gaussian'
            simplifiedFeatureList(it) = 2;
          case 'lognormal'
            simplifiedFeatureList(it) = 3;
          otherwise
            simplifiedFeatureList(it) = 4;
        end
      end
      countSimplifiedList = zeros(size(selectedTraces, 2), 4);
      countList = zeros(size(selectedTraces, 2), length(experiment.patternFeatures));
      for it = 1:size(selectedTraces, 2)
      %for it = 1
        if(isempty(experiment.validPatterns{it}))
          continue;
        end
        patternList = cellfun(@(x)x.pattern, experiment.validPatterns{it});
        patternListSimplified = simplifiedFeatureList(patternList);
        count = histc(patternList, 0.5+(0:length(experiment.patternFeatures)));
        count = count(1:end-1);
        countList(it, :) = count;
        countSimplified = histc(patternListSimplified, 0.5+(0:4));
        countSimplified = countSimplified(1:end-1);
        countSimplifiedList(it, :) = countSimplified;
      end
      if(strcmpi(featureType, 'simplifiedPatterns'))
        data = countSimplifiedList;
      else
        data = countList;
      end
  end
end

end
