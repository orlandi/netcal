function [hFigW] = viewRecordingPlugin(~, ~, experiment, varargin)
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
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

%#ok<*AGROW>
%#ok<*ASGLU>
%#ok<*FXUP>
%#ok<*INUSD>

persistent defaultFolder;

appFolder = fileparts(mfilename('fullpath'));
appFolder = [appFolder filesep '..'];

warning('off', 'MATLAB:dispatcher:nameConflict');
warning('off', 'MATLAB:Java:DuplicateClass');
addpath(genpath(appFolder));
rmpath(genpath([appFolder filesep '.git'])) % But exclude .git/
rmpath(genpath([appFolder filesep 'old'])) % And old
rmpath(genpath(fullfile(appFolder, 'external', 'OASIS_matlab', 'optimization', 'cvx'))); % And cvx
subFolderList = dir(appFolder);
for i = 1:length(subFolderList)
  if(subFolderList(i).isdir && any(strfind(subFolderList(i).name, 'netcal')))
    rmpath(genpath([appFolder filesep subFolderList(i).name])) % And any subfolders containing netcal
  end
end

%%% Java includes
javaaddpath({fullfile(appFolder, 'internal', 'java'), ...
            fullfile(appFolder, 'external', 'JavaTreeWrapper', '+uiextras', '+jTree', 'UIExtrasTree.jar')});
import('uiextras.jTree.*');
warning('on', 'MATLAB:dispatcher:nameConflict');

experiment = loadExperiment('defaultFolder', defaultFolder);
if(isempty(experiment))
return;
end
defaultFolder = experiment.folder;
experiment.virtual = true;

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

% Check if the handle exists. If not, update it - needs to go here for login purposes
[newExperiment, success] = experimentHandleCheck(experiment);
if(~success)
  return;
end
experiment = checkGroups(experiment);

[newExperiment, success] = precacheHISframes(newExperiment);
if(~success)
  return;
end

exportMovieOptionsCurrent = exportMovieOptions;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Create components
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
initVisible = 'off';
try
  [fpa, fpb, fpc] = fileparts(experiment.handle);
  if(strcmpi(fpc, '.avi'))
    initVisible = 'on';
  end
