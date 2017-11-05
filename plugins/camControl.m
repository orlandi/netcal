function hFigW = camControl(hObject, ~, varargin)
% CAMCONTROL GUI to control Hamamatsu ORCA cameras
%
% USAGE:
%    hFigW = camControl()
%
% INPUT arguments:
%    hObject - In case it is called as a callback
%
%    eventData - In case it is called as a callback
%
% INPUT optional arguments ('key' followed by its value):
%
%    dryRUN - Only used for testing purposes
%
% OUTPUT arguments:
%    hFigW - handle to the GUI figure
%
% EXAMPLE:
%    hFigW = camControl);
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% TODO
% Hey, if we write consecutive frames to multiple hard drives we do not
% need a RAID system to achieve maximum writing speeds. We just need a new
% interface to concatenate the new multi-file movies. For now let's start
% by trying to store the same number of frames onto a continous buffer
%
% Need ability to create new experiments within a project
%
% Missing: lower trace, glia-like movie, spikes, bursts
%
% Live spike inference - probably using OASIS

%#ok<*AGROW>
%#ok<*ASGLU>
%#ok<*FXUP>
%#ok<*INUSD>
%#ok<*ST2NM>

appFolder = fileparts(mfilename('fullpath'));
appFolder = [appFolder filesep '..'];
if(nargin == 0 || isempty(hObject))
  addpath(genpath([appFolder filesep 'internal']));
  addpath(genpath([appFolder filesep 'external']));
end

% Define additional optional argument pairs
params.dryRun = false;
% Parse them
params = parse_pv_pairs(params, varargin);
dryRun = params.dryRun;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Initialization
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
ncbar.automatic('Loading...');
gui = gcbf;

hFigW = [];
textFontSize = 10;
minGridBorder = 1;
movieRunning = false;
movieRecording = false;
realSize = false;
paused = false;
autoLevelsReset = true;
persistent ROIPosition;
persistent currFolder
if(isempty(currFolder))
  currFolder = appFolder;
end

if(~isempty(gui))
  proj = getappdata(gui, 'project');
  if(~isempty(proj))
    currFolder = proj.folder;
  end
end

%framesBuffer = [];
maxScreenFrameRate = 10;
updateRate = maxScreenFrameRate;
totalFrames = 1000;
baseT = 0;

outputVideoFile = 'recording.bin';
videoFileID = [];
bufferAllTraces = true;
saveMovie = true;
minIntensity = 0;
maxIntensity = 255;
futures = [];

gliaID = [];
gliaParams = [];
gliaF = [];
gliaT = [];
gliaFrameStart = [];
gliaFrameFinish = [];
        
histogramHandle = [];
histogramFigure = [];
histogramAxes = [];
histogramLineHandles = [];
histWidth = 1;
gliaAverageFrame = [];
multiIteration = 0;

bufferSize = 1000;
t = nan(bufferSize, 1);
timerT = nan(bufferSize, 1);
avgTrace = nan(bufferSize, 1);
avgTraceLower = [];
lowerPercentilePixel = 1;
avgT = nan(bufferSize, 1);
avgImg = [];
imData = [];
ROIimg = [];
plotHandleList = [];
cursorHandle = [];
selectionMode = 'normal';
sortMode = 'ROI';
addCount = 0;
ROIid = [];
% persistent recordingLength;
% if(isempty(recordingLength))
%   recordingLength = 300;
% end

multiDriveMode = false;
numberOfDrives = 1;
currentDrive = 1;
driveFrameIndex = [];
driveFramePosition = [];
driveCurrentFrame = [];
currentOrder = 1;
numberTraces = 10;
firstTrace = 1;
lastTrace = numberTraces;
ROItraces = [];
ROImodelTraces = [];
spikes = [];
totalPages = 1;
traceHandles = [];
modelTraceHandles = [];
spikeHandles = [];
cmap = parula(numberTraces + 1);
ROImode = 'active';
traceMode = 'average'; % average / ROI
disableTraceUpdates = false;

experiment = [];
[~, ROIautomaticOptionsCurrent] = preloadOptions(experiment, ROIautomaticOptions, gui, false, false);
experiment.ROIautomaticOptionsCurrent = ROIautomaticOptionsCurrent;
[~, ROIselectionOptionsCurrent] = preloadOptions(experiment, ROIselectionOptions, gui, false, false);
experiment.ROIselectionOptionsCurrent = ROIselectionOptionsCurrent;
[~, ccRecordingOptionsCurrent] = preloadOptions(experiment, ccRecordingOptions, gui, false, false);
experiment.ccRecordingOptionsCurrent = ccRecordingOptionsCurrent;

ROI = [];

normalizationMode = 'together';
spikeDetection = false;

recordingClock = tic;

% These two are only for winvideo
availableFPS = [];
currentFPS = [];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Camera initialization
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

try
  imaqreset;
  camHardware = 'hamamatsu';
  info = imaqhwinfo(camHardware);
  dev = info.DeviceInfo(1);
  formatList = dev.SupportedFormats;
  vid = videoinput(camHardware, 1, dev.DefaultFormat);
  currentFormat = find(strcmp(dev.DefaultFormat,formatList));
  src = getselectedsource(vid);
  vid.FramesPerTrigger = 1;
  src.ExposureTime = 0.1;
  FPS = 1/src.ExposureTime;
  
  if(isempty(ROIPosition))
    ROIPosition = [512 512 1024 1024];
    vid.ROIPosition = ROIPosition;
    %ROIPosition = vid.ROIPosition;
  else
    vid.ROIPosition = ROIPosition;
  end
  %vid.ROIPosition = [1024 1024 1024 1024];
catch ME
  logMsg(ME.message, hFigW);
  logMsg('Hamamatsu camera not found. Trying winvideo', 'e');
  try
    % Disabling macvideo for now due to memory issues
    %if(ismac)
    %  camHardware = 'macvideo';
    %else
      camHardware = 'winvideo';
    %end
    info = imaqhwinfo(camHardware);
    dev = info.DeviceInfo(1);
    formatList = dev.SupportedFormats;
    vid = videoinput(camHardware, 1, dev.DefaultFormat);
    currentFormat = find(strcmp(dev.DefaultFormat,formatList));
    src = getselectedsource(vid);
    vid.FramesPerTrigger = 1;
    if(strcmpi(camHardware, 'winvideo'))
      fpsInfo = propinfo(src,'FrameRate');
      availableFPS = fpsInfo.ConstraintValue;
      currentFPS = find(strcmp(src.FrameRate,availableFPS));
      FPS = str2double(src.FrameRate);
    else
      availableFPS = {'30'};
      currentFPS = 1;
      FPS = 30;
    end
  catch ME
    logMsg(ME.message, hFigW);
    logMsg('winvideo/macvideo not found. Trying a standard webcam', 'e');
    dryRun = true;
  end
end

if(dryRun)
  try
    vid = webcam;
    formatList = vid.AvailableResolutions;
    currentFormat = find(strcmp(vid.Resolution, formatList));
    res = strsplit(formatList{currentFormat},'x');
    ROIPosition(3) = str2double(res{1});
    ROIPosition(4) = str2double(res{2});
    currFrame = zeros(ROIPosition(4), ROIPosition(3));
    dryRun = false;
    camHardware = 'webcam';
    FPS = maxScreenFrameRate;
    BPP = 8;
  catch ME
    logMsg(ME.message);
    logMsg('Webcam not found. Using a still image', 'e');
    camHardware = 'none';
    imSize = [1 1]*2048;
    BPP = 16;
    FPS = 30;
  end
end

plotPeriod =  1/maxScreenFrameRate;
mainTimer = timer('TimerFcn', @timerUpdate, ...
                       'BusyMode', 'error', 'ExecutionMode','FixedRate',...
                       'Period', plotPeriod, 'Tag', 'mainTimer', 'ErrorFcn', @timerUpdateError);
recordingTimer = timer('TimerFcn', @timerRecordingUpdate, ...
                       'BusyMode', 'drop', 'ExecutionMode','FixedRate',...
                       'Period', 1/maxScreenFrameRate, 'Tag', 'recordingTimer');
frameIterator = 0;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Create components
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
hs.mainWindow = figure('Visible','off',...
                       'Resize','on',...
                       'Toolbar', 'figure',...
                       'Tag','camControl', ...
                       'NumberTitle', 'off',...
                       'DockControls','off',...
                       'MenuBar', 'none',...
                       'Name', 'camControl',...
                       'KeyPressFcn', @KeyPress, ...
                       'SizeChangedFcn', @mainWindowResize,...
                       'WindowButtonMotionFcn', @ROIWindowButtonMotionFcn,...
                       'CloseRequestFcn', @closeCallback);
hFigW = hs.mainWindow;
hFigW.Position = setFigurePosition(gui, 'width', 1200, 'height', 840);
if(~isempty(gui))
  setappdata(hFigW, 'logHandle', getappdata(gcbf, 'logHandle'));
end

hs.menuFile = uimenu(hs.mainWindow, 'Label', 'File');
hs.menuFileLoadROI = uimenu(hs.menuFile, 'Label', 'Load ROI', 'Callback', @menuLoadROI);
hs.menuFileLoadROIcompatibility = uimenu(hs.menuFile, 'Label', 'Load ROI (compatibility mode)', 'Callback', @menuLoadROIcompatibility);
hs.menuFileSaveROI = uimenu(hs.menuFile, 'Label', 'Save ROI', 'Callback', @menuSaveROI);

hs.menuAdd  = uimenu(hs.mainWindow, 'Label', 'Add ROI');
hs.menuAutomatic = uimenu(hs.menuAdd, 'Label', 'Automatic', 'Callback', @autoROI);

hs.menuActive = uimenu(hs.menuAdd, 'Label', 'Active contour', 'Callback', @activeROIButton, 'Accelerator', 'A');
hs.menuIndividual = uimenu(hs.menuAdd, 'Label', 'Individual');
hs.menuIndividualSquare = uimenu(hs.menuIndividual, 'Label', 'Square', 'Callback', @addSquare, 'Accelerator', 'S');
hs.menuIndividualCircle = uimenu(hs.menuIndividual, 'Label', 'Circle', 'Callback', @addCircle, 'Accelerator', 'C');
hs.menuGrid = uimenu(hs.menuAdd, 'Label', 'Grid');
hs.menuGridCircle2 = uimenu(hs.menuGrid, 'Label', 'Circle (center + radius)', 'Callback', @menuCircle2);
hs.menuGridCircle3 = uimenu(hs.menuGrid, 'Label', 'Circle (3 perimeter points)', 'Callback', @menuCircle3);
hs.menuRectangleFull = uimenu(hs.menuGrid, 'Label', 'Rectangle (whole image)', 'Callback', @menuRectangleFull);
hs.menuRectangleRegion = uimenu(hs.menuGrid, 'Label', 'Rectangle (subregion)', 'Callback', @menuRectangleRegion);
hs.menuMoveROI = uimenu(hs.menuAdd, 'Label', 'Move all ROIs', 'Callback', @menuMoveROI);
%hs.menuImportROI = uimenu(hs.menuAdd, 'Label', 'Import from another experiment', 'Callback', @menuImportROI);

hs.menuDelete  = uimenu(hs.mainWindow, 'Label', 'Delete ROI');
hs.menuDeleteClear = uimenu(hs.menuDelete, 'Label', 'All', 'Callback', @menuClear);
hs.menuDeleteIndividual = uimenu(hs.menuDelete, 'Label', 'Individual', 'Callback', @menuDelete, 'Accelerator', 'D');
hs.menuDeleteArea = uimenu(hs.menuDelete, 'Label', 'Area', 'Callback', @menuDeleteArea);

hs.menu.traces.root = uimenu(hs.mainWindow, 'Label', 'Traces');
hs.menu.traces.sort.root = uimenu(hs.menu.traces.root, 'Label', 'Sort');
hs.menu.traces.sort.ROI = uimenu(hs.menu.traces.sort.root, 'Label', 'ROI', 'Callback', {@sortTraces, 'ROI'}, 'Checked', 'on');
hs.menu.traces.sort.similarity = uimenu(hs.menu.traces.sort.root, 'Label', 'Similarity', 'Callback', {@sortTraces, 'Similarity'});

hs.menu.traces.view.root = uimenu(hs.menu.traces.root, 'Label', 'View');
hs.menu.traces.view.together = uimenu(hs.menu.traces.view.root, 'Label', 'Together', 'Callback', {@viewTraces, 'together'}, 'Checked', 'on');
hs.menu.traces.view.separated = uimenu(hs.menu.traces.view.root, 'Label', 'Separated', 'Callback', {@viewTraces, 'separated'});
hs.menu.traces.view.separated = uimenu(hs.menu.traces.view.root, 'Label', 'Separated & Normalized', 'Callback', {@viewTraces, 'separatedNormalized'});


hs.menu.preferences.root = uimenu(hs.mainWindow, 'Label', 'Preferences');
hs.menu.preferences.list = uimenu(hs.menu.preferences.root, 'Label', 'General', 'Callback', @preferences);
hs.menu.preferences.colormap = uimenu(hs.menu.preferences.root, 'Label', 'Colormap');
colormapList = getHtmlColormapNames({'gray', 'parula', 'morgenstemning', 'jet', 'isolum'}, 150, 15);
hs.menu.preferences.cmaps = [];
for i = 1:length(colormapList)
    hs.menu.preferences.cmaps = [hs.menu.preferences.cmaps; uimenu(hs.menu.preferences.colormap, 'Label', colormapList{i}, 'Callback', @changeColormap, 'Checked', 'off')];
end
hs.menu.preferences.cmaps(1).Checked = 'on';
hs.menu.preferences.realSize = uimenu(hs.menu.preferences.root, 'Label', 'Real Size', 'Enable', 'on', 'Callback', @menuPreferencesRealSize);
hs.menu.preferences.numTraces = uimenu(hs.menu.preferences.root, 'Label', 'Number visible ROI traces', 'Enable', 'on', 'Callback', @menuPreferencesNumberTraces);
% Camera preferences
hs.menu.preferences.ROIregion = [];
hs.menu.preferences.format.root = [];
hs.menu.preferences.format.list = [];
hs.menu.preferences.fps.root = [];
switch camHardware
  case 'hamamatsu'
    hs.menu.preferences.ROIregion = uimenu(hs.menu.preferences.root, 'Label', 'ROI region', 'Separator', 'on', 'Enable', 'on', 'Callback', @menuPreferencesROIregion);
    hs.menu.preferences.format.root = uimenu(hs.menu.preferences.root, 'Label', 'Video format');
    hs.menu.preferences.format.list = [];
    for i = 1:length(formatList)
      b = uimenu(hs.menu.preferences.format.root, 'Label', formatList{i}, 'Callback', {@changeFormat, formatList{i}});
      if(i == currentFormat)
        b.Checked = 'on';
      end
      hs.menu.preferences.format.list = [hs.menu.preferences.format.list; b];
    end
  case {'winvideo', 'macvideo'}
    hs.menu.preferences.format.root = uimenu(hs.menu.preferences.root, 'Label', 'Video format');
    hs.menu.preferences.format.list = [];
    for i = 1:length(formatList)
      b = uimenu(hs.menu.preferences.format.root, 'Label', formatList{i}, 'Callback', {@changeFormat, formatList{i}});
      if(i == currentFormat)
        b.Checked = 'on';
      end
      hs.menu.preferences.format.list = [hs.menu.preferences.format.list; b];
    end
    hs.menu.preferences.fps.root = uimenu(hs.menu.preferences.root, 'Label', 'Video Framerate');
    hs.menu.preferences.fps.list = [];
    for i = 1:length(availableFPS)
      b = uimenu(hs.menu.preferences.fps.root, 'Label', availableFPS{i}, 'Callback', {@changeWinvideoFPS, availableFPS{i}});
      if(i == currentFPS)
        b.Checked = 'on';
      end
      hs.menu.preferences.fps.list = [hs.menu.preferences.fps.list; b];
    end
  case 'webcam'
    hs.menu.preferences.format.root = uimenu(hs.menu.preferences.root, 'Label', 'Video format');
    hs.menu.preferences.format.list = [];
    for i = 1:length(formatList)
      b = uimenu(hs.menu.preferences.format.root, 'Label', formatList{i}, 'Callback', {@changeFormat, formatList{i}});
      if(i == currentFormat)
        b.Checked = 'on';
      end
      hs.menu.preferences.format.list = [hs.menu.preferences.format.list; b];
    end
    
