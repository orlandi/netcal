function [hFigW, experiment] = viewRecording(experiment)
% VIEWRECORDING Window for recording viewing
%
% USAGE:
%    viewRecording(experiment)
%
% INPUT arguments:
%    experiment - experiment structure
%
% OUTPUT arguments:
%    hFigW - handle to the GUI figure
%    experiment - experiment structure
%
% EXAMPLE:
%    [hFigW, experiment] = viewGlia(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

%#ok<*AGROW>
%#ok<*ASGLU>
%#ok<*FXUP>
%#ok<*INUSD>

if(nargin == 0)
  experiment = loadExperiment();
  if(isempty(experiment))
    return;
  end
  experiment.virtual = true;
  appFolder = fileparts(mfilename('fullpath'));
  appFolder = [appFolder filesep '..'];
  addpath(genpath(appFolder));
  rmpath(genpath([appFolder filesep '.git'])) % But exclude .git/
  rmpath(genpath([appFolder filesep 'old'])) % And old
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Initialization
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
gui = gcbf;
hFigW = [];
textFontSize = 10;
minGridBorder = 1;
movieRunning = false;
initialTime = [];
initialFrame = [];
realSize = false;
spikesOverlay = [];
spikesScatterOverlay = [];
firingNeuronColor = [];
frameSpikes = [];
showSpikes = false;
showBursts = false;
showPopulations = false;
burstsOverlay = [];
frameBursts = [];
frameBurstsIdx = [];
frameBurstsColor = [];
burstsPixels = [];
populationsOverlay = [];
framePopulationsColor =[];
populationsPixels = [];
autoLevelsReset = true;
currentCmap = gray;
avgTraceCorrection = 'none';
baseLineCorrection = false;

% Check if the handle exists. If not, update it - needs to go here for login purposes
[newExperiment, success] = experimentHandleCheck(experiment);
if(~success)
  return;
end
[newExperiment, success] = precacheHISframes(newExperiment);
if(~success)
  return;
end

if(~isequaln(newExperiment, experiment))
  experimentChanged = true;
else
  experimentChanged = false;
end
experiment = newExperiment;
[success, curOptions] = preloadOptions(experiment, exportMovieOptions, gui, false, false);
experiment.exportMovieOptionsCurrent = curOptions;

clear newExperiment;

if(isfield(experiment, 'ROI'))
    ROIid = getROIid(experiment.ROI);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Create components
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
initVisible = 'off';
try
  [fpa, fpb, fpc] = fileparts(experiment.handle);
  if(strcmpi(fpc, '.avi'))
    initVisible = 'off';
  end
catch
end
hs.mainWindow = figure('Visible', initVisible,...
                       'Resize','on',...
                       'Toolbar', 'figure',...
                       'Tag','viewRecording', ...
                       'NumberTitle', 'off',...
                       'DockControls','off',...
                       'MenuBar', 'none',...
                       'Name', ['Recording viewer: ' experiment.name],...
                       'KeyPressFcn', @KeyPress, ...
                       'SizeChangedFcn', @mainWindowResize,...
                       'CloseRequestFcn', @closeCallback);
hFigW = hs.mainWindow;
hFigW.Position = setFigurePosition(gui, 'width', 800, 'height', 600);
if(~isempty(gui))
  setappdata(hFigW, 'logHandle', getappdata(gcbf, 'logHandle'));
end

%%% The menu
hs.menu.file.root = uimenu(hs.mainWindow, 'Label', 'File');
uimenu(hs.menu.file.root, 'Label', 'Exit and discard changes', 'Callback', {@closeCallback, false});
if(~isfield(experiment, 'tag') || ~strcmp(experiment.tag, 'dummy'))
  uimenu(hs.menu.file.root, 'Label', 'Exit and save changes', 'Callback', {@closeCallback, true});
  uimenu(hs.menu.file.root, 'Label', 'Exit (default)', 'Callback', @closeCallback);
end

hs.menu.preferences.root = uimenu(hs.mainWindow, 'Label', 'Preferences', 'Enable', 'on');
hs.menu.preferences.realSize = uimenu(hs.menu.preferences.root, 'Label', 'Real Size', 'Enable', 'on', 'Callback', @menuPreferencesRealSize);

%%% Create menus that are only enabled if requisites are met
hs.menu.preferences.avgTraceCorrection.root = uimenu(hs.menu.preferences.root, 'Label', 'Average trace correction', 'Enable', 'off');
hs.menu.preferences.avgTraceCorrection.avg = uimenu(hs.menu.preferences.avgTraceCorrection.root, 'Label', 'Average', 'Enable', 'off', 'Callback', {@menuPreferencesAvgTraceCorrection, 'average'}, 'tag', 'avgTraceCorrection');
hs.menu.preferences.avgTraceCorrection.lower = uimenu(hs.menu.preferences.avgTraceCorrection.root, 'Label', 'Lower quartile', 'Enable', 'off', 'Callback', {@menuPreferencesAvgTraceCorrection, 'lower'}, 'tag', 'avgTraceCorrection');
hs.menu.preferences.avgTraceCorrection.upper = uimenu(hs.menu.preferences.avgTraceCorrection.root, 'Label', 'Upper quartile', 'Enable', 'off', 'Callback', {@menuPreferencesAvgTraceCorrection, 'upper'}, 'tag', 'avgTraceCorrection');
hs.menu.preferences.regionCorrection = uimenu(hs.menu.preferences.root, 'Label', 'Baseline correction', 'Enable', 'off', 'Callback', @menuPreferencesBaselineCorrection, 'tag', 'baseLineCorrection');
hs.menu.preferences.selectedMovie.root = uimenu(hs.menu.preferences.root, 'Label', 'Selected movie', 'Enable', 'off');
hs.menu.preferences.selectedMovie.original = uimenu(hs.menu.preferences.selectedMovie.root, 'Label', 'Original', 'Enable', 'off', 'Checked', 'on', 'Tag', 'selectedMovie', 'Callback', {@menuPreferencesSelectedMovie, 'original'});
hs.menu.preferences.selectedMovie.denoised = uimenu(hs.menu.preferences.selectedMovie.root, 'Label', 'Denoised', 'Enable', 'off', 'Tag', 'selectedMovie', 'Callback', {@menuPreferencesSelectedMovie, 'denoised'});
hs.menu.preferences.selectedMovie.both = uimenu(hs.menu.preferences.selectedMovie.root, 'Label', 'Both', 'Enable', 'off', 'Tag', 'selectedMovie', 'Callback', {@menuPreferencesSelectedMovie, 'both'});
  
if(isfield(experiment, 't'))
  hs.menu.preferences.avgTraceCorrection.root.Enable = 'on';
  hs.menu.preferences.avgTraceCorrection.avg.Enable = 'on';
end
if(isfield(experiment, 'avgTraceLower'))
  hs.menu.preferences.avgTraceCorrection.lower.Enable = 'on';
end
if(isfield(experiment, 'avgTraceUpper'))
  hs.menu.preferences.avgTraceCorrection.upper.Enable = 'on';
end

if(isfield(experiment, 'baseLine'))
  hs.menu.preferences.regionCorrection.Enable = 'on';
end

if(isfield(experiment, 'denoisedData'))
  hs.menu.preferences.selectedMovie.root.Enable = 'on';
  hs.menu.preferences.selectedMovie.original.Enable = 'on';
  hs.menu.preferences.selectedMovie.denoised.Enable = 'on';
  hs.menu.preferences.selectedMovie.both.Enable = 'on';
  currentMovie = 1;
  denoisedBlocksPerFrame = [];
else
  currentMovie = 1;
end

hs.menu.show.root = uimenu(hs.mainWindow, 'Label', 'Show', 'Visible', 'on');
hs.menu.show.populations = generateSelectionMenu(experiment, hs.menu.show.root);
hs.menu.show.populations.root.Label = 'Groups';
hs.menu.show.populations.root.Enable = 'off';

hs.menu.show.bursts = generateSelectionMenu(experiment, hs.menu.show.root);
hs.menu.show.bursts.root.Label = 'Bursts';
hs.menu.show.bursts.root.Enable = 'off';

hs.menu.show.spikes = generateSelectionMenu(experiment, hs.menu.show.root);
hs.menu.show.spikes.root.Label = 'Spikes';
hs.menu.show.spikes.root.Enable = 'off';

% Menu to show spikes
if(isfield(experiment, 'spikes'))
  hs.menu.show.spikes.root.Enable = 'on';
  spikesHandles = assignRecursiveCallback(hs.menu.show.spikes, @updateShowSpikes);
  groupNames = fieldnames(hs.menu.show.spikes);
  for i = 1:length(groupNames)
    if(strcmpi(groupNames{i}, 'root') || isa(hs.menu.show.spikes.(groupNames{i}), 'matlab.ui.container.Menu'))
      continue;
    end
    groupFields = fieldnames(hs.menu.show.spikes.(groupNames{i}));
    if(length(groupFields) == 1)
      continue;
    end
    if(isfield(hs.menu.show.spikes.(groupNames{i}), 'list') && length(hs.menu.show.spikes.(groupNames{i}).list) > 1)
      hs.menu.show.spikes.(groupNames{i}).all = ...
        uimenu(hs.menu.show.spikes.(groupNames{i}).root, 'Label', 'All', 'Separator', 'on', 'Enable', 'on', 'Callback', {@updateShowSpikes, 'all'});
    end
  end
  spikesMembers = cell(length(spikesHandles), 1);
  spikesColor = cell(length(spikesHandles), 1);
end

% Menu to show populations
if(isfield(experiment, 'traceGroups') && isfield(experiment, 'ROI') && ~isempty(experiment.ROI))
  hs.menu.show.populations.root.Enable = 'on';
  populationsHandles = assignRecursiveCallback(hs.menu.show.populations, @updateShowPopulations);
  groupNames = fieldnames(hs.menu.show.populations);
  for i = 1:length(groupNames)
    if(strcmpi(groupNames{i}, 'root') || isa(hs.menu.show.populations.(groupNames{i}), 'matlab.ui.container.Menu'))
      continue;
    end
    groupFields = fieldnames(hs.menu.show.populations.(groupNames{i}));
    if(length(groupFields) == 1)
      continue;
    end
    if(isfield(hs.menu.show.populations.(groupNames{i}), 'list') && length(hs.menu.show.populations.(groupNames{i}).list) > 1)
      hs.menu.show.populations.(groupNames{i}).all = ...
        uimenu(hs.menu.show.populations.(groupNames{i}).root, 'Label', 'All', 'Separator', 'on', 'Enable', 'on', 'Callback', {@updateShowPopulations, 'all'});
    end
  end
  framePopulationsColor = cell(length(populationsHandles), 1);
  populationsPixels = cell(length(populationsHandles), 1);
end

% Menu to show bursts
if(isfield(experiment, 'traceBursts'))
  burstHandles = assignRecursiveCallback(hs.menu.show.bursts, @updateShowBursts);
  groupNames = fieldnames(hs.menu.show.bursts);
  for i = 1:length(groupNames)
    if(strcmpi(groupNames{i}, 'root') || isa(hs.menu.show.bursts.(groupNames{i}), 'matlab.ui.container.Menu'))
      continue;
    end
    groupFields = fieldnames(hs.menu.show.bursts.(groupNames{i}));
    if(length(groupFields) == 1)
      continue;
    end
    if(isfield(hs.menu.show.bursts.(groupNames{i}), 'list') && length(hs.menu.show.bursts.(groupNames{i}).list) > 1)
      hs.menu.show.bursts.(groupNames{i}).all = uimenu(hs.menu.show.bursts.(groupNames{i}).root, 'Label', 'All', 'Separator', 'on', 'Enable', 'on', 'Callback', {@updateShowBursts, 'all'});
    end
  end
  frameBursts = cell(length(burstHandles), 1);
  frameBurstsIdx = cell(length(burstHandles), 1);
  frameBurstsColor = cell(length(burstHandles), 1);
  burstsPixels = cell(length(burstHandles), 1);
end

hs.menu.export.root = uimenu(hs.mainWindow, 'Label', 'Export');
hs.menu.export.current = uimenu(hs.menu.export.root, 'Label', 'Current image', 'Callback', @exportCurrentImage);
hs.menu.export.currentMovie = uimenu(hs.menu.export.root, 'Label', 'Current movie', 'Callback', @exportCurrentMovie);

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
% Frames panel
hs.mainWindowFramesPanel = uix.Panel('Parent', hs.mainWindowGrid, 'Padding', 0, 'BorderType', 'none');
axesContainer = uicontainer('Parent', hs.mainWindowFramesPanel);
hs.mainWindowFramesAxes = axes('Parent', axesContainer);

hs.mainWindowFramesAxes2 = [];

%%% Preinitialize the video
[fID, experiment] = openVideoStream(experiment);

currFrame = getFrame(experiment, 1, fID);

currFrame2 = [];

%me = mean(double(currFrame(:)));
%se = std(double(currFrame(:)));
%currFrame(currFrame > me+10*se) = NaN;
axes(hs.mainWindowFramesAxes);
imData = imagesc(currFrame, 'HitTest', 'off');
%imData.Parent.Children
imData2 = [];

axis equal tight;
maxIntensity = max(currFrame(:));
minIntensity = min(currFrame(:));
minIntensity2 = 0;
maxIntensity2 = 100;

set(hs.mainWindowFramesAxes, 'XTick', []);
set(hs.mainWindowFramesAxes, 'YTick', []);
set(hs.mainWindowFramesAxes, 'LooseInset', [0,0,0,0]);
box on;

%overlayData = imagesc(ones(size(currFrame)), 'HitTest', 'off');
overlayData = [];
    
% Below image panel
%uix.Empty('Parent', hs.mainWindowTabViewGrid);
hs.mainWindowBottomButtons = uix.VBox('Parent', hs.mainWindowGrid);

hs.mainWindowFramesSlider  = uicontrol('Style', 'slider', 'Parent', hs.mainWindowBottomButtons,...
                                       'Min', 1, 'Max', experiment.numFrames, 'Value', 1, ...,
                                       'SliderStep', [1 100]/(experiment.numFrames-1), 'Callback', @frameChange);
addlistener(hs.mainWindowFramesSlider, 'Value' , 'PostSet', @frameChange);

b = uix.HBox( 'Parent', hs.mainWindowBottomButtons);
frameRateText = uicontrol('Parent', b, 'Style','edit',...
          'String', num2str(round(experiment.fps)), 'FontSize', textFontSize, 'HorizontalAlignment', 'left');
uicontrol('Parent', b, 'Style', 'text', 'String', 'Frame rate (fps)', 'FontSize', textFontSize, 'HorizontalAlignment', 'left');
moviePlayButton = uicontrol('Parent', b, 'String', 'Play', 'FontSize', textFontSize, 'Callback', @moviePlay);
set(b, 'Widths', [30 120 80], 'Spacing', 5, 'Padding', 0);

set(hs.mainWindowBottomButtons, 'Heights', [20 20], 'Padding', 5, 'Spacing', 10);

uix.Empty('Parent', hs.mainWindowGrid);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% COLUMN START
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
uix.Empty('Parent', hs.mainWindowGrid);
% Colorbar panel
hs.mainWindowColorbarPanel = uix.Panel('Parent', hs.mainWindowGrid, 'Padding', 5, 'BorderType', 'none');
hs.mainWindowColorbarAxes = axes('Parent', hs.mainWindowColorbarPanel);
hs.mainWindowColorbarAxes.Visible = 'off';
hs.mainWindowColorbar = colorbar('location','East');
set(hs.mainWindowColorbarAxes, 'LooseInset', [0,0,0,0]);
caxis(hs.mainWindowColorbarAxes, [1 5]);
set(hs.mainWindowColorbar, 'XTick', [1 5]);


% Below colorbar panel
uix.Empty('Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowGrid);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% COLUMN START
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
uix.Empty('Parent', hs.mainWindowGrid);

% Right buttons
hs.mainWindowRightButtons = uix.VBox('Parent', hs.mainWindowGrid);


b = uix.HBox( 'Parent', hs.mainWindowRightButtons);
maxIntensityText = uicontrol('Parent', b, 'Style','edit',...
          'String', '12', 'FontSize', textFontSize, 'HorizontalAlignment', 'left', 'callback', {@intensityChange, 'max'});
uicontrol('Parent', b, 'Style', 'text', 'String', 'Maximum', 'FontSize', textFontSize, 'HorizontalAlignment', 'left');
set(b, 'Widths', [30 -1], 'Spacing', 5, 'Padding', 0);

uix.Empty('Parent', hs.mainWindowRightButtons);

b = uix.VButtonBox( 'Parent', hs.mainWindowRightButtons);
uicontrol('Parent', b, 'Style','text',...
          'String','Colormap:', 'FontSize', textFontSize, 'HorizontalAlignment', 'left');

htmlStrings = getHtmlColormapNames({'gray','parula', 'morgenstemning', 'jet', 'isolum'}, 115, 12);
uicontrol('Parent', b, 'Style','popup', 'Units','pixel', 'String',htmlStrings, 'Callback', @setmap, 'FontSize', textFontSize);
uicontrol('Parent', b, 'Units','pixel', 'String', 'Invert Colormap', 'Callback', @invertMap, 'FontSize', textFontSize);

set(b, 'ButtonSize', [200 15], 'Spacing', 20, 'Padding', 0);
uicontrol('Parent', hs.mainWindowRightButtons, 'String', 'Auto levels', 'FontSize', textFontSize, 'Callback', @autoLevels);

uix.Empty('Parent', hs.mainWindowRightButtons);

b = uix.HBox( 'Parent', hs.mainWindowRightButtons);
minIntensityText = uicontrol('Parent', b, 'Style','edit',...
          'String','12', 'FontSize', textFontSize, 'HorizontalAlignment', 'left', 'callback', {@intensityChange, 'min'});
uicontrol('Parent', b, 'Style','text', 'String', 'Minimum', 'FontSize', textFontSize, 'HorizontalAlignment', 'left');
set(b, 'Widths', [30 -1], 'Spacing', 5, 'Padding', 0);

set(hs.mainWindowRightButtons, 'Heights', [20 -1 100 25 -1 20], 'Padding', 5);
%set(hs.mainWindowRightButtons, 'ButtonSize', [100 35], 'Spacing', 55);


% Below right buttons
hs.mainWindowBottomRightButtons = uix.VBox('Parent', hs.mainWindowGrid);

b = uix.HBox( 'Parent', hs.mainWindowBottomRightButtons);
currentFrameText = uicontrol('Parent', b, 'Style','edit',...
          'String', '1', 'FontSize', textFontSize, 'HorizontalAlignment', 'left', 'callback', @currentFrameChange);
uicontrol('Parent', b, 'Style','text', 'String', 'Current Frame', 'FontSize', textFontSize, 'HorizontalAlignment', 'left');
set(b, 'Widths', [40 -1], 'Spacing', 5, 'Padding', 0);


set(hs.mainWindowBottomRightButtons, 'Heights', 20, 'Padding', 5);
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
set(hs.mainWindowSuperBox, 'Heights', [-1 65], 'Padding', 0, 'Spacing', 0);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Final init
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%imData.Parent.Children
colormap(currentCmap);

cleanMenu();

% Finish the new log panel
hFigW.Visible = 'on';


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
% Righ click menu
hs.rightClickMenu.root = uicontextmenu;
hs.mainWindowFramesAxes.UIContextMenu = hs.rightClickMenu.root;
hs.rightClickMenu.showTraceRaw = uimenu(hs.rightClickMenu.root, 'Label','Show neuron raw trace', 'Callback', {@rightClickPlotNeuronTrace, 'raw'});
hs.rightClickMenu.showTraceSmoothed = uimenu(hs.rightClickMenu.root, 'Label','Show neuron smoothed trace', 'Callback', {@rightClickPlotNeuronTrace, 'smoothed'});
if(~isfield(experiment, 'traces'))
  hs.rightClickMenu.showTraceRaw.Enable = 'off';
  hs.rightClickMenu.showTraceSmoothed.Enable = 'off';
end
axes(hs.mainWindowFramesAxes);


% Other callbacks
panh = pan;
panh.ActionPostCallback = @postPanZoomUpdate;
pan off;
zoomh = zoom;
zoomh.ActionPostCallback = @postPanZoomUpdate;
zoom off;
if(isfield(experiment, 'tag') && strcmp(experiment.tag, 'dummy'))
  menuPreferencesSelectedMovie([], [], 'denoised');
  hs.menu.preferences.selectedMovie.denoised.Checked = 'on';
end

mainWindowResize();

try
  autoLevels();
catch ME
  logMsg(ME.message, 'e');
end

if(isempty(gui))
  waitfor(hFigW);
end

%--------------------------------------------------------------------------
function mainWindowResize(~, ~)
  try
    set(hs.mainWindowGrid, 'Widths', [minGridBorder -1 25 200 minGridBorder], 'Heights', [minGridBorder -1 100 minGridBorder]);
  catch
    return;
  end
    pos = hs.mainWindowFramesAxes.Parent.Position;
    hs.mainWindowColorbar.Position(2) = pos(2);
    hs.mainWindowColorbar.Position(4) = pos(4);
    hs.mainWindowFramesSlider.Position(1) = pos(1);
    hs.mainWindowFramesSlider.Position(3) = pos(3);
    switch currentMovie
    case {1, 2}
      realRatio = size(currFrame,2)/size(currFrame,1);
      case 3
        realRatio = size(currFrame,2)/size(currFrame,1)*2;
    end
    curPos = hs.mainWindowFramesAxes.Parent.Position;
    if(realSize)
      curSize = get(hs.mainWindow, 'Position');
      if(isempty(curSize))
        return;
      end
      curPos(3) = size(currFrame,2);
      curPos(4) = size(currFrame,1);

      minWidth = curPos(3) + 25 + 200 + minGridBorder*2;
      minHeight = curPos(4) + 100 + minGridBorder*2+100;

      newPos = setFigurePosition([], 'width', minWidth, 'height', minHeight);
      if(newPos(3) ~= minWidth || newPos(4) ~= minHeight)
        logMsg('Screen not big enough for real size');
        realSize = false;
      end
      hs.mainWindow.Position = newPos;
    end
    curRatio = curPos(3)/curPos(4);
    if(curRatio > realRatio)
      set(hs.mainWindowGrid, 'Widths', [-1 max(curPos(4)*realRatio, 400) 25 200 -1], 'Heights', [-1 max(curPos(4),400) 100 -1]);
    else
      set(hs.mainWindowGrid, 'Widths', [-1 max(curPos(3), 400) 25 200 -1], 'Heights', [-1 max(curPos(3)/realRatio,400) 100 -1]);
    end
    updateImage();
end

%--------------------------------------------------------------------------
function setmap(hObject, ~)
  val = hObject.Value;
  maps = hObject.String;
  newmap = maps{val};
  mapNamePosition = strfind(newmap, 'png">');
  newmap = newmap(mapNamePosition+5:end);
  currentCmap = eval(newmap);
  colormap(currentCmap);
end

%--------------------------------------------------------------------------
function invertMap(~, ~)
  currentCmap = currentCmap(end:-1:1, :);
  colormap(currentCmap);
end

%--------------------------------------------------------------------------
function closeCallback(~, ~, varargin)
  if(~isempty(fID))
    try
      closeVideoStream(fID);
    catch ME
      logMsg(ME.message, 'e');
    end
  end
  
  guiSave(experiment, experimentChanged, varargin{:});
  
  delete(hFigW);
end

% ImageJ old auto version
%--------------------------------------------------------------------------
function autoLevels(~, ~)
  [minIntensity, maxIntensity] = autoLevelsFIJI(currFrame, experiment.bpp, autoLevelsReset);
  if(currentMovie == 3)
    [minIntensity2, maxIntensity2] = autoLevelsFIJI(currFrame2, experiment.bpp, autoLevelsReset, false);
  end
  
  maxIntensityText.String = sprintf('%.2f', maxIntensity);
  minIntensityText.String = sprintf('%.2f', minIntensity);
  updateImage();
  autoLevelsReset = false;
end

%--------------------------------------------------------------------------
function frameChange(~, ~)
  hs.mainWindowFramesSlider.Value = round(hs.mainWindowFramesSlider.Value);
    try
      switch currentMovie
        case 1
          currFrame = getFrame(experiment, hs.mainWindowFramesSlider.Value, fID);
        case 2
          currFrame = getDenoisedFrame(experiment, hs.mainWindowFramesSlider.Value, denoisedBlocksPerFrame);
        case 3
          currFrame = getFrame(experiment, hs.mainWindowFramesSlider.Value, fID);
          currFrame2 = getDenoisedFrame(experiment, hs.mainWindowFramesSlider.Value, denoisedBlocksPerFrame);
          %currFrame2 = currFrame;
      end
      if(~strcmpi(avgTraceCorrection, 'none'))
        applyAvgTraceCorrection();
      end
      if(baseLineCorrection)
        applyBaselineCorrection();
      end
    catch
      logMsg(sprintf('Something went wrong loading frame %d. Maybe the file is corrupt?', hs.mainWindowFramesSlider.Value), 'w');
    end
    
  currentFrameText.String = sprintf('%.0f', hs.mainWindowFramesSlider.Value);
  updateImage();
end

%--------------------------------------------------------------------------
function menuHandles = assignRecursiveCallback(menu, callbackFunction)
  menuHandles = [];
  if(isa(menu, 'matlab.ui.container.Menu'))
    if(length(menu) == 1)
      if(isempty(menu.Children))
        menu.Callback = callbackFunction;
        menuHandles = menu;
      else
        menuHandles = menu;
      end
    else
      for i = 1:length(menu)
        menuHandles = [menuHandles; assignRecursiveCallback(menu(i), callbackFunction)];
      end
    end
  else
    if(~isempty(menu))
      fields = fieldnames(menu);
      for it = 1:length(fields)
        %fields{it}
        menuHandles = [menuHandles; assignRecursiveCallback(menu.(fields{it}), callbackFunction)];
      end
    end
  end
end

%--------------------------------------------------------------------------
function updateShowSpikes(hObject, eventData, type)
  if(nargin < 3)
    type = 'single';
  end

  if(strcmpi(hObject.Checked, 'on'))
    hObject.Checked = 'off';
    showSpikes = false;
    switch type
      case 'all'
        parent = spikesHandles(find(spikesHandles == hObject.Parent));
        childsList = parent.Children;
        childsList(childsList == hObject) = [];
        for it = 1:length(childsList)
          curIdx = find(spikesHandles == childsList(it));
          spikesMembers{curIdx} = [];
          spikesColor{curIdx} = [];
          spikesHandles(curIdx).Checked = 'off';
        end
        for it = 1:length(spikesHandles)
          if(strcmpi(spikesHandles(it).Checked, 'on'))
            showSpikes = true;
            return;
          end
        end
      case 'single'
        curIdx = find(spikesHandles == hObject);
        spikesMembers{curIdx} = [];
        spikesColor{curIdx} = [];
        for it = 1:length(spikesHandles)
          if(strcmpi(spikesHandles(it).Checked, 'on'))
            showSpikes = true;
            return;
          end
        end
    end
    if(~isempty(spikesOverlay))
      delete(spikesOverlay);
    end
  else
    switch type
      case 'all'
        parent = spikesHandles(find(spikesHandles == hObject.Parent));
        childsList = parent.Children;
        childsList(childsList == hObject) = [];
        for it = 1:length(childsList)
          curIdx = find(spikesHandles == childsList(it));
          spikesType = strsplit(spikesHandles(curIdx).Tag,':');
          spikesType(1) = [];
          spikesType{2} = str2num(spikesType{2});
          
          spikesHandles(curIdx).Checked = 'on';
          
          if(length(spikesHandles) > 7)
            cmap = rand(length(spikesHandles), 3);
          else
            cmap = lines(length(spikesHandles));
          end
          spikesColor{curIdx} = cmap(curIdx, :);
          % Get the mask
          validPixels = [];
          members = experiment.traceGroups.(spikesType{1}){spikesType{2}};
          spikesMembers{curIdx} = members;
          showSpikes = true;
          hObject.Checked = 'on';
        end
      case 'single'
        curIdx = find(spikesHandles == hObject);
        spikesType = strsplit(spikesHandles(curIdx).Tag,':');
        spikesType(1) = [];
        spikesType{2} = str2num(spikesType{2});
        hObject.Checked = 'on';
        showSpikes = true;
        spikesColor{curIdx} = rand(1, 3);
        % Get the members
        members = experiment.traceGroups.(spikesType{1}){spikesType{2}};
        spikesMembers{curIdx} = members;
    end
  end
  % Now that we have the spiking members and their color, get for each
  % frame, the neurons that spike
  % Preload spike info
  if(showSpikes)
      siz = size(currFrame);
      siz = siz(1:2);
      hold on;
      spikesOverlay = imagesc(zeros([siz 3]), 'HitTest', 'off');
      hold off;
      % Create the full spike list
      fullSpikingNeuronsList = [];
      firingNeuronColor = zeros(length(experiment.spikes), 3);
      
      for j = 1:length(spikesMembers)
        fullSpikingNeuronsList = [fullSpikingNeuronsList, spikesMembers{j}(:)'];
        if(~isempty(spikesMembers{j}))
            firingNeuronColor(spikesMembers{j}', :) = repmat(spikesColor{j}, length(spikesMembers{j}), 1);
        end
      end
      fullSpikingNeuronsList = unique(fullSpikingNeuronsList)';
      fullSpikeList = [];
      for j = fullSpikingNeuronsList(:)'
        if(isempty(experiment.spikes{j}))
          continue;
        end
          validSpikes = experiment.spikes{j}';
          fullSpikeList = [fullSpikeList; j*ones(size(validSpikes)), validSpikes];
      end
      % Set in frameSpikes each neuron that fires within that frame
      if(isempty(frameSpikes))
          frameSpikes = cell(experiment.numFrames, 1);
          framediff = mean(diff(experiment.t))/2;
          frameEdges = [experiment.t(1)-framediff experiment.t(:)' experiment.t(end)-framediff];
          for i = 1:length(experiment.t)
              minT = frameEdges(i);
              maxT = frameEdges(i+1);
              validSpikes = (fullSpikeList(:,2) > minT & fullSpikeList(:,2) <= maxT);
              validSpikesIdx = fullSpikeList(validSpikes, 1);
              frameSpikes{i} = unique(validSpikesIdx); % Don't need firing rates
          end
      end
  end
  updateImage();
end

%--------------------------------------------------------------------------
function updateShowBursts(hObject, eventData, type)
  if(nargin < 3)
    type = 'single';
  end

  if(strcmpi(hObject.Checked, 'on'))
    hObject.Checked = 'off';
    showBursts = false;
    switch type
      case 'all'
        parent = burstHandles(find(burstHandles == hObject.Parent));
        childsList = parent.Children;
        childsList(childsList == hObject) = [];
        for it = 1:length(childsList)
          curIdx = find(burstHandles == childsList(it));
          frameBursts{curIdx} = [];
          frameBurstsIdx{curIdx} = [];
          frameBurstsColor{curIdx} = [];
          burstsPixels{curIdx} = [];
          burstHandles(curIdx).Checked = 'off';
        end
        for it = 1:length(burstHandles)
          if(strcmpi(burstHandles(it).Checked, 'on'))
            showBursts = true;
            return;
          end
        end
      case 'single'
        curIdx = find(burstHandles == hObject);
        frameBursts{curIdx} = [];
        frameBurstsIdx{curIdx} = [];
        frameBurstsColor{curIdx} = [];
        burstsPixels{curIdx} = [];
        for it = 1:length(burstHandles)
          if(strcmpi(burstHandles(it).Checked, 'on'))
            showBursts = true;
            return;
          end
        end
    end
    if(~isempty(burstsOverlay))
      delete(burstsOverlay);
    end
  else
    switch type
      case 'all'
        parent = burstHandles(find(burstHandles == hObject.Parent));
        childsList = parent.Children;
        childsList(childsList == hObject) = [];
        for it = 1:length(childsList)
          curIdx = find(burstHandles == childsList(it));
          frameBursts{curIdx} = [];
          frameBurstsIdx{curIdx} = [];
          burstType = strsplit(burstHandles(curIdx).Tag,':');
          burstType(1) = [];
          burstType{2} = str2num(burstType{2});
          if(~isfield(experiment.traceBursts, burstType{1}) || ~isfield(experiment.traceBursts.(burstType{1}){burstType{2}}, 'frames'))
            logMsg(['No bursts found for: ' burstHandles(curIdx).Tag], 'w');
            continue;
          end
          burstHandles(curIdx).Checked = 'on';
          for i = 1:length(experiment.traceBursts.(burstType{1}){burstType{2}}.frames)
              frameBursts{curIdx} = [frameBursts{curIdx}; experiment.traceBursts.(burstType{1}){burstType{2}}.frames{i}'];
              frameBurstsIdx{curIdx} = [frameBurstsIdx{curIdx}; ones(size(experiment.traceBursts.(burstType{1}){burstType{2}}.frames{i}'))*i];
          end
          
          if(length(burstHandles) > 7)
            cmap = rand(length(burstHandles), 3);
          else
            cmap = lines(length(burstHandles));
          end
          frameBurstsColor{curIdx} = cmap(curIdx, :);
          % Get the mask
          validPixels = [];
          members = experiment.traceGroups.(burstType{1}){burstType{2}};
          for i = 1:length(members)
            validPixels = [validPixels; experiment.ROI{members(i)}.pixels(:)];
          end
          validPixels = unique(validPixels);
          burstsPixels{curIdx} = validPixels;
          showBursts = true;
          hObject.Checked = 'on';
        end
      case 'single'
        curIdx = find(burstHandles == hObject);
        frameBursts{curIdx} = [];
        frameBurstsIdx{curIdx} = [];
        burstType = strsplit(burstHandles(curIdx).Tag,':');
        burstType(1) = [];
        burstType{2} = str2num(burstType{2});
        if(~isfield(experiment.traceBursts, burstType{1}) || ~isfield(experiment.traceBursts.(burstType{1}){burstType{2}}, 'frames'))
          logMsg(['No bursts found for: ' burstHandles(curIdx).Tag], 'w');
          return;
        end
        hObject.Checked = 'on';
        showBursts = true;
        for i = 1:length(experiment.traceBursts.(burstType{1}){burstType{2}}.frames)
            frameBursts{curIdx} = [frameBursts{curIdx}; experiment.traceBursts.(burstType{1}){burstType{2}}.frames{i}'];
            frameBurstsIdx{curIdx} = [frameBurstsIdx{curIdx}; ones(size(experiment.traceBursts.(burstType{1}){burstType{2}}.frames{i}'))*i];
        end
        frameBurstsColor{curIdx} = rand(1, 3);
        % Get the mask
        validPixels = [];
        members = experiment.traceGroups.(burstType{1}){burstType{2}};
        for i = 1:length(members)
          validPixels = [validPixels; experiment.ROI{members(i)}.pixels(:)];
        end
        validPixels = unique(validPixels);
        burstsPixels{curIdx} = validPixels;
    end
  end
  updateImage();
end

%--------------------------------------------------------------------------
function updateShowPopulations(hObject, eventData, type)
  if(nargin < 3)
    type = 'single';
  end

  if(strcmpi(hObject.Checked, 'on'))
    hObject.Checked = 'off';
    showPopulations = false;
    switch type
      case 'all'
        parent = populationsHandles(find(populationsHandles == hObject.Parent));
        childsList = parent.Children;
        childsList(childsList == hObject) = [];
        for it = 1:length(childsList)
          curIdx = find(populationsHandles == childsList(it));
          framePopulationsColor{curIdx} = [];
          populationsPixels{curIdx} = [];
          populationsHandles(curIdx).Checked = 'off';
        end
        for it = 1:length(populationsHandles)
          if(strcmpi(populationsHandles(it).Checked, 'on'))
            showPopulations = true;
            updateImage();
            return;
          end
        end
      case 'single'
        curIdx = find(populationsHandles == hObject);
        framePopulationsColor{curIdx} = [];
        populationsPixels{curIdx} = [];
        for it = 1:length(populationsHandles)
          if(strcmpi(populationsHandles(it).Checked, 'on'))
            showPopulations = true;
            updateImage();
            return;
          end
        end
    end
    if(~isempty(populationsOverlay))
      delete(populationsOverlay);
    end
  else
    switch type
      case 'all'
        parent = populationsHandles(find(populationsHandles == hObject.Parent));
        childsList = parent.Children;
        childsList(childsList == hObject) = [];
        for it = 1:length(childsList)
          curIdx = find(populationsHandles == childsList(it));

          populationsType = strsplit(populationsHandles(curIdx).Tag,':');
          populationsType(1) = [];
          populationsType{2} = str2num(populationsType{2});
          if(~isfield(experiment.traceGroups, populationsType{1}))
            logMsg(['No populations found for: ' populationsHandles(curIdx).Tag], 'w');
            continue;
          end
          populationsHandles(curIdx).Checked = 'on';
          if(length(populationsHandles) > 7)
            cmap = rand(length(populationsHandles), 3);
          else
            cmap = lines(length(populationsHandles));
          end
          framePopulationsColor{curIdx} = cmap(curIdx, :);
          % Get the mask
          validPixels = [];
          members = experiment.traceGroups.(populationsType{1}){populationsType{2}};
          for i = 1:length(members)
            validPixels = [validPixels; experiment.ROI{members(i)}.pixels(:)];
          end
          validPixels = unique(validPixels);
          populationsPixels{curIdx} = validPixels;
          showPopulations = true;
          hObject.Checked = 'on';
        end
      case 'single'
        curIdx = find(populationsHandles == hObject);
        
        populationsType = strsplit(populationsHandles(curIdx).Tag,':');
        populationsType(1) = [];
        populationsType{2} = str2num(populationsType{2});
        if(~isfield(experiment.traceGroups, populationsType{1}))
            logMsg(['No populations found for: ' populationsHandles(curIdx).Tag], 'w');
            return;
        end
        hObject.Checked = 'on';
        showPopulations = true;
        framePopulationsColor{curIdx} = rand(1, 3);
        % Get the mask
        validPixels = [];
        members = experiment.traceGroups.(populationsType{1}){populationsType{2}};
        for i = 1:length(members)
          validPixels = [validPixels; experiment.ROI{members(i)}.pixels(:)];
        end
        validPixels = unique(validPixels);
        populationsPixels{curIdx} = validPixels;
    end
  end
  updateImage();
end

%--------------------------------------------------------------------------
function preferencesShowSpikes(~, ~)
    % Check if spikes exist
    if(~isfield(experiment, 'spikes') || isempty(experiment.spikes))
        return;
    end
    % Toggle the menu
    if(strcmp(hs.menu.show.spikes.Checked, 'on'))
        hs.menu.show.spikes.Checked = 'off';
        showSpikes = false;
        if(~isempty(spikesOverlay))
            delete(spikesOverlay);
        end
    else
        hs.menu.show.spikes.Checked = 'on';
        showSpikes = true;
    end
    % Preload spike info
    if(showSpikes)
        % Create the full spike list
        fullSpikeList = [];
        for j = 1:length(experiment.spikes)
            validSpikes = experiment.spikes{j}';
            fullSpikeList = [fullSpikeList; j*ones(size(validSpikes)), validSpikes];
        end
        % Set in frameSpikes each neuron that fires within that frame
        if(isempty(frameSpikes))
            frameSpikes = cell(length(experiment.t), 1);
            framediff = mean(diff(experiment.t))/2;
            frameEdges = [experiment.t(1)-framediff experiment.t' experiment.t(end)-framediff];
            for i = 1:length(frameSpikes)
                minT = frameEdges(i);
                maxT = frameEdges(i+1);
                validSpikes = (fullSpikeList(:,2) > minT & fullSpikeList(:,2) <= maxT);
                validSpikesIdx = fullSpikeList(validSpikes, 1);
                frameSpikes{i} = unique(validSpikesIdx); % Don't need firing rates
            end
        end
    end
    updateImage;
end

%--------------------------------------------------------------------------
function postPanZoomUpdate(~, ~)
  recreateOverlayText();
end

%--------------------------------------------------------------------------
function moviePlay(~, ~)
    movieRunning = ~movieRunning;
    if(movieRunning)
        moviePlayButton.String = 'Stop';
    else
        moviePlayButton.String = 'Play';
    end
    initialTime = clock;
    initialFrame = hs.mainWindowFramesSlider.Value;
    while(movieRunning && hs.mainWindowFramesSlider.Value < hs.mainWindowFramesSlider.Max)
        closestFrame = round(initialFrame+etime(clock, initialTime)*str2double(frameRateText.String));
        if(closestFrame > hs.mainWindowFramesSlider.Max)
            closestFrame = hs.mainWindowFramesSlider.Max;
        end
        hs.mainWindowFramesSlider.Value = closestFrame;
        currentFrameText.String = sprintf('%.0f', hs.mainWindowFramesSlider.Value);
        switch currentMovie
          case 1
            currFrame = getFrame(experiment, hs.mainWindowFramesSlider.Value, fID);
          case 2
            currFrame = getDenoisedFrame(experiment, hs.mainWindowFramesSlider.Value, denoisedBlocksPerFrame);
          case 3
            currFrame = getFrame(experiment, hs.mainWindowFramesSlider.Value, fID);
            currFrame2 = getDenoisedFrame(experiment, hs.mainWindowFramesSlider.Value, denoisedBlocksPerFrame);
            %currFrame2 = currFrame;
        end
        if(~strcmpi(avgTraceCorrection, 'none'))
          applyAvgTraceCorrection();
        end
        updateImage();
        drawnow;
    end
    if(hs.mainWindowFramesSlider.Value == hs.mainWindowFramesSlider.Max)
        movieRunning = false;
        moviePlayButton.String = 'Play';
    end
end

%--------------------------------------------------------------------------
function KeyPress(hObject, eventData)
  switch eventData.Key
    case 'space'
      moviePlay(hObject, eventData)
    case 'rightarrow'
      if(hs.mainWindowFramesSlider.Value < hs.mainWindowFramesSlider.Max)
        hs.mainWindowFramesSlider.Value = hs.mainWindowFramesSlider.Value + 1;
        updateImage;
      end
    case 'leftarrow'
      if(hs.mainWindowFramesSlider.Value > hs.mainWindowFramesSlider.Min)
        hs.mainWindowFramesSlider.Value = hs.mainWindowFramesSlider.Value - 1;
        updateImage;
      end
    case 'uparrow'
      if(hs.mainWindowFramesSlider.Value < hs.mainWindowFramesSlider.Max-10)
        hs.mainWindowFramesSlider.Value = hs.mainWindowFramesSlider.Value + 10;
        updateImage();
      end
    case 'downarrow'
      if(hs.mainWindowFramesSlider.Value > hs.mainWindowFramesSlider.Min+10)
        hs.mainWindowFramesSlider.Value = hs.mainWindowFramesSlider.Value - 10;
        updateImage();
      end
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
          updateImage();
          autoLevelsReset = true;
        end
      case 'max'
        if(input <= minIntensity)
          errordlg('Maximum intensity has to be greater than minimum intensity','Invalid Input','modal');
          hObject.String = num2str(maxIntensity);
          uicontrol(hObject);
        else
          maxIntensity = input;
          updateImage();
          autoLevelsReset = true;
        end
    end
  end
end

%--------------------------------------------------------------------------
function currentFrameChange(hObject, ~)
    input = str2double(get(hObject,'string'));
    if isnan(input)
        errordlg('You must enter a numeric value','Invalid Input','modal')
        uicontrol(hObject)
        return
    end
    if(input > hs.mainWindowFramesSlider.Max)
      input = hs.mainWindowFramesSlider.Max;
    end
    if(input < hs.mainWindowFramesSlider.Min)
      input = hs.mainWindowFramesSlider.Min;
    end
    hs.mainWindowFramesSlider.Value = round(input);
    
    switch currentMovie
      case 1
        currFrame = getFrame(experiment, hs.mainWindowFramesSlider.Value, fID);
      case 2
        currFrame = getDenoisedFrame(experiment, hs.mainWindowFramesSlider.Value, denoisedBlocksPerFrame);
      case 3
        currFrame = getFrame(experiment, hs.mainWindowFramesSlider.Value, fID);
        %currFrame2 = currFrame;
        currFrame2 = getDenoisedFrame(experiment, hs.mainWindowFramesSlider.Value, denoisedBlocksPerFrame);
    end
    if(~strcmpi(avgTraceCorrection, 'none'))
      applyAvgTraceCorrection();
    end
    %me = double(mean(double(currFrame(:))));
    %se = double(std(double(currFrame(:))));
    %currFrame(currFrame > me+5*se) = NaN;

    updateImage();
end

%--------------------------------------------------------------------------
function menuPreferencesRealSize(~, ~, ~)
  realSize = ~realSize;
  mainWindowResize(gcbo);
  updateImage();
  if(realSize)
    hs.menu.preferences.realSize.Checked = 'on';
  else
    hs.menu.preferences.realSize.Checked = 'off';
  end
end

%--------------------------------------------------------------------------
function menuPreferencesBaselineCorrection(hObject, ~)
  if(strcmp(hObject.Checked, 'off'))
    baseLineCorrection = true;
    hObject.Checked = 'on';
  else
    baseLineCorrection = false;
    hObject.Checked = 'off';
  end
  frameChange();
  autoLevelsReset = true;
  autoLevels();
  updateImage();
end


%--------------------------------------------------------------------------
function menuPreferencesSelectedMovie(hObject, ~, selected)
  if(~isempty(hObject))
    % Clicking myself does nothing
    if(strcmp(hObject.Checked, 'on'))
      return;
    end
  end
  
  menuList = findobj(gcf, '-regexp','Tag', 'selectedMovie');
  % Uncheck all
  for i = 1:length(menuList)
    menuList(i).Checked = 'off';
  end
  
  if(~isempty(hObject))
    % Turn current selection on
    hObject.Checked = 'on';
  end
  
  % Do whatever you have to do
  switch selected
    case 'original'
      currentMovie = 1;
    case 'denoised'
      currentMovie = 2;
    case 'both'
      currentMovie = 3;
  end
  % 1 original - 2 denoised - 3 both - using ints instead of strings to speed up frame grabbing
  switch currentMovie
    case 1
      delete(hs.mainWindowFramesAxes);
      if(~isempty(hs.mainWindowFramesAxes2) && isvalid(hs.mainWindowFramesAxes2))
        delete(hs.mainWindowFramesAxes2)
      end
      hs.mainWindowFramesAxes = axes('Parent', axesContainer);
      
      imData = imagesc(currFrame, 'HitTest', 'off');
      axis equal tight;
      maxIntensity = max(currFrame(:));
      minIntensity = min(currFrame(:));
      set(hs.mainWindowFramesAxes, 'XTick', []);
      set(hs.mainWindowFramesAxes, 'YTick', []);
      set(hs.mainWindowFramesAxes, 'LooseInset', [0,0,0,0]);
      box on;
      
      %overlayData = imagesc(ones(size(currFrame)), 'HitTest', 'off');
      hs.mainWindowFramesAxes.UIContextMenu = hs.rightClickMenu.root;
    case 2
      if(ischar(experiment.denoisedData))
        ncbar.automatic('Loading denoised data');
        experiment = loadTraces(experiment, 'denoisedData');
        ncbar.close();
      end
      denoisedBlocksPerFrame = [arrayfun(@(x)x.frames(1), experiment.denoisedData)', arrayfun(@(x)x.frames(2), experiment.denoisedData)'];
      
      delete(hs.mainWindowFramesAxes);
      if(~isempty(hs.mainWindowFramesAxes2) && isvalid(hs.mainWindowFramesAxes2))
        delete(hs.mainWindowFramesAxes2)
      end
      hs.mainWindowFramesAxes = axes('Parent', axesContainer);
      
      imData = imagesc(currFrame, 'HitTest', 'off');
      axis equal tight;
      maxIntensity = max(currFrame(:));
      minIntensity = min(currFrame(:));
      set(hs.mainWindowFramesAxes, 'XTick', []);
      set(hs.mainWindowFramesAxes, 'YTick', []);
      set(hs.mainWindowFramesAxes, 'LooseInset', [0,0,0,0]);
      box on;
      
      hs.mainWindowFramesAxes.UIContextMenu = hs.rightClickMenu.root;
      
    case 3
      if(ischar(experiment.denoisedData))
        ncbar.automatic('Loading denoised data');
        experiment = loadTraces(experiment, 'denoisedData');
        ncbar.close();
      end
      denoisedBlocksPerFrame = [arrayfun(@(x)x.frames(1), experiment.denoisedData)', arrayfun(@(x)x.frames(2), experiment.denoisedData)'];
      delete(hs.mainWindowFramesAxes);
      if(~isempty(hs.mainWindowFramesAxes2) && isvalid(hs.mainWindowFramesAxes2))
        delete(hs.mainWindowFramesAxes2)
      end
      ax = multigap_subplot(1, 2, 'Parent', axesContainer);
      hs.mainWindowFramesAxes = ax(1);
      axes(hs.mainWindowFramesAxes);
      
      imData = imagesc(currFrame, 'HitTest', 'off');
      axis equal tight;
      maxIntensity = max(currFrame(:));
      minIntensity = min(currFrame(:));
      set(hs.mainWindowFramesAxes, 'XTick', []);
      set(hs.mainWindowFramesAxes, 'YTick', []);
      set(hs.mainWindowFramesAxes, 'LooseInset', [0,0,0,0]);
      box on;
      
      %overlayData = imagesc(ones(size(currFrame)), 'HitTest', 'off');
      hs.mainWindowFramesAxes.UIContextMenu = hs.rightClickMenu.root;
      
      hs.mainWindowFramesAxes2 = ax(2);
      axes(hs.mainWindowFramesAxes2);
      currFrame2 = currFrame;
      imData2 = imagesc(currFrame, 'HitTest', 'off');
      axis equal tight;
      maxIntensity2 = max(currFrame(:));
      minIntensity2 = min(currFrame(:));
      set(hs.mainWindowFramesAxes2, 'XTick', []);
      set(hs.mainWindowFramesAxes2, 'YTick', []);
      set(hs.mainWindowFramesAxes2, 'LooseInset', [0,0,0,0]);
      box on;
      
      axes(hs.mainWindowFramesAxes);
      linkaxes([hs.mainWindowFramesAxes hs.mainWindowFramesAxes2]);
  end
  if(isfield(experiment, 'tag') && strcmp(experiment.tag, 'dummy'))
    % Change the axes to match the first block
    ylim([1, experiment.denoisedData(1).blockSize(2)]+experiment.denoisedData(1).blockCoordinates(2)-1);
    xlim([1, experiment.denoisedData(1).blockSize(1)]+experiment.denoisedData(1).blockCoordinates(1)-1);
  end
  frameChange([],[]);
  autoLevelsReset = true;
  autoLevels();
  updateImage();
  mainWindowResize();
end

%--------------------------------------------------------------------------
function menuPreferencesAvgTraceCorrection(hObject, ~, mode)
  menuList = findobj(gcf, '-regexp','Tag', 'avgTraceCorrection');
  % Disable all menus, and correction if we click on an already checked one
  for i = 1:length(menuList)
    if(strcmp(menuList(i).Checked, 'on'))
      if(menuList(i) == hObject)
        menuList(i).Checked = 'off';
        avgTraceCorrection = 'none';
        frameChange();
        autoLevelsReset = true;
        autoLevels();
        updateImage();
        return;
      else
        menuList(i).Checked = 'off';
      end
    end
  end
  % Turn current selection on
  hObject.Checked = 'on';
  avgTraceCorrection = mode;
  frameChange();
  autoLevelsReset = true;
  autoLevels();
  updateImage();
end


%--------------------------------------------------------------------------
function rightClickPlotNeuronTrace(~, ~, type)
    clickedPoint = round(get(hs.mainWindowFramesAxes,'currentpoint'));
    plotSingleNeuronTrace(clickedPoint, type);
end


%--------------------------------------------------------------------------
function exportCurrentImage(~, ~)
    [fileName, pathName] = uiputfile({'*.png'; '*.tiff'}, 'Save current image', experiment.folder); 
    if(fileName ~= 0)
        export_fig([pathName fileName], hs.mainWindowFramesAxes);
    end
end

%--------------------------------------------------------------------------
function exportCurrentMovie(~, ~)
  % Export movie options
  exportMovieOptionsCurrent = experiment.exportMovieOptionsCurrent;
  exportMovieOptionsCurrent.frameRate = str2double(frameRateText.String);
  frameRange = [hs.mainWindowFramesSlider.Value hs.mainWindowFramesSlider.Max];

  [success, exportMovieOptionsCurrent] = optionsWindow(exportMovieOptionsCurrent);
  if(~success)
    return;
  end

  [fileName, pathName] = uiputfile({'*'}, 'Save current movie', experiment.folder);
  if(fileName == 0)
    return;
  end
  switch exportMovieOptionsCurrent.rangeSelection
    case 'frames'
      frameRange = exportMovieOptionsCurrent.range;
    case 'time'
      frameRange = round(exportMovieOptionsCurrent.range*experiment.fps);
  end
  % Little bit of consistency checks
    if(frameRange(1) < 1)
      frameRange(1) = 1;
    end
    if(frameRange(2) > hs.mainWindowFramesSlider.Max)
      frameRange(2) = hs.mainWindowFramesSlider.Max;
    end
  if(isempty(exportMovieOptionsCurrent.frameSkip) || exportMovieOptionsCurrent.frameSkip == 0)
    exportMovieOptionsCurrent.frameSkip = 1;
  end
  % Create the movie
  %if(exportMovieOptionsCurrent.compressMovie)
  %  newMovie = VideoWriter([pathName fileName], 'Motion JPEG AVI');
  %else
    newMovie = VideoWriter([pathName fileName], exportMovieOptionsCurrent.profile);
  %end
  % The iterator loop
  switch exportMovieOptionsCurrent.resamplingMethod
    case 'none'
      frameList = frameRange(1):exportMovieOptionsCurrent.frameSkip:frameRange(2);
    otherwise
      if(exportMovieOptionsCurrent.frameRate > experiment.fps)
        logMsg('New framerate cannot be higher with the selected resampling method. Use none instead', 'e');
        return;
      end
      if(mod(experiment.fps, exportMovieOptionsCurrent.frameRate) ~=0)
        closestFrameRate = 1/round(experiment.fps/exportMovieOptionsCurrent.frameRate)*experiment.fps;
        logMsg(sprintf('For the current resampling method the new frame rate has to be a divisor of the original one. Using %.3f instead', closestFrameRate), 'w');
        exportMovieOptionsCurrent.frameRate = closestFrameRate;
        frameWindow = round(experiment.fps/exportMovieOptionsCurrent.frameRate);
      end
      % New consistency check
      if(frameRange(2)+frameWindow-1 > hs.mainWindowFramesSlider.Max)
        frameRange(2) = hs.mainWindowFramesSlider.Max-frameWindow+1;
      end
      frameList = frameRange(1):frameWindow:frameRange(2);
  end
  newMovie.FrameRate = exportMovieOptionsCurrent.frameRate;
  open(newMovie);
  ncbar('Saving current movie');
  numFrames = length(frameList);
  prevUnits = hs.mainWindowFramesAxes.Units;
  hs.mainWindowFramesAxes.Units = 'pixels';
  frame = getframe(hs.mainWindowFramesAxes, hs.mainWindowFramesAxes.Position);
  for it = 1:numFrames
    %frame = getframe(hs.mainWindowFramesAxes, hs.mainWindowFramesAxes.Position-[0 0 1 1]);
    switch exportMovieOptionsCurrent.resamplingMethod
      case 'none'
        hs.mainWindowFramesSlider.Value = frameList(it);
        currentFrameText.String = sprintf('%.0f', hs.mainWindowFramesSlider.Value);
        frameChange();
        updateImage();
        frame = getframe(hs.mainWindowFramesAxes, hs.mainWindowFramesAxes.Position);
        writeVideo(newMovie, frame.cdata(:, :, :));
      otherwise
        frameData = zeros(size(frame.cdata));
        for it2 = 1:frameWindow
          hs.mainWindowFramesSlider.Value = frameList(it)+it2-1;
          currentFrameText.String = sprintf('%.0f', hs.mainWindowFramesSlider.Value);
          frameChange();
          frame = getframe(hs.mainWindowFramesAxes, hs.mainWindowFramesAxes.Position);
          frameData = frameData + double(frame.cdata(:, :, :));
        end
        if(strcmpi(exportMovieOptionsCurrent.resamplingMethod, 'mean'))
          frameData = frameData/frameWindow;
        end
        %whos frameData
        %size(frameData)
        writeVideo(newMovie, uint8(frameData));
        updateImage();
    end
    %frame = getframe(hs.mainWindowFramesAxes);
    
    ncbar.update(it/numFrames);
  end
  hs.mainWindowFramesAxes.Units = prevUnits;
  ncbar.close();
  close(newMovie);
  experiment.exportMovieOptionsCurrent = exportMovieOptionsCurrent;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Utility functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------------------------------------------------------------
function plotSingleNeuronTrace(clickedPoint, type)
  closestPixel = sub2ind([experiment.height, experiment.width], clickedPoint(1,2), clickedPoint(1,1));
  % Check interesection with the ROIs
  for i = 1:length(experiment.ROI)
      validPixels = experiment.ROI{i}.pixels;
      % Valid ROI found
      if(find(validPixels == closestPixel))
        newPos = [hs.mainWindow.Position(1)+hs.mainWindow.Position(3), hs.mainWindow.Position(2)];
        hFig = figure;
        hFig.Position = setFigurePosition(hs.mainWindow, 'width', 800, 'height', 200);
        switch type
          case 'raw'
            if(ischar(experiment.rawTraces))
              ncbar.automatic('Loading traces');
              experiment = loadTraces(experiment, 'raw');
              ncbar.close();
            end
            plot(experiment.rawT, experiment.rawTraces(:, i));
            hold on;
            if(isfield(experiment, 'spikes'))
              spikeTimes = experiment.spikes{i};
            end
          case 'smoothed'
            if(ischar(experiment.traces))
              ncbar.automatic('Loading traces');
              experiment = loadTraces(experiment, 'normal');
              ncbar.close();
            end
            plot(experiment.t, experiment.traces(:, i));
            hold on;
            if(isfield(experiment, 'spikes'))
              spikeTimes = experiment.spikes{i};
            end
        end

        % Plot inside the trace
        %plot(repmat(spikeTimes,2,1), cat(1,ones(size(spikeTimes))*min(experiment.traces(:, i)),ones(size(spikeTimes))*max(experiment.traces(:, i)))*0.5, 'LineWidth', 1, 'Color', 'k');
        % Plot above the trace
        if(isfield(experiment, 'spikes'))
          plot(repmat(spikeTimes,2,1), cat(1,ones(size(spikeTimes))*min(experiment.traces(:, i)),ones(size(spikeTimes))*max(experiment.traces(:, i)))*0.5+max(experiment.traces(:, i))*1.1, 'LineWidth', 1, 'Color', 'k');
        end
        xlabel('time');
        ylabel('Fluorescence');
        if(iscell(ROIid))
          ROIname = ROIid(i);
        else
          ROIname = num2str(ROIid(i));
        end
        title(['Trace for ROI ' ROIname]);
        uimenu(hFig, 'Label', 'Export',  'Callback', {@exportFigCallback, {'*.png';'*.tiff';'*.pdf'}, [experiment.folder 'singleTrace']});
        return;
      end
  end
  logMsg('No neuron found');
end

%--------------------------------------------------------------------------
function updateImage()
  set(imData, 'CData', currFrame);

  caxis(hs.mainWindowFramesAxes, [minIntensity maxIntensity]);
  if(currentMovie == 3)
    set(imData2, 'CData', currFrame2);
    if(minIntensity2 <= maxIntensity2)
      caxis(hs.mainWindowFramesAxes2, [minIntensity2 maxIntensity2]);
    end
  end

  if(showPopulations)
    plotPopulations();
  end

  if(showBursts)
    plotBursts();
  end
  if(showSpikes)
    plotSpikeEvents();
  end
  %drawnow;
  recreateOverlayText();
end


%--------------------------------------------------------------------------
function plotBursts()
  it = hs.mainWindowFramesSlider.Value;
  delete(burstsOverlay);
  % Check if there is  a burst in this frame
  burstsHere = [];
  for i = 1:length(frameBursts)
    if(any(it == frameBursts{i}))
      burstsHere = [burstsHere; i];
    end
  end
  if(isempty(burstsHere))
    return;
  end
  axes(hs.mainWindowFramesAxes);
  hold on;
  burstsOverlay = imagesc(zeros([experiment.height experiment.width 3]), 'HitTest', 'off');
  hold off;
  set(burstsOverlay, 'AlphaData', zeros([experiment.height experiment.width]));
  overlayFrameA = zeros([experiment.height experiment.width]);
  overlayFrameR = zeros([experiment.height experiment.width]);
  overlayFrameG = zeros([experiment.height experiment.width]);
  overlayFrameB = zeros([experiment.height experiment.width]);
  for i = 1:length(burstsHere)
    curIdx = burstsHere(i);
    overlayFrameA(burstsPixels{curIdx}) = 0.6;
    overlayFrameR(burstsPixels{curIdx}) = frameBurstsColor{curIdx}(1);
    overlayFrameG(burstsPixels{curIdx}) = frameBurstsColor{curIdx}(2);
    overlayFrameB(burstsPixels{curIdx}) = frameBurstsColor{curIdx}(3);
  end
  % Set alpha = 1 only for perimeters
  overlayFrameP = ~~overlayFrameA;
  overlayFrameP = bwperim(overlayFrameP,4);
  overlayFrameA(overlayFrameP) = 1;

  set(burstsOverlay, 'CData', cat(3, overlayFrameR, overlayFrameG, overlayFrameB));
  set(burstsOverlay, 'AlphaData', overlayFrameA);
end

%--------------------------------------------------------------------------
function plotPopulations()
  delete(populationsOverlay);
  
  axes(hs.mainWindowFramesAxes);
  hold on;
  populationsOverlay = imagesc(zeros([experiment.height experiment.width 3]), 'HitTest', 'off');
  hold off;
  set(populationsOverlay, 'AlphaData', zeros([experiment.height experiment.width]));
  overlayFrameA = zeros([experiment.height experiment.width]);
  overlayFrameR = zeros([experiment.height experiment.width]);
  overlayFrameG = zeros([experiment.height experiment.width]);
  overlayFrameB = zeros([experiment.height experiment.width]);
  
  %legendNames = {};
  for curIdx = 1:length(populationsPixels)
    if(isempty(populationsPixels{curIdx}))
      continue;
    end
    %legendNames{end+1} = populationsHandles(curIdx).Label;
    overlayFrameA(populationsPixels{curIdx}) = 0.5;
    overlayFrameR(populationsPixels{curIdx}) = framePopulationsColor{curIdx}(1);
    overlayFrameG(populationsPixels{curIdx}) = framePopulationsColor{curIdx}(2);
    overlayFrameB(populationsPixels{curIdx}) = framePopulationsColor{curIdx}(3);
  end
  %legend(legendNames);
  % Set alpha = 1 only for perimeters
  overlayFrameP = ~~overlayFrameA;
  overlayFrameP = bwperim(overlayFrameP,4);
  overlayFrameA(overlayFrameP) = 1;
  set(populationsOverlay, 'CData', cat(3, overlayFrameR, overlayFrameG, overlayFrameB));
  set(populationsOverlay, 'AlphaData', overlayFrameA);
  
end

%--------------------------------------------------------------------------
function plotSpikeEvents()
    if(~showSpikes || isempty(frameSpikes))
        return;
    end
    it = hs.mainWindowFramesSlider.Value;
    curSpikes = frameSpikes{it};
    validPixels = [];
    overlayFrameA = zeros(experiment.height, experiment.width);
    overlayFrameR = overlayFrameA;
    overlayFrameG = overlayFrameA;
    overlayFrameB = overlayFrameA;

    firingCenters = [];
    firingCentersColor = [];
    scalingFactor = experiment.width/size(currFrame,2); % In case of image resize
    for i = 1:length(curSpikes)
      firingPixels = experiment.ROI{curSpikes(i)}.pixels;
      firingCenters = [firingCenters; experiment.ROI{curSpikes(i)}.center/scalingFactor];
      firingCentersColor = [firingCentersColor; firingNeuronColor(curSpikes(i), :)];
      validPixels = [validPixels; firingPixels];
      overlayFrameA(firingPixels) = 0.4;
      overlayFrameR(firingPixels) = firingNeuronColor(curSpikes(i), 1);
      overlayFrameG(firingPixels) = firingNeuronColor(curSpikes(i), 2);
      overlayFrameB(firingPixels) = firingNeuronColor(curSpikes(i), 3);
    end
    validPixels = unique(validPixels);
    
    siz = size(currFrame);
    siz = siz(1:2);
    if(isempty(spikesOverlay))
      axes(hs.mainWindowFramesAxes);
      hold on;
      spikesOverlay = imagesc(zeros([siz 3]), 'HitTest', 'off');
      hold off;
    end
    if(~isempty(spikesOverlay))
      set(spikesOverlay, 'CData', zeros([siz 3]));
      set(spikesOverlay, 'AlphaData', zeros(siz));
    end
        
    % Set alpha = 1 only for perimeters
    overlayFrameP = ~~overlayFrameA;
    overlayFrameP = bwperim(overlayFrameP,4);
    overlayFrameA(overlayFrameP) = 1;
    % Now rescale them in case the image is different
    if(size(currFrame, 1) ~= size(overlayFrameA, 1))
      overlayFrameA = imresize(overlayFrameA, siz);
      overlayFrameR = imresize(overlayFrameR, siz);
      overlayFrameG = imresize(overlayFrameG, siz);
      overlayFrameB = imresize(overlayFrameB, siz);
      %overlayFrameA = ~~overlayFrameA*0.4;
      %overlayFrameR = ~~overlayFrameR;
      %overlayFrameG = ~~overlayFrameG;
      %overlayFrameB = ~~overlayFrameB;
    end
    if(~isempty(spikesOverlay))
      set(spikesOverlay, 'CData', cat(3, overlayFrameR, overlayFrameG, overlayFrameB));
      set(spikesOverlay, 'AlphaData', overlayFrameA);
      if(~isempty(firingCenters))
        if(~isempty(spikesScatterOverlay))
          delete(spikesScatterOverlay)
        end
%         spikesScatterOverlay = scatter(firingCenters(:,1), firingCenters(:,2), 32, firingCentersColor, 'o');
      end
    end
end

%--------------------------------------------------------------------------
function applyBaselineCorrection()
  baselineImg = zeros(size(currFrame));
  currentT = hs.mainWindowFramesSlider.Value;
  for it = 1:length(experiment.ROI)
    baselineImg(experiment.ROI{it}.pixels) = experiment.baseLine(currentT, it);
  end
  baselineImg = regionfill(baselineImg, ~baselineImg);
  %figure;imagesc(baselineImg);
  % Substract the mean value
  currFrame = currFrame - uint16(baselineImg);
end

%--------------------------------------------------------------------------
function applyAvgTraceCorrection()
  switch avgTraceCorrection
    case 'average'
      avgF = experiment.avgTrace;
    case 'lower'
      avgF = experiment.avgTraceLower;
    case 'upper'
      avgF = experiment.avgTraceUpper;
    case 'none'
      return;
  end
  % If true, we need to interpolate
  if(experiment.numFrames ~= length(experiment.avgT))
    currentT = hs.mainWindowFramesSlider.Value/experiment.fps;
    currentF = interp1(experiment.avgT, avgF, currentT, 'nearest', 'extrap');
  else
    currentF = avgF(hs.mainWindowFramesSlider.Value);
  end
  % Substract the mean value
  currFrame = currFrame - currentF;
end

%--------------------------------------------------------------------------
function cleanMenu()
    a = findall(gcf);
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

%--------------------------------------------------------------------------
function recreateOverlayText()
  overlayText = ['t = ' sprintf('%.2f', hs.mainWindowFramesSlider.Value/experiment.fps) ' s'];
  if(~isempty(overlayData) && ishandle(overlayData) && isvalid(overlayData))
    delete(overlayData);
  end
  xl = xlim(hs.mainWindowFramesAxes);
  yl = ylim(hs.mainWindowFramesAxes);
  if(verLessThan('matlab','9.1'))
    axes(hs.mainWindowFramesAxes);
    overlayData = text(xl(1)+diff(xl)*0.05, yl(1)+diff(yl)*0.05, overlayText, 'Color','w','FontSize', 16);
  else
    overlayData = text(hs.mainWindowFramesAxes, xl(1)+diff(xl)*0.05, yl(1)+diff(yl)*0.05, overlayText, 'Color','w','FontSize', 16);
  end
  
end

end