catch
end
hs.mainWindow = figure('Visible',initVisible,...
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
hFigW.Position = setFigurePosition(gui, 'width', 800, 'height', 700);
if(~isempty(gui))
  setappdata(hFigW, 'logHandle', getappdata(gcbf, 'logHandle'));
end


if(~isequaln(newExperiment, experiment))
  experimentChanged = true;
else
  experimentChanged = false;
end
experiment = newExperiment;
clear newExperiment;

if(isfield(experiment, 'ROI'))
    ROIid = getROIid(experiment.ROI);
end
experiment = loadTraces(experiment, 'all');



%%% The menu
hs.menu.file.root = uimenu(hs.mainWindow, 'Label', 'File');
uimenu(hs.menu.file.root, 'Label', 'Exit and discard changes', 'Callback', {@closeCallback, false});
uimenu(hs.menu.file.root, 'Label', 'Exit and save changes', 'Callback', {@closeCallback, false});
uimenu(hs.menu.file.root, 'Label', 'Exit (default)', 'Callback', @closeCallback);


hs.menu.preferences.root = uimenu(hs.mainWindow, 'Label', 'Preferences', 'Enable', 'on');
hs.menu.preferences.realSize = uimenu(hs.menu.preferences.root, 'Label', 'Real Size', 'Enable', 'on', 'Callback', @menuPreferencesRealSize);

hs.menu.show.root = uimenu(hs.mainWindow, 'Label', 'Show', 'Visible', 'off');

% Menu to show spikes
if(isfield(experiment, 'spikes'))
  hs.menu.show.spikes = generateSelectionMenu(experiment, hs.menu.show.root);
  hs.menu.show.spikes.root.Label = 'Spikes';
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
  hs.menu.show.root.Visible = 'on';
end

% Menu to show populations
if(isfield(experiment, 'traceGroups'))
  hs.menu.show.populations = generateSelectionMenu(experiment, hs.menu.show.root);
  hs.menu.show.populations.root.Label = 'Populations';
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
  hs.menu.show.root.Visible = 'on';
end

% Menu to show bursts
if(isfield(experiment, 'traceBursts'))
  hs.menu.show.bursts = generateSelectionMenu(experiment, hs.menu.show.root);
  hs.menu.show.bursts.root.Label = 'Bursts';
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
  hs.menu.show.root.Visible = 'on';
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
hs.mainWindowFramesAxes = axes('Parent', hs.mainWindowFramesPanel);

%%% Preinitialize the video
[fID, experiment] = openVideoStream(experiment);

currFrame = getFrame(experiment, 1, fID);

%me = mean(double(currFrame(:)));
%se = std(double(currFrame(:)));
%currFrame(currFrame > me+10*se) = NaN;
axis(hs.mainWindowFramesAxes);
imData = imagesc(currFrame, 'HitTest', 'off');

axis equal tight;
maxIntensity = max(currFrame(:));
minIntensity = min(currFrame(:));
set(hs.mainWindowFramesAxes, 'XTick', []);
set(hs.mainWindowFramesAxes, 'YTick', []);
set(hs.mainWindowFramesAxes, 'LooseInset', [0,0,0,0]);
box on;
hold on;
overlayData = imagesc(ones(size(currFrame)), 'HitTest', 'off');
    
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
set(b, 'Widths', [30 100 80], 'Spacing', 5, 'Padding', 0);

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
uicontrol('Parent', b, 'Style','popup',   'Units','pixel', 'String',htmlStrings, 'Callback', @setmap, 'FontSize', textFontSize);

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
set(hs.mainWindowSuperBox, 'Heights', [-1 100], 'Padding', 0, 'Spacing', 0);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Final init
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
colormap(gray);
set(hs.mainWindowGrid, 'Widths', [minGridBorder -1 25 200 minGridBorder],...
  'Heights', [minGridBorder -1 100 minGridBorder]);
%set(hs.mainWindowGrid, 'Widths', [size(currFrame,2) 25 -1], 'Heights', [size(currFrame,1) -1]);
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

mainWindowResize();
try
  autoLevels();
catch ME
  logMsg(ME.message, 'e');
end

if(isempty(gui))
  waitfor(hFigW);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Callbacks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function mainWindowResize(~, ~)
  try
    set(hs.mainWindowGrid, 'Widths', [minGridBorder -1 25 200 minGridBorder], 'Heights', [minGridBorder -1 100 minGridBorder]);
  catch
    return;
  end
    pos = plotboxpos(hs.mainWindowFramesAxes);
    hs.mainWindowColorbar.Position(2) = pos(2);
    hs.mainWindowColorbar.Position(4) = pos(4);
    hs.mainWindowFramesSlider.Position(1) = pos(1);
    hs.mainWindowFramesSlider.Position(3) = pos(3);
    realRatio = size(currFrame,2)/size(currFrame,1);
    curPos = hs.mainWindowFramesAxes.Position;
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
    %[pos(3) pos(4) realRatio curRatio]
    updateImage();
end

%--------------------------------------------------------------------------
function setmap(hObject, ~)
    val = hObject.Value;
    maps = hObject.String;

    newmap = maps{val};
    mapNamePosition = strfind(newmap, 'png">');
    newmap = newmap(mapNamePosition+5:end);
    colormap(newmap);
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
  maxIntensityText.String = sprintf('%.2f', maxIntensity);
  minIntensityText.String = sprintf('%.2f', minIntensity);
  updateImage();
  autoLevelsReset = false;
end

%--------------------------------------------------------------------------
function frameChange(~, ~)
  hs.mainWindowFramesSlider.Value = round(hs.mainWindowFramesSlider.Value);
  currFrame = getFrame(experiment, hs.mainWindowFramesSlider.Value, fID);
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
          spikesType = strsplit(spikesHandles(curIdx).Tag);
          if(length(spikesType) > 2)
            spikesType = {strcat(spikesType{1:end-1}) spikesType{end}};
          end
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
        spikesType = strsplit(spikesHandles(curIdx).Tag);
        if(length(spikesType) > 2)
          spikesType = {strcat(spikesType{1:end-1}) spikesType{end}};
        end
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
      spikesOverlay = imagesc(zeros([siz 3]), 'HitTest', 'off');
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
          burstType = strsplit(burstHandles(curIdx).Tag);
          if(length(burstType) > 2)
            burstType = {strcat(burstType{1:end-1}) burstType{end}};
          end
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
        burstType = strsplit(burstHandles(curIdx).Tag);
        if(length(burstType) > 2)
          burstType = {strcat(burstType{1:end-1}) burstType{end}};
        end
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

          populationsType = strsplit(populationsHandles(curIdx).Tag);
          if(length(populationsType) > 2)
            populationsType = {strcat(populationsType{1:end-1}) populationsType{end}};
          end
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
        
        populationsType = strsplit(populationsHandles(curIdx).Tag);
        if(length(populationsType) > 2)
          populationsType = {strcat(populationsType{1:end-1}) populationsType{end}};
        end
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
        currFrame = getFrame(experiment, hs.mainWindowFramesSlider.Value, fID);
        updateImage;
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
    
    currFrame = getFrame(experiment, input, fID);
    %me = double(mean(double(currFrame(:))));
    %se = double(std(double(currFrame(:))));
    %currFrame(currFrame > me+5*se) = NaN;

    updateImage;
end

%--------------------------------------------------------------------------
function menuPreferencesRealSize(~, ~, ~)
    realSize = ~realSize;
    mainWindowResize(gcbo);
    updateImage;
    if(realSize)
        hs.menuPreferencesRealSize.Checked = 'on';
    else
        hs.menuPreferencesRealSize.Checked = 'off';
    end
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
    
    exportMovieOptionsCurrent.frameRate = str2double(frameRateText.String);
    exportMovieOptionsCurrent.frameRange = [hs.mainWindowFramesSlider.Value hs.mainWindowFramesSlider.Max];
    
    [success, exportMovieOptionsCurrent] = optionsWindow(exportMovieOptionsCurrent);
    if(~success)
        return;
    end
    
    [fileName, pathName] = uiputfile({'*.avi'}, 'Save current movie', experiment.folder); 
    if(fileName == 0)
        return;
    end
    % Little bit of consistency checks
    if(exportMovieOptionsCurrent.frameRange(1) < 1)
        exportMovieOptionsCurrent.frameRange(1) = 1;
    end
    if(exportMovieOptionsCurrent.frameRange(2) > hs.mainWindowFramesSlider.Max)
        exportMovieOptionsCurrent.frameRange(2) = hs.mainWindowFramesSlider.Max;
    end
    if(exportMovieOptionsCurrent.jump == 0)
        exportMovieOptionsCurrent.jump = 1;
    end
    % Create the movie
    if(exportMovieOptionsCurrent.compressMovie)
      newMovie = VideoWriter([pathName fileName], 'Motion JPEG AVI');
    else
      newMovie = VideoWriter([pathName fileName], 'Uncompressed AVI');
    end
    newMovie.FrameRate = exportMovieOptionsCurrent.frameRate;
    open(newMovie);
    ncbar('Saving current movie');
    % The iterator loop
    frameList = exportMovieOptionsCurrent.frameRange(1):exportMovieOptionsCurrent.jump:exportMovieOptionsCurrent.frameRange(2);
    numFrames = length(frameList);
    for it = 1:numFrames
        hs.mainWindowFramesSlider.Value = frameList(it);
        currentFrameText.String = sprintf('%.0f', hs.mainWindowFramesSlider.Value);
        %currFrame = getFrame(experiment, hs.mainWindowFramesSlider.Value, fID);
        frameChange();
        updateImage;
        frame = getframe(hs.mainWindowFramesAxes, hs.mainWindowFramesAxes.Position);
        writeVideo(newMovie, frame.cdata(:, :, :));
        ncbar.update(it/numFrames);
    end
    ncbar.close();
    close(newMovie);
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
                hFig = figure('Position', [newPos 800 200]);
                switch type
                    case 'raw'
                        plot(experiment.rawT, experiment.rawTraces(:, i));
                        hold on;
                        if(isfield(experiment, 'spikes'))
                            spikeTimes = experiment.spikes{i};
                        end
                    case 'smoothed'
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
    %axes(hs.mainWindowFramesAxes);
    %ap = randperm(numel(currFrame));
    %currFrame = currFrame(ap);
    %set(hs.mainWindowColorbarPanel,'UserData', currFrame)
    %axes(hs.mainWindowFramesAxes);
    %imagesc('CData', currFrame);
    
    %ncurrFrame = insertText(currFrame, [size(currFrame, 2)*0.8 size(currFrame, 1)*0.8],sprintf('%.3f s', hs.mainWindowFramesSlider.Value/experiment.fps) ,'AnchorPoint','RightBottom','FontSize', 20, 'TextColor', [1 1 1]*maxIntensity, 'BoxColor', [1 1 1], 'BoxOpacity', 0);
    set(imData, 'CData', currFrame);
    overlayText = ['t = ' sprintf('%.2f', hs.mainWindowFramesSlider.Value/experiment.fps) ' s'];

    ar = rgb2gray(insertText(zeros(size(currFrame)), [1, 1], overlayText, 'TextColor', 'white', 'BoxColor', 'black', 'FontSize', 32));

    set(overlayData, 'CData', double(maxIntensity)*ones(size(currFrame)));
    set(overlayData, 'AlphaData', ar);
    
    %annotation('textbox', [0.5 0.5 0.3 0.3], 'String', 'stringtext')
    %imagesc(currFrame);
    %axis equal tight;
    %set(hs.mainWindowFramesAxes, 'XTick', []);
    %set(hs.mainWindowFramesAxes, 'YTick', []);
    %set(hs.mainWindowFramesAxes, 'LooseInset', [0,0,0,0]);
    %box on;
    %[minIntensity maxIntensity];
    caxis([minIntensity maxIntensity]);
    

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
  burstsOverlay = imagesc(zeros([experiment.height experiment.width 3]), 'HitTest', 'off');
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
  populationsOverlay = imagesc(zeros([experiment.height experiment.width 3]), 'HitTest', 'off');
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
      spikesOverlay = imagesc(zeros([siz 3]), 'HitTest', 'off');
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

end