end


hs.menuHotkeys = uimenu(hs.mainWindow, 'Label', 'Hotkeys');
hs.menuHotkeysPan = uimenu(hs.menuHotkeys, 'Label', 'Pan', 'Accelerator', 'P', 'Callback', @hotkeyPan);

hs.menu.export.root = uimenu(hs.mainWindow, 'Label', 'Export');
hs.menu.export.current = uimenu(hs.menu.export.root, 'Label', 'Current image', 'Callback', @exportCurrentImage);

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

% ROI selection buttons -------------------------------------------------
hs.mainWindowTop = uix.VBox( 'Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowTop);
hs.mainWindowTopButtons = uix.HBox( 'Parent', hs.mainWindowTop);
uix.Empty('Parent', hs.mainWindowTopButtons);
uicontrol('Parent', hs.mainWindowTopButtons, 'String', 'Show all ROI', 'FontSize', textFontSize, 'Callback', {@showROImode, 'all'});
uicontrol('Parent', hs.mainWindowTopButtons, 'String', 'Show active ROI', 'FontSize', textFontSize, 'Callback', {@showROImode, 'active'});
uicontrol('Parent', hs.mainWindowTopButtons, 'String', 'Hide ROI', 'FontSize', textFontSize, 'Callback', {@showROImode, 'none'});
uix.Empty('Parent', hs.mainWindowTopButtons);
set(hs.mainWindowTopButtons, 'Widths', [-1 100 100 100 -1], 'Padding', 0, 'Spacing', 15);
set(hs.mainWindowTop, 'Heights', [-1, 20], 'Padding', 0, 'Spacing', 5);


% Frames panel
hs.mainWindowFramesPanel = uix.Panel('Parent', hs.mainWindowGrid, 'Padding', 0, 'BorderType', 'etchedin');
hs.mainWindowFramesAxes = axes('Parent', hs.mainWindowFramesPanel);

hs.roiMenu.root = uicontextmenu;
hs.roiMenu.sortROI = uimenu(hs.roiMenu.root, 'Label','Sort ROI by distance', 'Callback', @rightClickMovie);
hs.mainWindowFramesAxes.UIContextMenu = hs.roiMenu.root;
  
% Below image panel
hs.mainWindowBottomButtons = uix.VBox('Parent', hs.mainWindowGrid);

b = uix.HBox('Parent', hs.mainWindowBottomButtons);

FPStext = uicontrol('Parent', b, 'Style','edit',...
          'String', num2str(round(FPS)), 'FontSize', textFontSize, 'HorizontalAlignment', 'left', 'Callback', @frameRateChange);
if(strcmpi(camHardware, 'winvideo') || strcmpi(camHardware, 'macvideo'))
  FPStext.Enable = 'inactive';
end
uicontrol('Parent', b, 'Style', 'text', 'String', 'recording fps', 'FontSize', textFontSize, 'HorizontalAlignment', 'left');
moviePreviewButton = uicontrol('Parent', b, 'String', 'Start preview', 'FontSize', textFontSize, 'Callback', @moviePreview);
currentFrameText = uicontrol('Parent', b, 'Style', 'text', 'String', '', 'FontSize', textFontSize, 'HorizontalAlignment', 'left');
%autoROIButton = uicontrol('Parent', b, 'String', 'Auto ROI', 'FontSize', textFontSize, 'Callback', @autoROI);

set(b, 'Widths', [30 130 100 200], 'Spacing', 5, 'Padding', 0);

b = uix.HBox('Parent', hs.mainWindowBottomButtons);
recordingLengthText = uicontrol('Parent', b, 'Style','text',...
          'String', num2str(experiment.ccRecordingOptionsCurrent.recordingLength), 'FontSize', textFontSize, 'HorizontalAlignment', 'left');
uicontrol('Parent', b, 'Style', 'text', 'String', 'remaining time (s)', 'FontSize', textFontSize, 'HorizontalAlignment', 'left');
movieRecordButton = uicontrol('Parent', b, 'String', 'Start recording', 'FontSize', textFontSize, 'Callback', @movieRecord);
movieRecordFPS = uicontrol('Parent', b, 'Style', 'text', 'String', '', 'FontSize', textFontSize, 'HorizontalAlignment', 'left');

set(b, 'Widths', [50 110 100 200], 'Spacing', 5, 'Padding', 0);

b = uix.HBox('Parent', hs.mainWindowBottomButtons);
%recordingLengthText = uicontrol('Parent', b, 'Style','edit',...
%          'String', num2str(recordingLength), 'FontSize', textFontSize, 'HorizontalAlignment', 'left', 'Callback', @setRecordingLength);
framesBufferText = uicontrol('Parent', b, 'Style', 'text', 'String', 'Frames in buffer: 0', 'FontSize', textFontSize, 'HorizontalAlignment', 'left');
movieOptionsButton = uicontrol('Parent', b, 'String', 'Recording options', 'FontSize', textFontSize, 'Callback', @setRecordingOptions);
set(b, 'Widths', [165 150], 'Spacing', 5, 'Padding', 0);


set(hs.mainWindowBottomButtons, 'Heights', [20 20 20], 'Padding', 0, 'Spacing', 10);

if(dryRun)
  if(BPP == 8)
    %currFrame = uint8(floor(2^BPP*rand(imSize(1), imSize(2))));
    currFrame = peaks(imSize(1));
    currFrame = currFrame - min(currFrame(:));
    currFrame = currFrame/max(currFrame(:));
    currFrame = uint8(floor(2^BPP*currFrame));
  elseif(BPP == 16)
    %currFrame = uint16(floor(2^BPP*rand(imSize(1), imSize(2))));
    currFrame = peaks(imSize(1));
    currFrame = currFrame - min(currFrame(:));
    currFrame = currFrame/max(currFrame(:));
    currFrame = uint16(floor(2^BPP*currFrame));
    %currFrame = uint16(floor(2^BPP*rand(imSize(1), imSize(2))));
  else
    currFrame = rand(imSize(1), imSize(2));
  end
else
  currFrame = zeros(64);
end

%resetFrame();
%axes(hs.mainWindowFramesAxes);
ROIimgData = imagesc(ones(size(currFrame)), 'HitTest', 'off');
%overlayData = imagesc(ones(size(currFrame)), 'HitTest', 'off');

uix.Empty('Parent', hs.mainWindowGrid);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% COLUMN START
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

uix.Empty('Parent', hs.mainWindowGrid);

% Right buttons
hs.mainWindowRightButtons = uix.VBox('Parent', hs.mainWindowGrid);

maxIntensityText = uicontrol('Parent', hs.mainWindowRightButtons, 'Style','edit',...
          'String', '12', 'FontSize', textFontSize, 'HorizontalAlignment', 'center', 'callback', {@intensityChange, 'max'});

% Colorbar panel
hs.colorbarHBox = uix.HBox('Parent', hs.mainWindowRightButtons);
uix.Empty('Parent', hs.colorbarHBox);
hs.mainWindowColorbarPanel = uix.Panel('Parent', hs.colorbarHBox, 'Padding', 0, 'BorderType', 'none');
hs.mainWindowColorbarAxes = axes('Parent', hs.mainWindowColorbarPanel);
hs.mainWindowColorbarAxes.Units = 'normalized';
hs.mainWindowColorbarAxes.Visible = 'off';
hs.mainWindowColorbar = colorbar('peer', hs.mainWindowColorbarAxes);
set(hs.mainWindowColorbar, 'XTick', []);
uix.Empty('Parent', hs.colorbarHBox);

minIntensityText = uicontrol('Parent', hs.mainWindowRightButtons, 'Style','edit',...
          'String','12', 'FontSize', textFontSize, 'HorizontalAlignment', 'center', 'callback', {@intensityChange, 'min'});

% Below right buttons
hs.mainWindowBottomButtonsA = uix.VBox('Parent', hs.mainWindowGrid);
uicontrol('Parent', hs.mainWindowBottomButtonsA, 'String', 'Auto', 'FontSize', textFontSize, 'Callback', @autoLevels);
uicontrol('Parent', hs.mainWindowBottomButtonsA, 'String', 'Hist', 'FontSize', textFontSize, 'Callback', @showHistogram);


set(hs.colorbarHBox, 'Widths', [-1 -2 -1], 'Spacing', 0, 'Padding', 0);
set(hs.mainWindowRightButtons, 'Heights', [20 -1 20], 'Spacing', 5, 'Padding', 0);
set(hs.mainWindowBottomButtonsA, 'Heights', [20 20], 'Padding', 0, 'Spacing', 5);

uix.Empty('Parent', hs.mainWindowGrid);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% COLUMN START
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Trace selection buttons -------------------------------------------------
hs.mainWindowTop = uix.VBox( 'Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowTop);
hs.mainWindowTopButtons = uix.HBox( 'Parent', hs.mainWindowTop);
uix.Empty('Parent', hs.mainWindowTopButtons);
uicontrol('Parent', hs.mainWindowTopButtons, 'String', 'Average trace', 'FontSize', textFontSize, 'Callback', {@traceModeSelection, 'average'});
uicontrol('Parent', hs.mainWindowTopButtons, 'String', 'ROI traces', 'FontSize', textFontSize, 'Callback', {@traceModeSelection, 'ROI'});
resetTracesButton = uicontrol('Parent', hs.mainWindowTopButtons, 'String', 'Reset traces', 'FontSize', textFontSize, 'Callback', @resetAllTraces);
uix.Empty('Parent', hs.mainWindowTopButtons);
spikeDetectionButton = uicontrol('Parent', hs.mainWindowTopButtons, 'String', 'Spike detection', 'FontSize', textFontSize, 'Callback', @detectSpikes);
uix.Empty('Parent', hs.mainWindowTopButtons);
set(hs.mainWindowTopButtons, 'Widths', [-1 100 100 100 50 100 -1], 'Padding', 0, 'Spacing', 15);
set(hs.mainWindowTop, 'Heights', [-1, 20], 'Padding', 0, 'Spacing', 5);

% Traces panel
hs.mainWindowTracesPanel = uix.Panel('Parent', hs.mainWindowGrid, 'Padding', 0, 'BorderType', 'etchedin');
% Traces axes
hs.mainWindowTracesAxes = axes('Parent', hs.mainWindowTracesPanel);

traceHandles = plot(avgT, avgTrace);
box on;
xlabel('time (s)');
ylabel('F (a.u.)');
%axis square;
xlim(hs.mainWindowTracesAxes, [0 bufferSize/maxScreenFrameRate]);
set(hs.mainWindowTracesAxes, 'LooseInset', [0,0,0,0]);

% Pages buttons -----------------------------------------------------------
hs.mainWindowBottom = uix.VBox( 'Parent', hs.mainWindowGrid);
hs.mainWindowBottomButtons = uix.HBox( 'Parent', hs.mainWindowBottom);
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', '<', 'FontSize', textFontSize, 'callback', @previousTracesButton);
uix.Empty('Parent', hs.mainWindowBottomButtons);

hs.mainWindowBottomButtonsCurrentPage = uix.HBox( 'Parent', hs.mainWindowBottomButtons);
uicontrol('Parent', hs.mainWindowBottomButtonsCurrentPage, 'Style', 'text', 'String', 'Current page:', 'FontSize', textFontSize, 'HorizontalAlignment', 'right');

hs.currentPageText = uicontrol('Parent', hs.mainWindowBottomButtonsCurrentPage, 'Style','edit',...
          'String', '1', 'FontSize', textFontSize, 'HorizontalAlignment', 'left', 'Callback', @currentPageChange);
hs.totalPagesText = uicontrol('Parent', hs.mainWindowBottomButtonsCurrentPage, 'Style', 'text', 'String', ['/' num2str(totalPages)], 'FontSize', textFontSize, 'HorizontalAlignment', 'left');
set(hs.mainWindowBottomButtonsCurrentPage, 'Widths', [100 35 35], 'Spacing', 5, 'Padding', 0);


uix.Empty('Parent', hs.mainWindowBottomButtons);
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', '>', 'FontSize', textFontSize, 'callback', @nextTracesButton);
%uix.Empty('Parent', hs.mainWindowBottom);
experimentInfoText = uicontrol('Parent', hs.mainWindowBottom, ...
                      'style', 'edit', 'max', 5, 'Background','w', 'HorizontalAlignment', 'left');

set(hs.mainWindowBottomButtons, 'Widths', [40 -1 200 -1 40], 'Padding', 0, 'Spacing', 15);
set(hs.mainWindowBottom, 'Heights', [20, -1], 'Padding', 0, 'Spacing', 5);

if(strcmpi(traceMode, 'average'))
  hs.mainWindowBottomButtons.Visible = 'off';
end

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

colormap(gray);
WIDTHLIST = [minGridBorder -1 60 -1 minGridBorder];
HEIGHTLIST = [minGridBorder+40 -1 100 minGridBorder];
GRIDSPACING = 5;
set(hs.mainWindowGrid, 'Widths', WIDTHLIST, ...
    'Heights', HEIGHTLIST, 'Spacing', GRIDSPACING);

  
% Now the log panel
hs.logPanelParent = uix.Panel('Parent', hs.mainWindowSuperBox, ...
                               'BorderType', 'none');
hs.logPanel = uicontrol('Parent', hs.logPanelParent, ...
                      'style', 'edit', 'max', 5, 'Background','w');
set(hs.mainWindowSuperBox, 'Heights', [-1 100], 'Padding', 0, 'Spacing', 0);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Final init
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


objectsDisabledDuringRecording = {movieOptionsButton, moviePreviewButton, FPStext, resetTracesButton, hs.menuAdd, hs.menuDelete, hs.menu.traces.sort.similarity, hs.menu.preferences.list, hs.menu.preferences.ROIregion, hs.menu.preferences.format.root, hs.menu.preferences.fps.root};

cleanMenu();

% Finish the new log panel
%hFigW.Visible = 'on';

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
  setappdata(hFigW, 'logHandle', hs.logPanelEditBox);
end
ncbar.close();
if(~dryRun)
  switch camHardware
    case 'hamamatsu'
      moviePreview();
      currFrame = peekdata(vid, 1);
    case {'winvideo', 'macvideo'}
      moviePreview();
      currFrame = peekdata(vid, 1);
      currFrame = rgb2gray(currFrame);
    case 'webcam'
      currFrame = snapshot(vid);
      %currFrame = uint8(mean(currFrame, 3));
      currFrame = rgb2gray(currFrame);
      moviePreview();
  end
  switch class(currFrame)
    case 'uint16'
      BPP = 16;
    case 'uint8'
      BPP = 8;
    otherwise
      BPP = 16;
  end
end
autoLevels();
mainWindowResize();
hFigW.Visible = 'on';

if(isempty(gui))
  waitfor(hFigW);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Callbacks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------------------------------------------------------------
function mainWindowResize(~, ~)
  set(hs.mainWindowGrid, 'Widths', WIDTHLIST, ...
      'Heights', HEIGHTLIST, 'Spacing', GRIDSPACING);
  pos = plotboxpos(hs.mainWindowFramesAxes);
  hs.mainWindowColorbar.Position(2) = pos(2);
  hs.mainWindowColorbar.Position(4) = pos(4);
  
  
  realRatio = size(currFrame,2)/size(currFrame,1);
  curPos = hs.mainWindowFramesAxes.Position;
  if(realSize)
    curSize = get(hs.mainWindow, 'Position');
    if(isempty(curSize))
      return;
    end
    curPos(3) = size(currFrame,2);
    curPos(4) = size(currFrame,1);

    minWidth = 2*curPos(3) + sum(WIDTHLIST) + 2 + GRIDSPACING*(length(WIDTHLIST)-1);
    minHeight = curPos(4) + sum(HEIGHTLIST) + 1 + 100 + GRIDSPACING*(length(HEIGHTLIST)-1);

    newPos = setFigurePosition([], 'width', minWidth, 'height', minHeight);
    if(newPos(3) ~= minWidth || newPos(4) ~= minHeight)
      logMsg('Screen not big enough for real size');
      realSize = false;
    end
    hs.mainWindow.Position = newPos;
  end
  curRatio = curPos(3)/curPos(4);
  if(curRatio > realRatio)
    newWidth = WIDTHLIST;
    newWidth(1) = -1;
    newWidth(2) = curPos(4)*realRatio;
    newWidth(4) = newWidth(2);
    newWidth(end) = -1;
    newHeight = HEIGHTLIST;
    newHeight(1) = -1;
    newHeight(2) = curPos(4);
    newHeight(end) = -1;
    set(hs.mainWindowGrid, 'Widths', newWidth, 'Heights', newHeight, 'Spacing', GRIDSPACING);
  else
    newWidth = WIDTHLIST;
    newWidth(1) = -1;
    newWidth(2) = curPos(3);
    newWidth(4) = newWidth(2);
    newWidth(end) = -1;
    newHeight = HEIGHTLIST;
    newHeight(1) = -1;
    newHeight(2) = curPos(3)/realRatio;
    newHeight(end) = -1;
    set(hs.mainWindowGrid, 'Widths', newWidth, 'Heights', newHeight, 'Spacing', GRIDSPACING);
  end
  updateImage();
end

%--------------------------------------------------------------------------
function showHistogram(hObject, ~, ~)
  currFrame = imData.CData;
  histogramFigure = figure;
  histogramFigure.Position = setFigurePosition(gcbf, 'width', 500, 'height', 300);
  histogramAxes = axes('Parent', histogramFigure);
  [ah,bh] = hist(currFrame(:), 0:histWidth:(2^BPP-1));
  histogramHandle = bar(histogramAxes,bh, ah, 1);
  %xlim(histogramAxes, [minIntensity maxIntensity]);
  xlim(histogramAxes, [min(currFrame(:)), max(currFrame(:))]);
  yl = ylim;
  hold on;
  histogramLineHandles =  plot([1, 1]*minIntensity, yl, '--');
  histogramLineHandles = [histogramLineHandles; plot([1, 1]*maxIntensity, yl, '--')];
  hold off;
  xlabel('Intensity');
  ylabel('Hits');
end

%--------------------------------------------------------------------------
function menuPreferencesROIregion(~, ~)
  curPos = vid.ROIPosition;
  prompt = {'X-offset', 'Y-offset', 'Width', 'Height'};
  dlg_title = 'Select ROI region';
  num_lines = 1;
  defaultans = {num2str(curPos(1)), num2str(curPos(2)), num2str(curPos(3)), num2str(curPos(4))};
  answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
  if(~isempty(answer))
    try
      ncbar.automatic('Please wait...');
      if(movieRunning)
        moviePreview();
        mpaused = true;
      else
        mpaused = false;
      end
      imaqreset;
      vid = videoinput(camHardware, 1, formatList{currentFormat});
      src = getselectedsource(vid);
      vid.FramesPerTrigger = 1;
      src.ExposureTime = 1/FPS;
      vid.ROIPosition = [str2num(answer{1}) str2num(answer{2}) str2num(answer{3}) str2num(answer{4})];
      ROIPosition = vid.ROIPosition;
      xlim(hs.mainWindowFramesAxes, [1 ROIPosition(3)]);
      ylim(hs.mainWindowFramesAxes, [1 ROIPosition(4)]);
      
      if(mpaused)
        moviePreview();
        autoLevelsReset = true;
        autoLevels();
      end
    catch ME
      logMsg(ME.message, hFigW, 'e');
    end
  end
  ncbar.close();
end

%--------------------------------------------------------------------------
function changeFormat(~, ~, formatName)
  if(strcmpi(formatName, formatList{currentFormat}))
    return;
  end
  if(movieRecording)
    logMsg('Cannot change format while recording', 'e');
    return;
  end
  mpaused = false;
  try
    ncbar.automatic('Please wait...');
    if(movieRunning)
      moviePreview();
      mpaused = true;
    end
    imaqreset;
    if(strcmp(camHardware, 'webcam'))
      res = strsplit(formatName,'x');
      ROIPosition(3) = str2double(res{1});
      ROIPosition(4) = str2double(res{2});
      currFrame = zeros(ROIPosition(4), ROIPosition(3));
    else
      vid = videoinput(camHardware, 1, formatName);
      src = getselectedsource(vid);
      vid.FramesPerTrigger = 1;
    end
    
    switch camHardware
      case 'hamamatsu'
        src.ExposureTime = 1/FPS;
        ROIPosition = vid.ROIPosition;
      case {'winvideo', 'macvideo'}
        src.FrameRate = availableFPS{currentFPS};
    end
  catch ME
    logMsg(ME.message, 'e');
    return;
  end
  currentFormat = find(strcmp(formatName,formatList));
  for i = 1:length(hs.menu.preferences.format.list)
    if(i ~= currentFormat)
      hs.menu.preferences.format.list(i).Checked = 'off';
    else
      hs.menu.preferences.format.list(i).Checked = 'on';
    end
  end
  if(mpaused)
    moviePreview();
    autoLevelsReset = true;
    autoLevels();
  end
  ncbar.close();
  
end

%------------------------------------------------------------------------
function rightClickMovie(hObject, ~)
  if(isempty(ROI))
    return;
  end
  
  %currentOrder = getappdata(hFigW, 'currentOrder');
  clickedPoint = get(hs.mainWindowFramesAxes,'currentpoint');
  xy = clickedPoint([1,3]);
  dist = cellfun(@(x)(sum((x.center-xy).^2)), ROI(currentOrder));
  [~, newOrder] = sort(dist);
  currentOrder = currentOrder(newOrder);
  pageChange(1);
  viewPositionsOnScreenUpdate();
%     dist = zeros(size(currentOrder));
%     for it = 1:length(currentOrder)
%       ROIxy = experiment.ROI{currentOrder(it)}.center;
%       dist(it) = sum((ROIxy-xy).^2);
%     end
    %hFigW

end

%--------------------------------------------------------------------------
function changeWinvideoFPS(~, ~, fpsValue)
 if(strcmpi(fpsValue, availableFPS{currentFPS}))
    return;
  end
  if(movieRecording)
    logMsg('Cannot change frame rate while recording', 'e');
    return;
  end
  mpaused = false;
  currentFPS = find(strcmp(fpsValue,availableFPS));
  for i = 1:length(hs.menu.preferences.fps.list)
    if(i ~= currentFPS)
      hs.menu.preferences.fps.list(i).Checked = 'off';
    else
      hs.menu.preferences.fps.list(i).Checked = 'on';
    end
  end
  try
    ncbar.automatic('Please wait...');
    if(movieRunning)
      moviePreview();
      mpaused = true;
    end
    imaqreset;
    vid = videoinput(camHardware, 1, formatList{currentFormat});
    src = getselectedsource(vid);
    vid.FramesPerTrigger = 1;
    src.FrameRate = availableFPS{currentFPS};
    FPS = str2double(src.FrameRate);
    FPStext.String = num2str(FPS);
  catch ME
    logMsg(ME.message, 'e');
    return;
  end
  if(mpaused)
    moviePreview();
    autoLevelsReset = true;
    autoLevels();
  end
  ncbar.close();
end

%--------------------------------------------------------------------------
function changeColormap(hObject, ~ ,~, varargin)
  cmapName = hObject.Label;

  % In case it comes from the menu
  mapNamePosition = strfind(cmapName, 'png">');
  if(~isempty(mapNamePosition))
    cmapName = cmapName(mapNamePosition+5:end);
  end
  colormap(cmapName);

  for i = 1:length(hs.menu.preferences.cmaps)
      hs.menu.preferences.cmaps(i).Checked = 'off';
  end
  hObject.Checked = 'on';

  updateImage();
end

%--------------------------------------------------------------------------
function traceModeSelection(~, ~, mode)
  if(nargin < 3)
    mode = traceMode;
  end
  switch mode
    case 'average'
      set(ROIimgData, 'AlphaData', zeros(size(currFrame)));
      hs.mainWindowBottomButtons.Visible = 'off';
      cla(hs.mainWindowTracesAxes);
      traceHandles = plot(hs.mainWindowTracesAxes, avgT, avgTrace);
      if(movieRecording && bufferAllTraces)
        xlim(hs.mainWindowTracesAxes,[0 experiment.ccRecordingOptionsCurrent.recordingLength]);
      else
        xlim(hs.mainWindowTracesAxes, [0 bufferSize/updateRate]);
      end
      title(hs.mainWindowTracesAxes, 'Average trace');
      xlabel(hs.mainWindowTracesAxes,'time (s)');
      ylabel(hs.mainWindowTracesAxes,'F (a.u.)');
    case 'ROI'
      if(isempty(ROI) || isempty(ROItraces))
        logMsg('No ROI available' ,'e');
        traceMode = 'average';
        return;
      end
      hs.mainWindowBottomButtons.Visible = 'on';
      cla(hs.mainWindowTracesAxes);
      traceHandles = plot(hs.mainWindowTracesAxes, t, ROItraces(:, 1:min(numberTraces, length(ROI)))');
      if(spikeDetection)
        hold(hs.mainWindowTracesAxes, 'on');
        if(~isempty(ROImodelTraces))
          modelTraceHandles = plot(hs.mainWindowTracesAxes, t, ROImodelTraces(:, 1:min(numberTraces, length(ROI)))', '--');
        end
        if(~isempty(spikes))
          spikeHandles = plot(hs.mainWindowTracesAxes, t, spikes(:, 1:min(numberTraces, length(ROI)))', 'o');
        end
        hold(hs.mainWindowTracesAxes, 'off');
      end
      if(movieRecording && bufferAllTraces)
        xlim(hs.mainWindowTracesAxes,[0 experiment.ccRecordingOptionsCurrent.recordingLength]);
      else
        xlim(hs.mainWindowTracesAxes, [0 bufferSize/updateRate]);
      end
      title(hs.mainWindowTracesAxes, sprintf('ROI traces (total ROI: %d)', length(ROI)));
      xlabel(hs.mainWindowTracesAxes,'time (s)');
      ylabel(hs.mainWindowTracesAxes,'F (a.u.)');
      pageChange();
      viewPositionsOnScreenUpdate();
  end
  traceMode = mode;
end

%--------------------------------------------------------------------------
function viewTraces(hObject, ~, mode)
  for i = 1:length(hObject.Parent.Children)
    hObject.Parent.Children(i).Checked = 'off';
  end
  hObject.Checked = 'on';
  normalizationMode = mode;
  if(strcmpi(traceMode, 'ROI'))
    pageChange();
  end
  updatePlots(true);
end

%--------------------------------------------------------------------------
function sortTraces(hObject, ~, mode)
  if(isempty(ROI))
    return;
  end
  for i = 1:length(hObject.Parent.Children)
    hObject.Parent.Children(i).Checked = 'off';
  end
  hObject.Checked = 'on';
  sortMode = mode;
  
  switch sortMode
    case 'ROI'
      currentOrder = 1:length(ROI);
    case 'Similarity'
      didIpause = pauseRecording();
      validIdx = ~isnan(ROItraces(:, 1));
      try
        [~, currentOrder, ~] = identifySimilaritiesInTraces(experiment, ...
          ROItraces(validIdx, :), 'saveSimilarityMatrix', false, 'showSimilarityMatrix', false, 'verbose', false);
      catch ME
        logMsg(ME.message, 'e');
      end
      if(didIpause)
        resumeRecording();
      end
  end
  if(strcmpi(traceMode, 'ROI'))
    pageChange();
  end
end

%--------------------------------------------------------------------------
function viewPositionsOnScreenUpdate()
  switch ROImode
    case 'all'
      selectedROI = ROI;
      ROIimg = visualizeROI(zeros(size(currFrame)), selectedROI, 'plot', false, 'color', true, 'mode','edge');
    case 'active'
      if(length(ROI) >= lastTrace)
        selectedROI = ROI(currentOrder(firstTrace:lastTrace));
        ROIimg = visualizeROI(zeros(size(currFrame)), selectedROI, 'plot', false, 'color', true, 'mode','edge', 'cmap', cmap);
      else
        ROIimg = zeros([size(currFrame), 3]);
      end
    case 'none'
      ROIimg = zeros([size(currFrame), 3]);
  end

  invalid = (ROIimg(:,:,1) == 0 & ROIimg(:,:,2) == 0 & ROIimg(:,:,3) == 0);
  alpha = ones(size(ROIimg,1), size(ROIimg,2));
  alpha(invalid) = 0;
  if(~exist('ROIimgData'))
    axes(hs.mainWindowFramesAxes);
    ROIimgData = imagesc(ones(size(currFrame)), 'HitTest', 'off');
  end
  set(ROIimgData, 'CData', ROIimg);
  set(ROIimgData, 'AlphaData', alpha);
end

%--------------------------------------------------------------------------
function previousTracesButton(hObject, ~)
  currentPage = str2double(hs.currentPageText.String);
  pageChange(currentPage-1);
  viewPositionsOnScreenUpdate();
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
function pageChange(input)
  if(isempty(ROI))
    traceMode = 'average';
    set(ROIimgData, 'AlphaData', zeros(size(currFrame)));
    return;
  end
%   didIpause = pauseRecording();
  if(nargin < 1)
    input = str2num(hs.currentPageText.String);
  end
  % Fix the bounds
  input = max(min(input, totalPages), 1);

  hs.currentPageText.String = num2str(input);
  firstTrace = 1+numberTraces*(input-1);

  totalPages = ceil(length(ROI)/numberTraces);

  hs.totalPagesText.String = ['/' num2str(totalPages)];
  lastTrace = firstTrace+numberTraces-1;
  if(lastTrace > length(ROI))
      lastTrace = length(ROI);
  end
  if(firstTrace > lastTrace)
    firstTrace = 1;
    lastTrace = firstTrace+numberTraces-1;
    hs.currentPageText.String = num2str(1);
  end
  if(lastTrace > length(ROI))
    lastTrace = length(ROI);
  end
  if(isempty(ROItraces))
    return;
  end
  %cla(hs.mainWindowTracesAxes);
  if(~all(isempty(traceHandles)))
    delete(traceHandles)
  end
  if(spikeDetection && ~all(isempty(modelTraceHandles)))
    delete(modelTraceHandles)
  end
  if(spikeDetection && ~all(isempty(spikeHandles)))
    delete(spikeHandles);
  end
  cla(hs.mainWindowTracesAxes);
  
  if(length(currentOrder) ~= length(ROI))
    currentOrder = 1:length(ROI);
    sortMode = 'ROI';
  end
  if(size(ROItraces, 2) < length(currentOrder))
    ROItraces(:, (size(ROItraces, 2)+1):length(currentOrder)) = nan;
  elseif(size(ROItraces, 2) > length(currentOrder))
    ROItraces = ROItraces(:, 1:length(currentOrder));
  end

  traceHandles = plot(hs.mainWindowTracesAxes, t, ROItraces(:, currentOrder(firstTrace:lastTrace))');
  if(spikeDetection)
    hold(hs.mainWindowTracesAxes, 'on');
    if(~isempty(ROImodelTraces))
      modelTraceHandles = plot(hs.mainWindowTracesAxes, t, ROImodelTraces(:, currentOrder(firstTrace:lastTrace))', '--');
    end
    if(~isempty(spikes))
      spikeHandles = plot(hs.mainWindowTracesAxes, t, spikes(:, currentOrder(firstTrace:lastTrace))', 'o');
    end
    hold(hs.mainWindowTracesAxes, 'off');
  end

  if(movieRecording && bufferAllTraces)
    xlim(hs.mainWindowTracesAxes,[0 experiment.ccRecordingOptionsCurrent.recordingLength]);
  else
    xlim(hs.mainWindowTracesAxes, [0 bufferSize/updateRate]);
  end
  title(hs.mainWindowTracesAxes, sprintf('ROI traces (total ROI: %d)', length(ROI)));
  xlabel(hs.mainWindowTracesAxes,'time (s)');
  ylabel(hs.mainWindowTracesAxes,'F (a.u.)');

  % Update stuff
  switch normalizationMode
    case 'together'
    case {'separated','separatedNormalized'}
      selectedTraces = currentOrder(firstTrace:lastTrace);
      xl = xlim(hs.mainWindowTracesAxes);
      hold(hs.mainWindowTracesAxes, 'on');
      for i = 1:length(traceHandles)
        plot(hs.mainWindowTracesAxes, xl, [1, 1]*(i-1), ':', 'Color', cmap(i, :));
      end
      hold(hs.mainWindowTracesAxes, 'off');
      ylim(hs.mainWindowTracesAxes, [-0.25 length(selectedTraces)+0.25]);
      ylabel(hs.mainWindowTracesAxes, 'ROI index');
      set(hs.mainWindowTracesAxes, 'YTick', (1:length(selectedTraces))-1);
      set(hs.mainWindowTracesAxes, 'YTickLabel', ROIid(selectedTraces));
  end
  updatePlots(true);
end

%--------------------------------------------------------------------------
function nextTracesButton(hObject, ~)
    currentPage = str2double(hs.currentPageText.String);
    pageChange(currentPage+1);
    viewPositionsOnScreenUpdate();
end

%--------------------------------------------------------------------------
function resetAllTraces(~, ~)
  t = nan(bufferSize, 1);
  timerT = nan(bufferSize, 1);
  avgTrace = nan(bufferSize, 1);
  avgTraceLower = [];
  avgT = nan(bufferSize, 1);
  ROItraces = nan(bufferSize, length(ROI));
  %ROImodelTraces = nan(size(ROItraces));
  %spikes = nan(size(spikes));
  traceModeSelection();
end

%--------------------------------------------------------------------------
function closeCallback(~, ~, varargin)
  runningTimers = timerfind('TimerFcn', @timerUpdate);
  if(~isempty(runningTimers))
    stop(runningTimers);
    delete(runningTimers);
  end
  runningTimers = timerfind('TimerFcn', @timerRecordingUpdate);
  if(~isempty(runningTimers))
    stop(runningTimers);
    delete(runningTimers);
  end
  switch camHardware
    case {'hamamatsu', 'winvideo', 'macvideo'}
      imaqreset;
    case 'webcam'
      delete(vid);
  end
  delete(hFigW);
end

%--------------------------------------------------------------------------
function autoLevels(h, e)
  [minIntensity, maxIntensity] = autoLevelsFIJI(currFrame, BPP, autoLevelsReset);
  if(BPP == 8 || BPP == 16)
    minIntensity = round(minIntensity);
    maxIntensity = round(maxIntensity);
    maxIntensityText.String = sprintf('%d', maxIntensity);
    minIntensityText.String = sprintf('%d', minIntensity);
  else
    maxIntensityText.String = sprintf('%.2f', maxIntensity);
    minIntensityText.String = sprintf('%.2f', minIntensity);
  end
  updateImage();
  autoLevelsReset = false;
end

%--------------------------------------------------------------------------

function detectSpikes(~, ~)
  [success, foopsiOptionsCurrent] = preloadOptions(experiment, foopsiOptions, gcbf, true, false);
  if(~success)
    return;
  end
  didIpause = pauseRecording();
  experiment.ROI = ROI;
  validIdx = ~isnan(ROItraces(:, 1));
  experiment.traces = ROItraces(validIdx, :);
  experiment.t = t(validIdx);
  experiment.fps =  1/nanmean(diff(t));
  if(isfield(experiment, 'modelTraces'))
    experiment = rmfield(experiment, 'modelTraces');
  end
  experiment = spikeInferenceFoopsi(experiment, foopsiOptionsCurrent, 'spikeRasterTrain', true, 'verbose', false);
  spikes = nan(size(ROItraces));
  spikes(validIdx, :) = experiment.spikes;
  
  %logMsg(sprintf('%d spikes detected', sum(cellfun(@length, experiment.spikes))));
  logMsg(sprintf('%d spikes detected', nansum(spikes(:))));
  experiment.foopsiOptionsCurrent = foopsiOptionsCurrent;
  if(isfield(experiment, 'modelTraces'))
    ROImodelTraces = nan(size(ROItraces));
    ROImodelTraces(validIdx, :) = experiment.modelTraces;
  else
    ROImodelTraces = nan(size(ROItraces));
  end
  spikeDetection = true;
  pageChange();
  if(didIpause)
    resumeRecording();
  end
end

%--------------------------------------------------------------------------
function menuLoadROI(~, ~)
  [fpa, ~, ~] = fileparts(appFolder);
  [fileName, pathName] = uigetfile('*', 'Select ROI file', fpa);
  fileName = [pathName fileName];
  if(~fileName | ~exist(fileName, 'file')) %#ok<BDSCI,OR2,BDLGI>
    logMsg('Invalid ROI file', 'e');
    return;
  end
  didIpause = pauseRecording();
  switch camHardware
    case {'hamamatsu', 'winvideo', 'macvideo'}
        rp = vid.ROIPosition;
        experiment.width = rp(3);
        experiment.height = rp(4);
    otherwise
      experiment.width = size(currFrame, 2);
      experiment.height = size(currFrame, 1);
  end
  try
    ROI = loadROI(experiment, fileName);
  catch
    logMsg('Looks like the ROI file might be in the new format. Updating...','w');
    ROI = loadROI(experiment, fileName, 'overwriteMode', 'rawNew');
  end
  experiment.ROI = ROI;
  displayROI();
  if(didIpause)
    resumeRecording();
  end
end

%--------------------------------------------------------------------------
function menuLoadROIcompatibility(~, ~)
  [fpa, ~, ~] = fileparts(appFolder);
  [fileName, pathName] = uigetfile('*', 'Select ROI file', fpa);
  fileName = [pathName fileName];
  if(~fileName | ~exist(fileName, 'file')) %#ok<BDSCI,OR2,BDLGI>
    logMsg('Invalid ROI file', 'e');
    return;
  end
  didIpause = pauseRecording();
  switch camHardware
    case {'hamamatsu', 'winvideo', 'macvideo'}
        rp = vid.ROIPosition;
        experiment.width = rp(3);
        experiment.height = rp(4);
    otherwise
      experiment.width = size(currFrame, 2);
      experiment.height = size(currFrame, 1);
  end
  ROI = loadROI(experiment, fileName, 'overwriteMode', 'rawNew');

  experiment.ROI = ROI;
  displayROI();
  if(didIpause)
    resumeRecording();
  end
end

%--------------------------------------------------------------------------
function menuSaveROI(~, ~)
  didIpause = pauseRecording();
  if(~isfield(experiment, 'folder'))
    experiment.folder = [currFolder filesep];
  end
  switch camHardware
    case {'hamamatsu', 'winvideo', 'macvideo'}
        rp = vid.ROIPosition;
        experiment.width = rp(3);
        experiment.height = rp(4);
  end
  %appFolder
  %experiment.folder
  %currFolder
  if(~isfield(experiment, 'name'))
    experiment.name = 'recording';
  end
  saveROI(experiment, ROI);
  [fpa, ~, ~] = fileparts(experiment.folder);
  currFolder = fpa;
  if(didIpause)
    resumeRecording();
  end
end


%--------------------------------------------------------------------------
function autoROI(~, ~)
  [success, ROIautomaticOptionsCurrent] = preloadOptions(experiment, ROIautomaticOptions, gui, true, false);
  if(~success)
    return;
  end
  didIpause = pauseRecording();
  ROI = autoDetectROI(currFrame, ROIautomaticOptionsCurrent);
  logMsg([num2str(length(ROI)) ' ROI generated']);
  if(isempty(ROI))
    resumeRecording();
    return;
  end
  experiment.ROIautomaticOptionsCurrent = ROIautomaticOptionsCurrent;
  experiment.ROI = ROI;
  displayROI();
  if(didIpause)
    resumeRecording();
  end
  logMsg([num2str(length(ROI)) ' ROI generated']);
end

%--------------------------------------------------------------------------
function menuDelete(~, ~, ~)
  delete(plotHandleList);
  hold on;
  plotHandleList = [];

  coordList = [];
  while(1)
      x = []; %#ok<NASGU>
      [x, y, bt] = ginput(1);
      if(isempty(x) || bt == 27)
          break;
      end

      for j = 1:length(x)
          coord = floor([x(j), y(j)]);
          coordList = [coordList; coord];
          plotHandleList = [plotHandleList; plot(coord(1), coord(2), 'rx')];
      end
  end
  didIpause = pauseRecording();
  deleted = false;
  deletedCount = 0;
  for j = 1:size(coordList,1)
      mask = zeros(size(currFrame));
      coord = floor([coordList(j,1), coordList(j,2)]);
      mask(coord(2), coord(1)) = 1;
      B = bwconncomp(mask);
      px = B.PixelIdxList{1}';
      for i = 1:length(ROI)
          if(any(ROI{i}.pixels == px))
              ROI(i) = [];
              deleted = true;
              deletedCount = deletedCount + 1;
              break;
          end
      end
      %ROI{i+ROIoffset}.ID = i+ROIoffset;
      %ROI{i+ROIoffset}.pixels = B.PixelIdxList{i}';
  end
  if(deleted)
      displayROI();
      logMsg([num2str(deletedCount) ' ROI deleted']);
      logMsg([num2str(length(ROI)) ' ROI present']);
  end
  delete(plotHandleList);
  hold on;
  plotHandleList = [];
  if(didIpause)
    resumeRecording();
  end
end

%--------------------------------------------------------------------------
function menuDeleteArea(~, ~, ~)
  h = imrect;
  pos = getPosition(h);
  pos = round(pos);
  x_range = pos(1):(pos(1)+pos(3));
  y_range = pos(2):(pos(2)+pos(4));
  plist = zeros(length(x_range)*length(y_range), 2);
  it = 0;
  for ii = 1:length(x_range)
      for j = 1:length(y_range)
          it = it + 1;
          plist(it, :) = [x_range(ii) y_range(j)];
      end
  end
  pixelList = sub2ind(size(currFrame), plist(:,2), plist(:,1));
  invalid = [];
  for it = 1:length(ROI)
     if(any(ismember(ROI{it}.pixels, pixelList)))
         invalid = [invalid; it];
     end
  end
  didIpause = pauseRecording();
  ROI(invalid) = [];
  delete(h);
  if(~isempty(invalid))
      displayROI();
      logMsg([num2str(length(invalid)) ' ROI deleted']);
      logMsg([num2str(length(ROI)) ' ROI present']);
  end
  if(didIpause)
    resumeRecording();
  end
end

%--------------------------------------------------------------------------
function menuPreferencesNumberTraces(~, ~)
  answer = inputdlg({'Number of visible ROI traces'}, 'N traces', [1 60], {num2str(numberTraces)});
  if(isempty(answer))
    return;
  end
  numberTraces = str2num(strtrim(answer{1}));
  resetROItraces();
end

%--------------------------------------------------------------------------
function menuCircle2(~, ~, ~)
    delete(plotHandleList);
    hold on;
    plotHandleList = [];

    p = [];
    for i = 1:2
        [x, y, bt] = ginput(1);
        if(isempty(x) || bt == 27)
            break;
        end
        p = [p; x, y];
        plotHandleList = [plotHandleList; plot(x, y, 'rx')];
    end
    center = p(1, :);
    radius = sqrt(sum((p(2,:)-p(1,:)).^2));
    x_min = round(center(1) - radius);
    x_max = round(center(1) + radius);
    y_min = round(center(2) - radius);
    y_max = round(center(2) + radius);
    %rows = 16+1;
    %cols = 16+1;
    answer = inputdlg({'rows', 'columns'}, 'Grid selection', [1 60], {'8', '8'});
    if(isempty(answer))
        return;
    end
    rows = str2double(answer{1})+1;
    cols = str2double(answer{2})+1;
    [x,y] = meshgrid(round(linspace(x_min, x_max, cols)), round(linspace(y_min, y_max, rows)));
    ROIsize = (x(1,2)-x(1,1)+1)*(y(2,1)-y(1,1)+1);
    ROI = cell((rows-1)*(cols-1), 1);
    idx = 0;
    invalid = [];
    for i = 1:(size(x,1)-1)
        for j = 1:(size(x,2)-1)
            idx = idx + 1;
            x_range = x(i,j):(x(i,j+1)-1);
            y_range = y(i,j):(y(i+1,j)-1);
            [tx, ty] = meshgrid(x_range, y_range);
            pixelList = [tx(:) ty(:)];
            valid = find((pixelList(:,1) - center(1)).^2 + (pixelList(:,2) - center(2)).^2 <= radius.^2 & pixelList(:,1) >= 1 & pixelList(:,1) <= size(currFrame, 2) & pixelList(:,2) >= 1 & pixelList(:,2) <= size(currFrame, 1));
            if(~isempty(valid) && length(valid) >= ROIsize/5)
                pixelList = sub2ind(size(currFrame), pixelList(valid,2), pixelList(valid,1));
                ROI{idx}.ID = idx;
                ROI{idx}.pixels = pixelList';
                [yb, xb] = ind2sub(size(currFrame), ROI{idx}.pixels(:));
                ROI{idx}.center = [mean(xb), mean(yb)];
                ROI{idx}.maxDistance = max(sqrt((ROI{idx}.center(1)-xb).^2+(ROI{idx}.center(2)-yb).^2));
            else
                invalid = [invalid; idx];
            end
        end
    end
    ROI(invalid) = [];
    displayROI();
    logMsg([num2str(length(ROI)) ' ROI generated']);
end

%--------------------------------------------------------------------------
function menuCircle3(~, ~, ~)
    delete(plotHandleList);
    hold on;
    plotHandleList = [];

    p = [];
    for i = 1:3
        [x, y, bt] = ginput(1);
        if(isempty(x) || bt == 27)
            break;
        end
        p = [p; x, y];
        plotHandleList = [plotHandleList; plot(x, y, 'rx')];
    end
    [center, radius] = calcCircle(p(1,:), p(2,:), p(3,:));
    x_min = round(center(1) - radius);
    x_max = round(center(1) + radius);
    y_min = round(center(2) - radius);
    y_max = round(center(2) + radius);
    %rows = 16+1;
    %cols = 16+1;
    answer = inputdlg({'rows', 'columns'}, 'Grid selection', [1 60], {'8', '8'});
    if(isempty(answer))
        return;
    end
    rows = str2double(answer{1})+1;
    cols = str2double(answer{2})+1;
    [x,y] = meshgrid(round(linspace(x_min, x_max, cols)), round(linspace(y_min, y_max, rows)));
    ROIsize = (x(1,2)-x(1,1)+1)*(y(2,1)-y(1,1)+1);
    ROI = cell((rows-1)*(cols-1), 1);
    idx = 0;
    invalid = [];
    for i = 1:(size(x,1)-1)
        for j = 1:(size(x,2)-1)
            idx = idx + 1;
            x_range = x(i,j):(x(i,j+1)-1);
            y_range = y(i,j):(y(i+1,j)-1);
            [tx, ty] = meshgrid(x_range, y_range);
            pixelList = [tx(:) ty(:)];
            valid = find((pixelList(:,1) - center(1)).^2 + (pixelList(:,2) - center(2)).^2 <= radius.^2 & pixelList(:,1) >= 1 & pixelList(:,1) <= size(currFrame, 2) & pixelList(:,2) >= 1 & pixelList(:,2) <= size(currFrame, 1));
            if(~isempty(valid) && length(valid) >= ROIsize/5)
                pixelList = sub2ind(size(currFrame), pixelList(valid,2), pixelList(valid,1));
                ROI{idx}.ID = idx;
                ROI{idx}.pixels = pixelList';
                [yb, xb] = ind2sub(size(currFrame), ROI{idx}.pixels(:));
                ROI{idx}.center = [mean(xb), mean(yb)];
                ROI{idx}.maxDistance = max(sqrt((ROI{idx}.center(1)-xb).^2+(ROI{idx}.center(2)-yb).^2));
            else
                invalid = [invalid; idx];
            end
        end
    end
    ROI(invalid) = [];
 
    displayROI();
    logMsg([num2str(length(ROI)) ' ROI generated']);
end

%--------------------------------------------------------------------------
function menuRectangleFull(~, ~, ~)
    x_min = 1;
    x_max = size(currFrame, 2);
    y_min = 1;
    y_max = size(currFrame, 1);
    
    answer = inputdlg({'rows', 'columns'}, 'Grid selection', [1 60], {'8', '8'});
    if(isempty(answer))
        return;
    end
    didIpause = pauseRecording();
    rows = str2double(answer{1})+1;
    cols = str2double(answer{2})+1;
    [x,y] = meshgrid(round(linspace(x_min, x_max, cols)), round(linspace(y_min, y_max, rows)));
    ROIsize = (x(1,2)-x(1,1)+1)*(y(2,1)-y(1,1)+1);
    ROI = cell((rows-1)*(cols-1), 1);
    idx = 0;
    invalid = [];
    for i = 1:(size(x,1)-1)
        for j = 1:(size(x,2)-1)
            idx = idx + 1;
            x_range = x(i,j):(x(i,j+1)-1);
            y_range = y(i,j):(y(i+1,j)-1);
            [tx, ty] = meshgrid(x_range, y_range);
            pixelList = [tx(:) ty(:)];
            valid = find(pixelList(:,1) >= 1 & pixelList(:,1) <= size(currFrame, 2) & pixelList(:,2) >= 1 & pixelList(:,2) <= size(currFrame, 1));
            if(~isempty(valid) && length(valid) >= ROIsize/5)
                pixelList = sub2ind(size(currFrame), pixelList(valid,2), pixelList(valid,1));
                ROI{idx}.ID = idx;
                ROI{idx}.pixels = pixelList';
                [yb, xb] = ind2sub(size(currFrame), ROI{idx}.pixels(:));
                ROI{idx}.center = [mean(xb), mean(yb)];
                ROI{idx}.maxDistance = max(sqrt((ROI{idx}.center(1)-xb).^2+(ROI{idx}.center(2)-yb).^2));
            else
                invalid = [invalid; idx];
            end
        end
    end
    ROI(invalid) = [];
    displayROI();
    logMsg([num2str(length(ROI)) ' ROI generated']);
    if(didIpause)
      resumeRecording();
    end
end

%--------------------------------------------------------------------------
function menuRectangleRegion(~, ~, ~)
    delete(plotHandleList);
    hold on;
    plotHandleList = [];

    h = imrect;
    pos = getPosition(h);
    pos = round(pos);
    delete(h);
    x_min = pos(1);
    x_max = pos(1) + pos(3);
    y_min = pos(2);
    y_max = pos(2) + pos(4);
    
    answer = inputdlg({'rows', 'columns'}, 'Grid selection', [1 60], {'8', '8'});
    if(isempty(answer))
        return;
    end
    rows = str2double(answer{1})+1;
    cols = str2double(answer{2})+1;
    [x,y] = meshgrid(round(linspace(x_min, x_max, cols)), round(linspace(y_min, y_max, rows)));
    ROIsize = (x(1,2)-x(1,1)+1)*(y(2,1)-y(1,1)+1);
    ROI = cell((rows-1)*(cols-1), 1);
    idx = 0;
    invalid = [];
    for i = 1:(size(x,1)-1)
        for j = 1:(size(x,2)-1)
            idx = idx + 1;
            x_range = x(i,j):(x(i,j+1)-1);
            y_range = y(i,j):(y(i+1,j)-1);
            [tx, ty] = meshgrid(x_range, y_range);
            pixelList = [tx(:) ty(:)];
            valid = find(pixelList(:,1) >= 1 & pixelList(:,1) <= size(currFrame, 2) & pixelList(:,2) >= 1 & pixelList(:,2) <= size(currFrame, 1));
            if(~isempty(valid) && length(valid) >= ROIsize/5)
                pixelList = sub2ind(size(currFrame), pixelList(valid,2), pixelList(valid,1));
                ROI{idx}.ID = idx;
                ROI{idx}.pixels = pixelList';
                [yb, xb] = ind2sub(size(currFrame), ROI{idx}.pixels(:));
                ROI{idx}.center = [mean(xb), mean(yb)];
                ROI{idx}.maxDistance = max(sqrt((ROI{idx}.center(1)-xb).^2+(ROI{idx}.center(2)-yb).^2));
            else
                invalid = [invalid; idx];
            end
        end
    end
    ROI(invalid) = [];
    
    displayROI();
    logMsg([num2str(length(ROI)) ' ROI generated']);
end

%--------------------------------------------------------------------------
function menuMoveROI(~, ~)
    answer = inputdlg({'Pixel displacement in X (columns, negative to the left)','Pixel displacement in Y (rows, negative for up)'}, 'Move ROI', [1 60],{'0','0'});
    if(isempty(answer))
        return;
    end
    %[answer{1} answer{2}]
    for idx = 1:length(ROI)
        [row, col] = ind2sub(size(currFrame), ROI{idx}.pixels);
        row = row+str2double(answer{2});
        col = col+str2double(answer{1});
        row(row < 1) = 1;
        col(col < 1) = 1;
        row(row > size(currFrame, 1)) = size(currFrame, 1);
        col(col > size(currFrame, 2)) = size(currFrame, 2);
        pixelList = sub2ind(size(currFrame), row, col);
        ROI{idx}.pixels = pixelList';
        ROI{idx}.center = [mean(col), mean(row)];
        ROI{idx}.maxDistance = max(sqrt((ROI{idx}.center(1)-col).^2+(ROI{idx}.center(2)-row).^2));
    end
    
    displayROI();
end

%--------------------------------------------------------------------------
function activeROIButton(~, ~)
  changeSelectionMode('normal');

  delete(plotHandleList);
  hold on;
  plotHandleList = [];
  I = uint16(currFrame);
  %L = false(size(I));
  coordList = [];
  while(1)
      x = []; %#ok<NASGU>
      [x, y, bt] = ginput(1);
      if(isempty(x) || bt == 27)
          break;
      end
      %mask = false(size(I));
      for j = 1:length(x)
          coord = floor([x(j), y(j)]);
          coordList = [coordList; coord];
          plotHandleList = [plotHandleList; plot(coord(1), coord(2), 'rx')];
      end
  end
  if(isempty(coordList))
      return;
  end
  mask = false(size(I));
  for j = 1:size(coordList,1)
      coord = floor([coordList(j,1), coordList(j,2)]);
      mask(coord(2)-experiment.ROIselectionOptionsCurrent.sizeActiveContour/2:coord(2)+experiment.ROIselectionOptionsCurrent.sizeActiveContour/2, coord(1)-experiment.ROIselectionOptionsCurrent.sizeActiveContour/2:coord(1)+experiment.ROIselectionOptionsCurrent.sizeActiveContour/2) = 1;
  end

  bw = activecontour(I,mask);
  %L = L + bw;
%     B = bwboundaries(bw);
%     for i = 1:length(B)
%         plotHandleList = [plotHandleList; plot(B{i}(:,2), B{i}(:,1), 'r')];
%     end

   B = bwconncomp(bw);
   %ROI = cell(B.NumObjects, 1);
   ROIoffset = length(ROI);
   didIpause = pauseRecording();
   ROI = [ROI(:)' cell(B.NumObjects, 1)']';
   for i = 1:B.NumObjects
       ROI{i+ROIoffset}.ID = i+ROIoffset;
       ROI{i+ROIoffset}.pixels = B.PixelIdxList{i}';
       [y, x] = ind2sub(size(I), ROI{i+ROIoffset}.pixels);
       ROI{i+ROIoffset}.center = [mean(x), mean(y)];
       ROI{i+ROIoffset}.maxDistance = max(sqrt((ROI{i+ROIoffset}.center(1)-x).^2+(ROI{i+ROIoffset}.center(2)-y).^2));
   end

  displayROI();
  logMsg([num2str(B.NumObjects) ' ROI added']);
  logMsg([num2str(length(ROI)) ' ROI present']);
  delete(plotHandleList);
  hold on;
  plotHandleList = [];
  if(didIpause)
    resumeRecording();
  end
end

%--------------------------------------------------------------------------
function menuClear(~, ~, ~)
  didIpause = pauseRecording();
  hold off;
  cla(hs.mainWindowFramesAxes);
  axes(hs.mainWindowFramesAxes);
  imData = imagesc(currFrame, 'HitTest', 'on');
  axis equal tight;
  maxIntensity = max(currFrame(:));
  minIntensity = min(currFrame(:));
  set(hs.mainWindowFramesAxes, 'XTick', []);
  set(hs.mainWindowFramesAxes, 'YTick', []);
  set(hs.mainWindowFramesAxes, 'LooseInset', [0,0,0,0]);
  box on;
  hold on;
  %if(~exist('ROIimgData'))
  ROIimgData = imagesc(ones(size(currFrame)), 'HitTest', 'off');
  %end
  valid = zeros(size(currFrame));
  set(ROIimgData, 'AlphaData', valid);

  ROI = [];
  displayROI();
  logMsg('ROI cleared');
  if(didIpause)
    resumeRecording();
  end
  hs.roiMenu.root = uicontextmenu;
  hs.roiMenu.sortROI = uimenu(hs.roiMenu.root, 'Label','Sort ROI by distance', 'Callback', @rightClickMovie);
  hs.mainWindowFramesAxes.UIContextMenu = hs.roiMenu.root;
end

%--------------------------------------------------------------------------
function ROIWindowButtonMotionFcn(~, ~, ~)
    hObj = hittest(gcf);
    if(isa(hObj, 'matlab.graphics.primitive.Image'))
        %set(gcf,'Pointer','cross');
        %cursorHandle
        if(strcmp(selectionMode, 'circle'))
            C = get (gca, 'CurrentPoint');
            x = C(1,1);
            y = C(1,2);
            if(~isempty(cursorHandle))
                delete(cursorHandle)
                cursorHandle = [];
            end
            r = ROIselectionOptionsCurrent.sizeManual/2;
            if(x >= 1+r && x <= size(currFrame, 2)-r && y >= 1+r && y <= size(currFrame, 1)-r)
                theta = linspace(0,2*pi, 100);
                hold on;
                cursorHandle = plot(x+r*cos(theta), y+r*sin(theta), 'r', 'LineWidth', 2);
            end
        elseif(strcmp(selectionMode, 'square'))
            C = get (gca, 'CurrentPoint');
            x = C(1,1);
            y = C(1,2);
            if(~isempty(cursorHandle))
                delete(cursorHandle)
                cursorHandle = [];
            end
            r = ROIselectionOptionsCurrent.sizeManual/2;
            if(x >= 1+r && x <= size(currFrame, 2)-r && y >= 1+r && y <= size(currFrame, 1)-r)
                hold on;
                cursorHandle = rectangle('Position', [x-r, y-r, 2*r, 2*r], 'LineWidth', 2, 'EdgeColor', 'r');
            end

        end

    else
        %set(gcf,'Pointer','arrow');
    end
end

%--------------------------------------------------------------------------
function hotkeyPan(~, ~, ~)
    changeSelectionMode('normal');
    pan;
    
end

%--------------------------------------------------------------------------
function preferences(~, ~)
  [success, ROIselectionOptionsCurrent] = preloadOptions(experiment, ROIselectionOptions, gui, true, false);
  if(success)
    experiment.ROIselectionOptionsCurrent = ROIselectionOptionsCurrent;
  end
end

%--------------------------------------------------------------------------
function resetFrame()
  cla(hs.mainWindowFramesAxes);
  axes(hs.mainWindowFramesAxes);
  if(isempty(ROIPosition))
    ROIPosition(3) = size(currFrame,2);
    ROIPosition(4) = size(currFrame,1);
  end
  currFrame = zeros(ROIPosition(4), ROIPosition(3));
  
  imData = imagesc(currFrame, 'HitTest', 'on');
  axis equal tight;
  maxIntensity = max(currFrame(:));
  minIntensity = min(currFrame(:));
  set(hs.mainWindowFramesAxes, 'XTick', []);
  set(hs.mainWindowFramesAxes, 'YTick', []);
  set(hs.mainWindowFramesAxes, 'LooseInset', [0,0,0,0]);
  box on;
  hold on;
  %if(~exist('ROIimgData'))
    ROIimgData = imagesc(ones(size(currFrame)), 'HitTest', 'off');
  %end
  valid = zeros(size(currFrame));
  set(ROIimgData, 'AlphaData', valid);

  hs.roiMenu.root = uicontextmenu;
  hs.roiMenu.sortROI = uimenu(hs.roiMenu.root, 'Label','Sort ROI by distance', 'Callback', @rightClickMovie);
  hs.mainWindowFramesAxes.UIContextMenu = hs.roiMenu.root;

end

%--------------------------------------------------------------------------
function addSquare(~, ~, ~)
  changeSelectionMode('square');
  delete(plotHandleList);
  hold on;
  plotHandleList = [];
  I = uint16(currFrame);
  %L = false(size(I));
  coordList = [];
  addCount = 0;
  while(1)
      x = []; %#ok<NASGU>
      h = impoint;
      if(isempty(h))
          break;
      end
      pos = h.getPosition();
      x = pos(1);
      y = pos(2);
      delete(h);
      didIpause = pauseRecording();
      for j = 1:length(x)
          coord = floor([x(j), y(j)]);
          coordList = [coordList; coord];
          r = ROIselectionOptionsCurrent.sizeManual/2;
          if(x >= 1+r && x <= size(currFrame, 2)-r && y >= 1+r && y <= size(currFrame, 1)-r)
              % Add the ROI
              plotHandleList = [plotHandleList; rectangle('Position', [x-r, y-r, 2*r, 2*r], 'LineWidth', 2, 'EdgeColor', 'r')];
              mask = zeros(size(currFrame));
              mask(round(y-r):round(y+r), round(x-r):round(x+r)) = 1;
              B = bwconncomp(mask);
              ROI = [ROI(:)' cell(1)']';
              ROI{end}.ID = length(ROI);
              ROI{end}.pixels = B.PixelIdxList{1}';
              [y, x] = ind2sub(size(I), ROI{end}.pixels);
              ROI{end}.center = [x, y];
              ROI{end}.maxDistance = max(sqrt((ROI{end}.center(1)-x).^2+(ROI{end}.center(2)-y).^2));
              addCount = addCount + 1;
          end
      end
      if(didIpause)
        resumeRecording();
      end
  end
  changeSelectionMode('normal');
end

%--------------------------------------------------------------------------
function addCircle(~, ~, ~)
    changeSelectionMode('circle');
    
    delete(plotHandleList);
    hold on;
    plotHandleList = [];
    I = uint16(currFrame);
    %L = false(size(I));
    coordList = [];
    theta = linspace(0,2*pi, 50);
    r = ROIselectionOptionsCurrent.sizeManual/2;
    [gridX, gridY] = meshgrid(1:size(currFrame,2), 1:size(currFrame, 1));
    addCount = 0;
    while(1)
        x = []; %#ok<NASGU>
        h = impoint;
        if(isempty(h))
            break;
        end
        pos = h.getPosition();
        x = pos(1);
        y = pos(2);
        delete(h);
        didIpause = pauseRecording();
        for j = 1:length(x)
            coord = floor([x(j), y(j)]);
            coordList = [coordList; coord];
            if(x >= 1+r && x <= size(currFrame, 2)-r && y >= 1+r && y <= size(currFrame, 1)-r)
                % Add the ROI
                plotHandleList = [plotHandleList; plot(x+r*cos(theta), y+r*sin(theta), 'r', 'LineWidth', 2)];
                mask = zeros(size(currFrame));
                
                mask((gridX-x).^2+(gridY-y).^2 <= r.^2) = 1;
                B = bwconncomp(mask);
                ROI = [ROI(:)' cell(1)']';
                ROI{end}.ID = length(ROI);
                ROI{end}.pixels = B.PixelIdxList{1}';
                [y, x] = ind2sub(size(I), ROI{end}.pixels);
                ROI{end}.center = [x, y];
                ROI{end}.maxDistance = max(sqrt((ROI{end}.center(1)-x).^2+(ROI{end}.center(2)-y).^2));
                addCount = addCount + 1;
            end
        end
        if(didIpause)
          resumeRecording();
        end
    end
    changeSelectionMode('normal');
end

%--------------------------------------------------------------------------
function showROImode(~, ~, mode)
  ROImode = mode;
  ROIid = getROIid(ROI);
  viewPositionsOnScreenUpdate();
end


%--------------------------------------------------------------------------
function displayROI(varargin)
  if(isempty(ROI))
    traceMode = 'average';
    set(ROIimgData, 'AlphaData', zeros(size(currFrame)));
    traceModeSelection();
    return;
  end
  ROIid = getROIid(ROI);
  didIpause = pauseRecording();
  resetROItraces();
  sortTraces(hs.menu.traces.sort.ROI, [], 'ROI');
  if(isempty(varargin))
      mode = 'fast';
  else
      mode = varargin{1};
  end
  ncbar.automatic('Plotting ROI...');
  newImg = currFrame;
  ROIimg = visualizeROI(zeros(size(newImg)), ROI, 'plot', false, 'color', true, 'mode', mode);
  if(strcmp(mode, 'fast'))
      nROIimg = bwperim(sum(ROIimg,3) > 0);
      nROIimg = cat(3, nROIimg, nROIimg, nROIimg);
      ROIimg(~nROIimg) = ROIimg(~nROIimg)*0.25;
      ROIimg(nROIimg) = ROIimg(nROIimg)*2;
      ROIimg(ROIimg > 255) = 255;
      invalid = (ROIimg(:,:,1) == 0 & ROIimg(:,:,2) == 0 & ROIimg(:,:,3) == 0);
      alpha = ones(size(ROIimg,1), size(ROIimg,2))*0.5;
  else
      invalid = (ROIimg(:,:,1) == 0 & ROIimg(:,:,2) == 0 & ROIimg(:,:,3) == 0);
      alpha = ones(size(ROIimg,1), size(ROIimg,2))*0.25;
  end
  alpha(invalid) = 0;
  ncbar.close();
  if(~exist('ROIimgData'))
    axes(hs.mainWindowFramesAxes);
    ROIimgData = imagesc(ones(size(currFrame)), 'HitTest', 'off');
  end
  set(ROIimgData, 'CData', ROIimg);
  set(ROIimgData, 'AlphaData', alpha);
  updateImage();
  if(didIpause)
    resumeRecording();
  end
end

%--------------------------------------------------------------------------
function moviePreview(~, ~)
  disableTraceUpdates = false;
  if(movieRecording)
    logMsg('Stop recording first', 'e');
    return;
  end
  if(~movieRunning)
    switch camHardware
      case {'hamamatsu', 'winvideo', 'macvideo'}
        if(isempty(currFrame))
          currFrame = zeros(64);
        end
        resetFrame();
        ncbar.automatic('Initializing recording...');
        stop(mainTimer);
        stop(vid);
        triggerconfig(vid, 'Manual')
        vid.FramesPerTrigger = 1000;
        flushdata(vid);
        resetAllTraces();
        timerT = nan(size(timerT));
        start(vid);
        pause(ceil(1/FPS)*2);
        ncbar.close();
      case 'webcam'
        stop(mainTimer);
        delete(vid);
        resetFrame();
        ncbar.automatic('Initializing recording...');
        vid = webcam;
        vid.Resolution = formatList{currentFormat};
        res = strsplit(vid.Resolution,'x');
        ROIPosition(3) = str2double(res{1});
        ROIPosition(4) = str2double(res{2});
        currFrame = zeros(ROIPosition(4), ROIPosition(3));
        pause(ceil(1/FPS)*2);
        ncbar.close();
    end
    updateRate = maxScreenFrameRate;
    xlim(hs.mainWindowTracesAxes, [0 bufferSize/updateRate]);
    movieRunning = true;
    plotPeriod =  1/maxScreenFrameRate;
    mainTimer.Period = plotPeriod;
    start(mainTimer);
    frameIterator = 0;
    paused = false;
    moviePreviewButton.String = 'Stop preview';
  else
    movieRunning = false;
    stop(mainTimer);
    switch camHardware
      case {'hamamatsu', 'winvideo', 'macvideo'}
        stop(vid);
      case 'webcam'
        delete(vid);
    end
    paused = false;
    moviePreviewButton.String = 'Start preview';
  end
end

%--------------------------------------------------------------------------
function movieRecord(~, ~)
  if(movieRunning)
    logMsg('Stop preview first', 'e');
    return;
  end
  if(~movieRecording)
    switch camHardware
      case {'hamamatsu', 'winvideo', 'macvideo'}
        ncbar.automatic('Initializing recording...');
        stop(mainTimer);
        stop(recordingTimer);
        stop(vid);
        triggerconfig(vid, 'Immediate')
        if(multiDriveMode)
          clear futures;
          delete(gcp('nocreate'));
          parpool('local', round(str2double(experiment.ccRecordingOptionsCurrent.numberOfDrives)));
        end
        % Let's gather values from the options class
        % Experiment name and folder
        [fpa, fpb, fpc] = fileparts(experiment.ccRecordingOptionsCurrent.recordingName);
        experiment.name = fpb;
        saveMovie = experiment.ccRecordingOptionsCurrent.saveMovie;
        disableTraceUpdates = experiment.ccRecordingOptionsCurrent.disableTraceUpdates;
        if(saveMovie)
          outputVideoFile = [experiment.name '.bin'];
          %outputMetadataFile = [experiment.name '_metadata.txt'];
          experiment.handle = fullfile(fpa, outputVideoFile);
        else
          experiment.handle = '';
        end
        experiment.folder = [fpa filesep];
        % The FPS
        if(strcmp(camHardware, 'hamamatsu'))
          FPS = experiment.ccRecordingOptionsCurrent.FPS;
          FPStext.String = num2str(FPS);
          src.ExposureTime = 1/FPS;
        elseif(strcmp(camHardware, 'winvideo') || strcmp(camHardware, 'macvideo'))
          src.FrameRate = availableFPS{currentFPS};
          FPS = str2double(src.FrameRate);
        end
        % The length
        recordingLengthText.String = num2str(experiment.ccRecordingOptionsCurrent.recordingLength);
        % Other options
        bufferAllTraces = experiment.ccRecordingOptionsCurrent.bufferAllTraces;
        
        % Let's try single trigger with all the frames
        recordingLength = str2double(recordingLengthText.String);
        totalFrames = round(recordingLength*FPS);
        rp = vid.ROIPosition;
        experiment.width = rp(3);
        experiment.height = rp(4);
        avgImg = zeros(experiment.height, experiment.width);
        vid.FramesPerTrigger = totalFrames;
        % Get frames every second - as long as the FPS is above 10
        %vid.FramesAcquiredFcnCount = max(FPS/maxScreenFrameRate, 1);
        %vid.FramesAcquiredFcn = @framesObtainedCallback;
        vid.StopFcn = @stopRecording;
        if(~disableTraceUpdates)
          if(bufferAllTraces)
            bufferSize = totalFrames;
            if(~isempty(ROI))
              %experiment.rawTraces = nan(totalFrames, length(experiment.ROI));
              ROItraces = nan(ceil(totalFrames/experiment.ccRecordingOptionsCurrent.recordingFrameRateStepSize), length(ROI));
            end
            t = nan(ceil(totalFrames/experiment.ccRecordingOptionsCurrent.recordingFrameRateStepSize), 1);
          else
            t = nan(bufferSize, 1);
            ROItraces = nan(bufferSize, length(ROI));
          end
          avgT = nan(totalFrames, 1);
          avgTrace = nan(totalFrames, 1);

          if(experiment.ccRecordingOptionsCurrent.computeLowerPercentileTrace)
            avgTraceLower = zeros(totalFrames, 1);
            lowerPercentilePixel = round(experiment.height*experiment.width/100*experiment.ccRecordingOptionsCurrent.lowerPercentile);
            if(lowerPercentilePixel < 1)
              lowerPercentilePixel = 1;
            end
          end
        end
        % Prepare the outputfile
        if(saveMovie)
          curVidFile = fullfile(fpa,outputVideoFile);
          % Check for duplicate names
          numericTag = [];
          validName = false;
          while(~validName)
            validName = true;
            if(exist(fullfile(fpa, [fpb num2str(numericTag) '.bin']), 'file'))
              validName = false;
              if(isempty(numericTag))
                numericTag = 1;
              else
                numericTag = numericTag + 1;
              end
            end
          end
          if(~isempty(numericTag))
            curVidFile = fullfile(fpa, [fpb num2str(numericTag) '.bin']);
            experiment.handle = fullfile(fpa,[fpb num2str(numericTag) '.bin']);
            experiment.name = [fpb num2str(numericTag)];
            logMsg(sprintf('Found duplicate recording name. Using %s instead', curVidFile), hFigW, 'w');
          end
          if(round(str2double(experiment.ccRecordingOptionsCurrent.numberOfDrives)) > 1)
            multiDriveMode = true;
            multiIteration = 0;
            numberOfDrives = round(str2double(experiment.ccRecordingOptionsCurrent.numberOfDrives));
            currentDrive = numberOfDrives; % Since for hte first frame we already add +1
          else
            multiDriveMode = false;
            numberOfDrives = 1;
            currentDrive = 1;
          end
          if(~multiDriveMode)
            videoFileID = fopen(curVidFile, 'W');
          else
            % Let's create the file identifiers for the other drives
            [fpa, fpb, fpc] = fileparts(curVidFile);
            clear videoFileID;
            videoFileID{1} = curVidFile;
            %videoFileID(1) = fopen(curVidFile, 'W');
            %videoFileID{1} = java.io.DataOutputStream(java.io.FileOutputStream(curVidFile));
            
            experiment.multiDriveHandle{1} = curVidFile;
            for it = 2:numberOfDrives
              switch it
                case 2
                  curDrive = experiment.ccRecordingOptionsCurrent.secondDriveFolder;
                case 3
                  curDrive = experiment.ccRecordingOptionsCurrent.thirdDriveFolder;
                case 4
                  curDrive = experiment.ccRecordingOptionsCurrent.fourthDriveFolder;
              end
              tmpFile = [curDrive, filesep, fpb, '_' num2str(it) fpc];
              experiment.multiDriveHandle{it} = tmpFile;
              experiment.multiDriveMode = true;
              %videoFileID(it) = fopen(tmpFile, 'W');
              videoFileID{it} = tmpFile;
              %videoFileID{it} = java.io.DataOutputStream(java.io.FileOutputStream(tmpFile));
            end
            driveFrameIndex = zeros(totalFrames, 1);
            driveFramePosition = zeros(totalFrames, 1);
            driveCurrentFrame = zeros(numberOfDrives, 1);
          end
        end
        updateRate = FPS;
        if(~disableTraceUpdates)
          if(~bufferAllTraces)
            xlim(hs.mainWindowTracesAxes, [0 bufferSize/updateRate]);
          else
            xlim(hs.mainWindowTracesAxes,[0 experiment.ccRecordingOptionsCurrent.recordingLength]);
          end
        end
        %%% Let's add the experiment already in case something crashes, so
        %%% it can be recovered later on
        if(~isempty(ROI))
          experiment.ROI = ROI;
        end
        experiment.saveFile = [experiment.name '.exp'];
        % The metadata
        if(strcmp(camHardware, 'hamamatsu'))
          experiment.metadata.ExposureTime = src.ExposureTime;
        end
        rp = vid.ROIPosition;
        experiment.metadata.ROIPosition = rp;
        experiment.metadata.VideoFormat = formatList{currentFormat};
        experiment.metadata.RecordingEnd = datetime;
        experiment.metadata.info = experimentInfoText.String;  
        experiment.numFrames = length(avgT);
        experiment.fps = FPS;
        experiment.totalTime = experiment.ccRecordingOptionsCurrent.recordingLength;
        experiment.pixelType = '*uint16'; % By default
        experiment.bpp = 16; % By default
        experiment.frameSize = experiment.width*experiment.height*experiment.bpp/8;

        if(~isempty(gui))
          project = getappdata(gui, 'project');
          if(~isempty(project))
            % Check for duplicate names
            numericTag = [];
            validName = false;
            while(~validName)
              validName = true;
              for it = 1:size(project.experiments,2)
                if(strcmpi(project.experiments{it}, [experiment.name num2str(numericTag)]))
                  validName = false;
                  if(isempty(numericTag))
                    numericTag = 1;
                  else
                    numericTag = numericTag + 1;
                  end
                  continue;
                end
              end
            end
            if(~isempty(numericTag))
              experiment.name = [experiment.name num2str(numericTag)];
              logMsg(sprintf('Found duplicate experiment names. Using %s instead', experiment.name), hFigW, 'w');
            end
            project.experiments{numel(project.experiments)+1} = experiment.name;
            project.labels{numel(project.experiments)} = 'camControl';
            project.currentExperiment = length(project.experiments);
            % Change the folder to match the project structure
            experiment.folder = [project.folder experiment.name filesep];
            experiment.saveFile = ['..' filesep 'projectFiles' filesep experiment.name '.exp'];
            saveProject(project, 'gui', gui);
            setappdata(gui, 'project', project);
          end
        end
        try
          saveExperimentMetadata(experiment, regexprep(experiment.handle,'.bin$','.json'))
        catch ME
          logMsg(ME.message, hFigW, 'e');
        end
        saveExperiment(experiment);
        resizeHandle = getappdata(gui, 'ResizeHandle');
        if(isa(resizeHandle,'function_handle'))
          resizeHandle([], [], 'resetTree');
          
        end

        % Prepare the glia file
        if(experiment.ccRecordingOptionsCurrent.generateGliaMovie)
          gliaParams = experiment.ccRecordingOptionsCurrent.get();
          gliaParams.bpp = experiment.bpp;
          [gliaID, gliaParams] = initializeGliaMovie(gliaParams, experiment);
          [gliaF, gliaT, gliaFrameStart, gliaFrameFinish] = precacheGliaFrames(gliaParams, experiment.numFrames, experiment.fps);
          if(gliaParams.imageRescalingFactor == 1)
            gliaAverageFrame = zeros(experiment.height, experiment.width);
          else
            gliaAverageFrame = zeros(size(imresize(zeros(experiment.height, experiment.width), gliaParams.imageRescalingFactor)));
          end
        end
        %
        %gliaF = assignGliaFrames(gliaF, frameStart, frameFinish, currFrame, frameIterator, fID, params)

        movieRecording = true;
        for it = 1:length(objectsDisabledDuringRecording)
          objectsDisabledDuringRecording{it}.Enable = 'off';
        end
        experiment.metadata.RecordingStart = datetime;
        plotPeriod =  1/maxScreenFrameRate;
        mainTimer.Period = plotPeriod;
        start(mainTimer);
        start(recordingTimer);
        frameIterator = 0;
        paused = false;
        movieRecordButton.String = 'Stop recording';
        logMsg('Starting recording...', hFigW, 'w');
        start(vid);
        timerT = nan(size(timerT));
        ncbar.close();
        %pause(ceil(1/FPS)*2);
      case 'webcam'
        stop(mainTimer);
        stop(recordingTimer);
        delete(vid);
        vid = webcam;
        pause(ceil(1/FPS)*2);
        updateRate = FPS;
        xlim(hs.mainWindowTracesAxes, [0 bufferSize/updateRate]);
        movieRecording = true;
        for it = 1:length(objectsDisabledDuringRecording)
          objectsDisabledDuringRecording{it}.Enable = 'off';
        end
        t = nan(bufferSize, 1);
        avgTrace = nan(bufferSize, 1);
        avgTraceLower = [];
        plotPeriod =  1/maxScreenFrameRate;
        mainTimer.Period = plotPeriod;
        start(mainTimer);
        start(recordingTimer);
        frameIterator = 0;
        paused = false;
        movieRecordButton.String = 'Stop recording';
    end
    
  else
    stopRecording(vid);
    movieRecording = false;
    for it = 1:length(objectsDisabledDuringRecording)
      objectsDisabledDuringRecording{it}.Enable = 'on';
    end
    stop(mainTimer);
    stop(recordingTimer);
    switch camHardware
      case {'hamamatsu', 'winvideo', 'macvideo'}
        stop(vid);
      case 'webcam'
        delete(vid);
    end
    paused = false;
    movieRecordButton.String = 'Start recording';
  end
end

%--------------------------------------------------------------------------
function stopRecording(obj, ~)
  logMsg('Stopping recording...', hFigW, 'w');
  if(~movieRecording)
    return;
  end
  movieRecording = false;
  for it = 1:length(objectsDisabledDuringRecording)
    objectsDisabledDuringRecording{it}.Enable = 'on';
  end
  stop(mainTimer);
  stop(recordingTimer);
  switch camHardware
    case {'hamamatsu', 'winvideo', 'macvideo'}
      stop(vid);
    case 'webcam'
      delete(vid);
  end
  % Get the last frames
  if(obj.FramesAvailable > 0)
    [framesBuffer, time, metadata] = getdata(obj, obj.FramesAvailable);
    if(strcmpi(camHardware, 'winvideo') || strcmpi(camHardware, 'macvideo'))
      framesBuffer = mean(framesBuffer,3);
    end
    % And store them
    if(saveMovie)
      % Raw write
      if(~multiDriveMode)
        fwrite(videoFileID, framesBuffer, 'uint16');
      else
        % Write this batch together
        currentDrive = mod(currentDrive, numberOfDrives)+1;
        %fwrite(videoFileID(currentDrive), framesBuffer, 'uint16');
        %start(javawriteOpened(videoFileID{currentDrive}, int16(double(framesBuffer(:))-32768), true));  % start running in parallel
        multiIteration = multiIteration + 1;
        futures(multiIteration) = parfeval(@writeParallelFrames, 0, videoFileID{currentDrive}, framesBuffer);
        driveFrameIndex(arrayfun(@(x)x.FrameNumber,metadata)) = currentDrive;
        driveFramePosition(arrayfun(@(x)x.FrameNumber,metadata)) = driveCurrentFrame(currentDrive)+(1:size(framesBuffer, 4))-1;
        driveCurrentFrame(currentDrive) = driveCurrentFrame(currentDrive)+size(framesBuffer, 4);
        % Finalize
        experiment.driveFrameIndex = driveFrameIndex;
        experiment.driveFramePosition = driveFramePosition;
      end
    end
  processFrames(framesBuffer, time, metadata);
  recordingLengthText.String = sprintf('%.2f', max(0,experiment.ccRecordingOptionsCurrent.recordingLength-avgT(metadata(end).FrameNumber)));
  end
  % Generate the average frame
  avgImg = avgImg/length(avgT);
  currFrame = avgImg;
  if(saveMovie)
    % Close the files
    logMsg('Emptying buffers...', hFigW, 'w');
    if(~multiDriveMode)
      fclose(videoFileID);
    else
      while(~all([futures.Read]))
        completedIdx = fetchNext(futures);
      end
      %for it = 1:numberOfDrives
      %  fclose(videoFileID(it));
      %end
%     else
%       for it = 1:numberOfDrives
%         fclose(videoFileID(it));
%       end
    end
    %fclose(metaFileID);
  end
  if(experiment.ccRecordingOptionsCurrent.generateGliaMovie)
    finalizeGliaMovie(gliaF, gliaID);
    experiment.gliaAverageFrame = gliaAverageFrame/length(gliaT);
    experiment.gliaAverageT = gliaT;
    experiment.gliaAverageWindowSize = gliaParams.windowSize;
    experiment.gliaAverageWindowOverlap = gliaParams.windowOverlap;
  end
  
  % Consistency check
  if(any(isnan(avgT)))
    logMsg('I see NaNs on the time vector, maybe some frames were not correctly recorded or the recording was stopped before it finished', hFigW, 'e');
  end
  % Now let's try to save the experiment again
  if(~isempty(ROI))
    experiment.ROI = ROI;
  end
  if(~disableTraceUpdates)
    if(~isempty(ROI) && bufferAllTraces)
      experiment.rawTraces = ROItraces;
      experiment.rawT = t;
    end
    experiment.avgT = avgT;
    experiment.avgTrace = avgTrace;
    if(experiment.ccRecordingOptionsCurrent.computeLowerPercentileTrace)
      experiment.avgTraceLower = avgTraceLower;
    end
  end
  % The metadata
  rp = vid.ROIPosition;
  experiment.metadata.ROIPosition = rp;
  experiment.width = rp(3);
  experiment.height = rp(4);
  if(strcmp(camHardware, 'hamamatsu'))
    experiment.metadata.ExposureTime = src.ExposureTime;
  end
  experiment.avgImg = avgImg;
  experiment.metadata.VideoFormat = formatList{currentFormat};
  experiment.metadata.RecordingEnd = datetime;
  experiment.numFrames = length(avgT);
  experiment.fps = FPS;
  experiment.totalTime = experiment.ccRecordingOptionsCurrent.recordingLength;
  experiment.pixelType = '*uint16'; % By default
  experiment.bpp = 16; % By default
  experiment.frameSize = experiment.width*experiment.height*experiment.bpp/8;

  try
    saveExperimentMetadata(experiment, regexprep(experiment.handle,'.bin$','.json'))
  catch ME
    logMsg(ME.message, hFigW, 'e');
  end
  saveExperiment(experiment, 'verbose', false);
  % Updating just in case
  resizeHandle = getappdata(gui, 'ResizeHandle');
  if(isa(resizeHandle,'function_handle'))
    resizeHandle([], [], 'resetTree');
  end
  
%   % Also save the project
%   if(~isempty(gui))
%     project = getappdata(gui, 'project');
%     if(~isempty(project))
%       saveProject(project);
%     end
%   end
  paused = false;
  movieRecordButton.String = 'Start recording';
  logMsg('Recording finished', hFigW, 'w');
end

%--------------------------------------------------------------------------
function frameRateChange(hObject, ~)
  try
    src.ExposureTime = 1/str2double(hObject.String);
    FPS = 1/src.ExposureTime;
    experiment.ccRecordingOptionsCurrent.FPS = FPS;
    %movieSnapshot();
  catch ME
    logMsg(ME.message, hFigW, 'e');
    hObject.String = num2str(FPS);
  end
end

function setRecordingOptions(~, ~)
  if(~isempty(gui))
    project = getappdata(gui, 'project');
  else
    project = [];
  end
  [success, ccRecordingOptionsCurrent] = optionsWindow(experiment.ccRecordingOptionsCurrent, 'project', project);
  if(~success)
    return;
  end
  experiment.ccRecordingOptionsCurrent = ccRecordingOptionsCurrent;
  recordingLengthText.String = num2str(experiment.ccRecordingOptionsCurrent.recordingLength);
  FPStext.String = num2str(experiment.ccRecordingOptionsCurrent.FPS);
end

%--------------------------------------------------------------------------
% function setRecordingLength(hObject, ~)
%   try
%     recordingLength = str2double(hObject.String);
%   catch ME
%     logMsg(ME.message, 'e');
%     hObject.String = num2str(FPS);
%   end
% end


%--------------------------------------------------------------------------
% function movieSnapshot(~, ~)
%   if(~movieRunning)
%     vid.FramesPerTrigger = 1;
%     start(vid);
%     wait(vid);
%     currFrame = getdata(vid);
%     flushdata(vid);
%   else
%     currFrame = peekdata(vid, 1);
%   end
%   %currFrame = getsnapshot(vid);
%   updateImage();
% end

%--------------------------------------------------------------------------
function KeyPress(hObject, eventData)
  switch eventData.Key
    case 'space'
      moviePreview(hObject, eventData)
    case 'rightarrow'
      nextTracesButton(hObject, eventData);
    case 'leftarrow'
      previousTracesButton(hObject, eventData);
    case 'uparrow'
      nextTracesButton(hObject, eventData, 5);
    case 'downarrow'
      previousTracesButton(hObject, eventData, 5);

  end
end

%--------------------------------------------------------------------------
function intensityChange(hObject, ~, mode)
  input = str2double(get(hObject, 'string'));
  if(isnan(input))
    errordlg('You must enter a numeric value','Invalid Input','modal')
    uicontrol(hObject)
  else
    switch mode
      case 'min'
        if(input >= maxIntensity)
          errordlg('Maximum intensity has to be greater than minimum intensity','Invalid Input','modal');
          hObject.String = num2str(minIntensity);
          uicontrol(hObject);
        else
          minIntensity = input;
          autoLevelsReset = false;
          updateImage();
        end
      case 'max'
        if(input <= minIntensity)
          errordlg('Maximum intensity has to be greater than minimum intensity','Invalid Input','modal');
          hObject.String = num2str(maxIntensity);
          uicontrol(hObject);
        else
          maxIntensity = input;
          autoLevelsReset = false;
          updateImage();
        end
    end
  end
end

%--------------------------------------------------------------------------
function menuPreferencesRealSize(~, ~, ~)
  realSize = ~realSize;
  mainWindowResize(gcbo);
  updateImage();
  if(realSize)
    hs.menuPreferencesRealSize.Checked = 'on';
  else
    hs.menuPreferencesRealSize.Checked = 'off';
  end
end

%--------------------------------------------------------------------------
function exportCurrentImage(~, ~)
  [fileName, pathName] = uiputfile({'*.png'; '*.tiff'}, 'Save current image', appFolder);
  if(fileName ~= 0)
      export_fig([pathName fileName], hs.mainWindowFramesAxes);
  end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Utility functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------------------------------------------------------------
function updateImage()
  if(isempty(imData) || isempty(currFrame))
    return;
  end
  set(imData, 'CData', currFrame);
  caxis(hs.mainWindowFramesAxes, [minIntensity maxIntensity]);
  %if(frameIterator > 0 && mod(frameIterator, maxScreenFrameRate*1) == 0) % update at least every second
  if(frameIterator >= 10) % update at least every second
    currentFrameText.String = sprintf('screen refresh fps: %.2f', 1/nanmean(diff(timerT)));
    frameIterator = 0;
    %overlayText = sprintf('f = %d', frameIterator);
    %ar = rgb2gray(insertText(zeros(size(currFrame)), [1, 1], overlayText, 'TextColor', 'white', 'BoxColor', 'black', 'FontSize', 32));
    %set(overlayData, 'CData', double(maxIntensity)*ones(size(currFrame)));
    %set(overlayData, 'AlphaData', ar);
    if(~isempty(histogramFigure) && isvalid(histogramFigure) && ~isempty(histogramAxes) && isvalid(histogramAxes))
      [ah,bh] = hist(currFrame(:), 0:histWidth:(2^BPP-1));
      set(histogramHandle, 'XData', bh, 'YData', ah);
      set(histogramLineHandles(1), 'XData', [1, 1]*minIntensity);
      set(histogramLineHandles(2), 'XData', [1, 1]*maxIntensity);
      xlim(histogramAxes, [min(currFrame(:)), max(currFrame(:))]);
      %xlim(histogramAxes, [minIntensity maxIntensity]);
    end
  elseif(frameIterator == 0)
    currentFrameText.String = '';
  end
  %drawnow;
%     if(showPopulations)
%       plotPopulations();
%     end
end

%--------------------------------------------------------------------------
function timerRecordingUpdate(~, ~)
  if(~movieRecording)
    return;
  end
  % Only if we at least have 1 frames
  if(vid.FramesAvailable < 1)
    return;
  end
  framesBufferText.String = sprintf('Frames in buffer: %d', vid.FramesAvailable);
  [framesBuffer, time, metadata] = getdata(vid, vid.FramesAvailable);
  if(strcmpi(camHardware, 'winvideo') || strcmpi(camHardware, 'macvideo'))
    framesBuffer = mean(framesBuffer,3);
  end
  currFrame = framesBuffer(:, :, 1, end);
  if(saveMovie)
    % Raw write
    if(~multiDriveMode)
      fwrite(videoFileID, framesBuffer, 'uint16');
    else
      % Write this batch together
      currentDrive = mod(currentDrive, numberOfDrives)+1;
      %fwrite(videoFileID(currentDrive), framesBuffer, 'uint16');
      %ndata = int16(double(framesBuffer(:))-32768);
      %start(javawriteOpened(videoFileID{currentDrive}, int16(double(framesBuffer(:))-32768), false));  % start running in parallel
      multiIteration = multiIteration + 1;
      futures(multiIteration) = parfeval(@writeParallelFrames, 0, videoFileID{currentDrive}, framesBuffer);
      driveFrameIndex(arrayfun(@(x)x.FrameNumber,metadata)) = currentDrive;
      driveFramePosition(arrayfun(@(x)x.FrameNumber,metadata)) = driveCurrentFrame(currentDrive)+(1:size(framesBuffer, 4))-1;
      driveCurrentFrame(currentDrive) = driveCurrentFrame(currentDrive)+size(framesBuffer, 4);
    end
  end
  movieRecordFPS.String = sprintf('recording real fps: %.2f', 1/nanmean(diff(time)));
  % Now let's update the rest
  processFrames(framesBuffer, time, metadata);
  recordingLengthText.String = sprintf('%.2f', max(0,experiment.ccRecordingOptionsCurrent.recordingLength-avgT(metadata(end).FrameNumber)));
end

%--------------------------------------------------------------------------
function processFrames(framesBuffer, time, metadata)
  if(disableTraceUpdates)
    return;
  end
  % Update frames
  for cf = 1:size(framesBuffer, 4)
    switch camHardware
      case {'hamamatsu', 'winvideo', 'macvideo'}
        currFrame = framesBuffer(:, :, 1, cf);
        avgImg = avgImg + double(currFrame);
        currentFrameNumber = metadata(cf).FrameNumber;
    end
    
    if(~bufferAllTraces)
      t = circshift(t, -1);
      avgTrace = circshift(avgTrace, -1);
      t(end) = toc(recordingClock);
      %avgTrace(end) = mean(currFrame(:));
      % avgT is always buffered
      avgT(currentFrameNumber) = t(currentFrameNumber);
      avgTrace(currentFrameNumber) = mean(currFrame(:));
    else
      if(currentFrameNumber > 1)
        if(mod(currentFrameNumber-1, experiment.ccRecordingOptionsCurrent.recordingFrameRateStepSize) == 0)
          cFrame = ceil(currentFrameNumber/experiment.ccRecordingOptionsCurrent.recordingFrameRateStepSize);
          t(cFrame) = time(cf)-baseT+1/FPS;
        end
      else
        t(1) = 1/FPS;
        baseT = time(cf);
      end
      avgT(currentFrameNumber) = time(cf)-baseT+1/FPS;
      avgTrace(currentFrameNumber) = mean(currFrame(:));
      if(experiment.ccRecordingOptionsCurrent.computeLowerPercentileTrace)
        sortedIntensities = sort(currFrame(:));
        avgTraceLower(currentFrameNumber) = mean(sortedIntensities(1:lowerPercentilePixel));
      end
    end
    
    if(experiment.ccRecordingOptionsCurrent.generateGliaMovie)
      gliaF = assignGliaFrames(gliaF, gliaAverageFrame, gliaFrameStart, gliaFrameFinish, currFrame, currentFrameNumber, gliaID, gliaParams);
    end
        
    % Compute the means for each trace
    if(~isempty(ROItraces))
      % The spike detection part - PENDING
%       if(~bufferAllTraces)
%         ROItraces = circshift(ROItraces, -1);
%         if(spikeDetection)
%           if(~isempty(ROImodelTraces))
%             ROImodelTraces = circshift(ROImodelTraces, -1);
%           end
%           if(~isempty(spikes))
%             spikes = circshift(spikes, -1);
%           end
%         end
%       end
      % If not buffering everything, update the circular buffer
      if(~bufferAllTraces)
        for k = 1:length(ROI)
          ROItraces(end, k) = mean(currFrame(ROI{k}.pixels));
        end
      % Else update with the given recording step size
      elseif(mod(currentFrameNumber-1, experiment.ccRecordingOptionsCurrent.recordingFrameRateStepSize) == 0)
        cFrame = ceil(currentFrameNumber/experiment.ccRecordingOptionsCurrent.recordingFrameRateStepSize);
        for k = 1:length(ROI)
          ROItraces(cFrame, k) = mean(currFrame(ROI{k}.pixels));
        end
      end
    end
  end
end

%--------------------------------------------------------------------------
function timerUpdate(~, ~)
  if(~movieRunning && ~movieRecording)
    return;
  end
  timerT = circshift(timerT, -1);
  timerT(end) = toc(recordingClock);
  frameIterator = frameIterator + 1;
  if(movieRunning)
    updatePreviewBuffers();
  end
  updatePlots();
end

%--------------------------------------------------------------------------
function timerUpdateError(~, ~)
  if(plotPeriod < 10)
    plotPeriod = round(1000*plotPeriod*1.25)/1000;
    logMsg(sprintf('Cannot keep up! Increasing the screen update period to %.2f', plotPeriod), hFigW, 'w');
    mainTimer = timer('TimerFcn', @timerUpdate, ...
                      'BusyMode', 'error', 'ExecutionMode','FixedRate',...
                      'Period', plotPeriod, 'Tag', 'mainTimer', 'ErrorFcn', @timerUpdateError);
    start(mainTimer);
  else
    logMsg('Cannot keep up! Not updating the screen anymore to save the recording', hFigW, 'e');
  end
end

%--------------------------------------------------------------------------
function updatePreviewBuffers()
  % Current frame update
  switch camHardware
    case 'hamamatsu'
      if(movieRunning)
        currFrame = peekdata(vid, 1);
      else
        %currFrame = framesBuffer(:, :, 1, end);
      end
    case {'winvideo', 'macvideo'}
      if(movieRunning)
        currFrame = peekdata(vid, 1);
        currFrame = rgb2gray(currFrame);
      end
    case 'webcam'
      currFrame = snapshot(vid);
      %currFrame = uint8(mean(currFrame, 3));
      currFrame = rgb2gray(currFrame);
  end
  % Buffers update
  t = circshift(t, -1);
  avgT = circshift(avgT, -1);
  avgTrace = circshift(avgTrace, -1);
  t(end) = toc(recordingClock);
  avgT(end) = t(end);
  avgTrace(end) = mean(currFrame(:));

  if(~isempty(ROItraces))
    ROItraces = circshift(ROItraces, -1);
    if(spikeDetection)
      if(~isempty(ROImodelTraces))
        ROImodelTraces = circshift(ROImodelTraces, -1);
      end
      if(~isempty(spikes))
        spikes = circshift(spikes, -1);
      end
    end
    for k = 1:length(ROI)
      ROItraces(end, k) = mean(currFrame(ROI{k}.pixels));
      if(spikeDetection)
        if(~isempty(ROImodelTraces))
          ROImodelTraces(end, k) = NaN;
        end
        if(~isempty(spikes))
          spikes(end, k) = NaN;
        end
      end
    end
  end
end
%--------------------------------------------------------------------------
function updatePlots(varargin)
  if(disableTraceUpdates)
    return;
  end
  if(nargin > 0)
    force = varargin{1};
  else
    force = false;
  end
  % Plotting part
  if(movieRunning || movieRecording || force)
    if(ishandle(hs.mainWindowTracesAxes) && isvalid(hs.mainWindowTracesAxes) && all(ishandle(traceHandles)) && all(isvalid(traceHandles)))
      if(~bufferAllTraces || movieRunning)
        tOffset = - max(t) + bufferSize/updateRate;
      else
        tOffset = 0;
      end
      switch traceMode
        case 'average'
          set(traceHandles, 'XData', avgT + tOffset, 'YData', avgTrace);
        case 'ROI'
          selectedTraces = currentOrder(firstTrace:lastTrace);
          switch normalizationMode
            case 'together'
              for i = 1:length(traceHandles)
                set(traceHandles(i), 'XData', t + tOffset, 'YData', ROItraces(:, selectedTraces(i)'));
                set(traceHandles(i), 'Color', cmap(i, :));
                if(spikeDetection && all(ishandle(modelTraceHandles)) && all(isvalid(modelTraceHandles)))
                  set(modelTraceHandles(i), 'XData', t + tOffset, ...
                      'YData', ROImodelTraces(:, selectedTraces(i))');
                  set(modelTraceHandles(i), 'Color', cmap(i, :));
                end
                if(spikeDetection && all(ishandle(spikeHandles)) && all(isvalid(spikeHandles)))
                   set(spikeHandles(i), 'XData', t + tOffset, ...
                       'YData', spikes(:, selectedTraces(i))'*0.9*max(ROItraces(:, selectedTraces(i)')));
                  set(spikeHandles(i), 'Color', cmap(i, :));
                end
              end
            case 'separated'
              minF = min(min(ROItraces(:, selectedTraces)));
              maxF = max(max(ROItraces(:, selectedTraces)));
              for i = 1:length(traceHandles)
                set(traceHandles(i), 'XData', t + tOffset, ...
                    'YData', (i-1)+(ROItraces(:, selectedTraces(i))'-minF)/(maxF-minF));
                set(traceHandles(i), 'Color', cmap(i, :));
                if(spikeDetection && all(ishandle(modelTraceHandles)) && all(isvalid(modelTraceHandles)))
                  set(modelTraceHandles(i), 'XData', t + tOffset, ...
                    'YData', (i-1)+(ROImodelTraces(:, selectedTraces(i))'-minF)/(maxF-minF));
                  set(modelTraceHandles(i), 'Color', cmap(i, :));
                end
                if(spikeDetection && all(ishandle(spikeHandles)) && all(isvalid(spikeHandles)))
                  set(spikeHandles(i), 'XData', t + tOffset, ...
                    'YData', (i-1)+spikes(:, selectedTraces(i))'*0.9);
                  set(spikeHandles(i), 'Color', cmap(i, :));
                end
              end
            case 'separatedNormalized'
              for i = 1:length(traceHandles)
                minF = min(ROItraces(:, selectedTraces(i)));
                maxF = max(ROItraces(:, selectedTraces(i)));
                set(traceHandles(i), 'XData', t + tOffset, ...
                  'YData', (i-1)+(ROItraces(:, selectedTraces(i))'-minF)/(maxF-minF));
                set(traceHandles(i), 'Color', cmap(i, :));
                if(spikeDetection && all(ishandle(modelTraceHandles)) && all(isvalid(modelTraceHandles)))
                  set(modelTraceHandles(i), 'XData', t + tOffset, ...
                    'YData', (i-1)+(ROImodelTraces(:, selectedTraces(i))'-minF)/(maxF-minF));
                  set(modelTraceHandles(i), 'Color', cmap(i, :));
                end
                if(spikeDetection && all(ishandle(spikeHandles)) && all(isvalid(spikeHandles)))
                  set(spikeHandles(i), 'XData', t + tOffset, ...
                    'YData', (i-1)+spikes(:, selectedTraces(i))'*0.9);
                  set(spikeHandles(i), 'Color', cmap(i, :));
                end
              end
          end
      end
    end
    updateImage();
  end
end
%--------------------------------------------------------------------------
function cleanMenu()
  a = findall(gcf);
  b = findall(a, 'ToolTipString', 'Save Figure');
  set(b,'Visible','Off');
  b = findall(a, 'ToolTipString', 'Show Plot Tools');
  %set(b,'Visible','Off');
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

%--------------------------------------------------------------------------
function changeSelectionMode(mode)
    if(~strcmp(selectionMode, 'normal') && strcmp(mode, 'normal'))
        % Finish selection
        delete(plotHandleList);
        hold on;
        plotHandleList = [];
        selectionMode = 'normal';
        if(addCount > 0)
            displayROI();
            logMsg([num2str(addCount) ' ROI added'], hFigW);
            logMsg([num2str(length(ROI)) ' ROI present'], hFigW);
            addCount = 0;
        end
    end
    selectionMode = mode;
    if(~isempty(cursorHandle))
        delete(cursorHandle)
        cursorHandle = [];
    end
end

%--------------------------------------------------------------------------
function didIpause = pauseRecording()
  didIpause = false;
  if(strcmpi(mainTimer.Running, 'on'))
    stop(mainTimer);
    if(~paused)
      didIpause = true;
    end
    paused = true;
  end
end

%--------------------------------------------------------------------------
function resumeRecording()
  if(paused)
    plotPeriod =  1/maxScreenFrameRate;
    mainTimer.Period = plotPeriod;
    start(mainTimer);
  end
  paused = false;
end

%--------------------------------------------------------------------------
function resetROItraces()
  firstTrace = currentOrder(1);
  lastTrace = numberTraces;
  totalPages = ceil(length(ROI)/numberTraces);
  cmap = parula(numberTraces + 1);
  if(isempty(ROItraces))
    ROItraces = nan(length(t), length(ROI));
  end
  %ROImodelTraces = nan(length(t), length(ROI));
  %spikes = nan(length(t), length(ROI));
  pageChange();
  traceModeSelection([], [], 'ROI')
end

%--------------------------------------------------------------------------
function saveExperimentMetadata(exp, outputFile)
  fieldList = {'handle', 'metadata', 'numFrames', 'fps', 'totalTime', 'width', 'height', 'pixelType', 'bpp', 'frameSize', 'name'};
  if(multiDriveMode)
    fieldList{end+1} = 'driveFrameIndex';
    fieldList{end+1} = 'driveFramePosition';
  end
  for i = 1:length(fieldList)
    if(isfield(exp, fieldList{i}))
      meta.(fieldList{i}) = exp.(fieldList{i});
    end
  end
              
  metaFile = savejson([], meta, 'ParseLogical', true);
  fID = fopen(outputFile, 'W');
    fprintf(fID, '%s', metaFile);
  fclose(fID);
end

end

% This is what we need to do to also generate the glia average movie
% Buffer size is going to depend on the amount of overlap. We can use a
% cell structure, fill and empty as it goes

%--------------------------------------------------------------------------
function [fID, params] = initializeGliaMovie(params, experiment)
  if(~isempty(params.smoothingKernel))
    params.kernel = eval(params.smoothingKernel);
  else
    params.kernel = [];
  end

  %%% Define stuff
  dataFolder = [experiment.folder 'data' filesep];
  if(~exist(dataFolder, 'dir'))
    mkdir(dataFolder);
  end
  fID = fopen([dataFolder experiment.name '_gliaAverageMovieDataFile.dat'], 'W');
end

%--------------------------------------------------------------------------
function finalizeGliaMovie(gliaF, fID)
  % Check if any frame is still open
  for i = 1:length(gliaF)
    if(~isempty(gliaF{i}))
      logMsg(sprintf('Glia frame %d is still open', i), 'e');
    end
  end
  fclose(fID);
end

%--------------------------------------------------------------------------
function [gliaF, gliaT, frameStart, frameFinish] = precacheGliaFrames(params, numFrames, fps)
  averagedFrames = floor((numFrames - params.windowSize)/params.windowOverlap)-1;
  gliaT = (1:averagedFrames)*params.windowOverlap/fps;
  frameStart = zeros(averagedFrames, 1);
  frameFinish = zeros(averagedFrames, 1);
  for i = 1:averagedFrames
    frameStart(i) = 1+(i-1)*params.windowOverlap;
    frameFinish(i) = frameStart(i) + params.windowSize - 1;
    if(frameFinish(i) > numFrames)
      frameFinish(i) = numFrames;
    end
  end
  gliaF = cell(averagedFrames, 1);
end

%--------------------------------------------------------------------------
function gliaF = assignGliaFrames(gliaF, gliaAverageFrame, frameStart, frameFinish, currFrame, frameIterator, fID, params)
  valid = find(frameIterator >= frameStart & frameIterator <= frameFinish);
  % For all the frames that need updating
  for i = 1:length(valid)
    % If we are starting a new average frame, initialize it
    if(frameIterator == frameStart(valid(i)))
      gliaF{valid(i)} = double(currFrame);
    elseif(frameIterator == frameFinish(valid(i)))
      % Update and write
      gliaF{valid(i)} = (gliaF{valid(i)} + double(currFrame))/length(frameStart(valid(i)):frameFinish(valid(i)));
      
      if(params.imageRescalingFactor ~= 1)
        gliaMovieFrame = imresize(gliaF{valid(i)}, params.imageRescalingFactor);
      else
        gliaMovieFrame = gliaF{valid(i)};
      end
      % Turns out the resize can produce negative values. Let's threshold them
      gliaMovieFrame(gliaMovieFrame < 0) = 0;
      % Also over saturated values, just in case
      gliaMovieFrame(gliaMovieFrame > (2^params.bpp-1)) = (2^params.bpp-1);
      gliaAverageFrame = gliaAverageFrame + gliaMovieFrame;
      % Store the movie in a raw file
      %fwrite(fID, gliaMovieFrame, 'double');
      fwrite(fID, gliaMovieFrame, 'double');
      % Free storage
      gliaF{valid(i)} = [];
    else
      % Update
      gliaF{valid(i)} = gliaF{valid(i)} + double(currFrame);
    end
  end
end




%fID = java.io.DataOutputStream(java.io.FileOutputStream('/Users/orlandi/test.dat'));
%ndata = int16(double(data)-32768);
%start(javawriteOpened(fID, ndata(:), true));  % start running in parallel


%%
% Read
%fID2 = fopen('/Users/orlandi/test.dat', 'r', 's');
%ar = uint16(double(fread(fID2, [1000 1000], 'int16'))+32768);


