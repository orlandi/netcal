function [hFigW] = viewRecordingPlugin2(hObj, eventHandle)
% VIEWRECORDINGPLUGIN2 Window for recording viewing
%
% USAGE:
%    viewRecording(experiment)
%
% INPUT arguments:
%    none
%
% OUTPUT arguments:
%    hFigW - handle to the GUI figure
%
% EXAMPLE:
%    hFigW = viewRecordingPlugin2()
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

%#ok<*AGROW>
%#ok<*ASGLU>
%#ok<*FXUP>
%#ok<*INUSD>

persistent defaultFolder;

%appFolder = fileparts(mfilename('fullpath'));
%appFolder = [appFolder filesep '..'];

%warning('off', 'MATLAB:dispatcher:nameConflict');
warning('off', 'MATLAB:Java:DuplicateClass');
% addpath(genpath(appFolder));
% rmpath(genpath([appFolder filesep '.git'])) % But exclude .git/
% rmpath(genpath([appFolder filesep 'old'])) % And old
% rmpath(genpath(fullfile(appFolder, 'external', 'OASIS_matlab', 'optimization', 'cvx'))); % And cvx
% subFolderList = dir(appFolder);
% for i = 1:length(subFolderList)
%   if(subFolderList(i).isdir && any(strfind(subFolderList(i).name, 'netcal')))
%     rmpath(genpath([appFolder filesep subFolderList(i).name])) % And any subfolders containing netcal
%   end
% end
% 
% %%% Java includes
% javaaddpath({fullfile(appFolder, 'internal', 'java'), ...
%             fullfile(appFolder, 'external', 'JavaTreeWrapper', '+uiextras', '+jTree', 'UIExtrasTree.jar')});
% import('uiextras.jTree.*');
% warning('on', 'MATLAB:dispatcher:nameConflict');


defaultFolder = pwd;

% Create dummy experiment - will be overriden by drag and drop
experiment = createDummyExperiment();
fID = -1;

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
frameBurstsColor = [];
burstsPixels = [];
populationsOverlay = [];
framePopulationsColor =[];
populationsPixels = [];
autoLevelsReset = true;

exportMovieOptionsCurrent = exportMovieOptions;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Create components
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
initVisible = 'off';

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

%%% The menu
hs.menu.file.root = uimenu(hs.mainWindow, 'Label', 'File');
uimenu(hs.menu.file.root, 'Label', 'Exit and discard changes', 'Callback', {@closeCallback, false});
uimenu(hs.menu.file.root, 'Label', 'Exit and save changes', 'Callback', {@closeCallback, false});
uimenu(hs.menu.file.root, 'Label', 'Exit (default)', 'Callback', @closeCallback);

hs.menu.preferences.root = uimenu(hs.mainWindow, 'Label', 'Preferences', 'Enable', 'on');
hs.menu.preferences.realSize = uimenu(hs.menu.preferences.root, 'Label', 'Real Size', 'Enable', 'on', 'Callback', @menuPreferencesRealSize);

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
panelj = findjobj(hs.mainWindowFramesPanel);
dndobj = dndcontrol(panelj);
% Set Drop callback functions
dndobj.DropFileFcn = @dropFile;

hs.mainWindowFramesAxes = axes('Parent', hs.mainWindowFramesPanel);

currFrame = zeros(experiment.height, experiment.width, 'uint16');

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

mainWindowResize();
try
  autoLevels();
catch ME
  logMsg(ME.message, 'e', hFigW);
end

% if(isempty(gui))
%   waitfor(hFigW);
% end

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
      logMsg('Screen not big enough for real size', hFigW);
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
      logMsg(ME.message, 'e', hFigW);
    end
  end
  
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
function updateImage()
  %ncurrFrame = insertText(currFrame, [size(currFrame, 2)*0.8 size(currFrame, 1)*0.8],sprintf('%.3f s', hs.mainWindowFramesSlider.Value/experiment.fps) ,'AnchorPoint','RightBottom','FontSize', 20, 'TextColor', [1 1 1]*maxIntensity, 'BoxColor', [1 1 1], 'BoxOpacity', 0);
  set(imData, 'CData', currFrame);
  overlayText = ['t = ' sprintf('%.2f', hs.mainWindowFramesSlider.Value/experiment.fps) ' s'];

  ar = rgb2gray(insertText(zeros(size(currFrame)), [1, 1], overlayText, 'TextColor', 'white', 'BoxColor', 'black', 'FontSize', 32));

  % Add the text
  if(strcmpi(experiment.name, 'no experiment'))
    tmpText = 'Waiting for movie file (drag and drop the file here)';
    br = rgb2gray(insertText(zeros(size(currFrame)), [experiment.width/2, experiment.height/2], tmpText, 'TextColor', 'white', 'BoxColor', 'black', 'FontSize', 16, 'AnchorPoint', 'center'));
    ar = ar + br;
  end
 
 set(overlayData, 'CData', double(maxIntensity)*ones(size(currFrame)));
 set(overlayData, 'AlphaData', ar);

 caxis([minIntensity maxIntensity]);
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
function dropFile(~, e)
  failedLoad = false;
  if(strcmp(e.DropType, 'file'))
    experimentFile = e.Data{1};
    experiment = loadExperiment(experimentFile, 'verbose', true, 'pbar', 0);
    if(isempty(experiment))
      logMsg(sprintf('Could not load %s', experimentFile), hFigW, 'e');
      experiment = createDummyExperiment();
      failedLoad = true;
    end
    experiment.virtual = true;
    if(~failedLoad)
      [newExperiment, success] = experimentHandleCheck(experiment);
    end
    if(~failedLoad && ~success)
      logMsg(sprintf('Could not load %s', experimentFile), hFigW, 'e');
      experiment = createDummyExperiment();
      failedLoad = true;
    end

    if(~failedLoad)
      try
        closeVideoStream(fID);
      end
      [fID, experiment] = openVideoStream(experiment);
    end
    % Update GUI stuff
    hs.mainWindowFramesSlider.Value = 1;
    hs.mainWindowFramesSlider.Max = experiment.numFrames;
    if(experiment.numFrames > 1)
      hs.mainWindowFramesSlider.Visible = 'on';
      hs.mainWindowFramesSlider.SliderStep = [1 100]/(experiment.numFrames-1);
    else
      hs.mainWindowFramesSlider.Visible = 'off';
    end
    frameRateText.String = num2str(round(experiment.fps));
    currentFrameText.String = sprintf('%.0f', hs.mainWindowFramesSlider.Value);
    
    % Clean and recreate axes
    cla(hs.mainWindowFramesAxes);
    if(~failedLoad)
      currFrame = getFrame(experiment, hs.mainWindowFramesSlider.Value, fID);
    else
      currFrame = zeros(experiment.height, experiment.width, 'uint16');
    end

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
    
    % Finally, update image
    autoLevelsReset = true;
    autoLevels();
    updateImage();
    hFigW.Name = ['Recording viewer: ' experiment.name];
  end
end

%--------------------------------------------------------------------------
function experiment = createDummyExperiment()
  experiment = struct;
  experiment.virtual = true;
  experiment.name = 'no experiment';
  experiment.folder = defaultFolder;
  experiment.width = 512;
  experiment.height = 512;
  experiment.bpp = 16;
  experiment.numFrames = 10;
  experiment.fps = 1;
  experiment.handle = '';
  experiment.pixelType = '*uint16';
  fID = -1;
end
end
