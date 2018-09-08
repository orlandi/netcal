%% View ROI
%#ok<*AGROW>
%#ok<*ASGLU>
%#ok<*FXUP>
function [hFigW, experiment] = viewROI(experiment)
% VIEWRECORDING
% More help about the program

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Initialization
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
oldExperiment = experiment;
gui = gcbf;
hFigW = [];
if(~isempty(gui))
  project = getappdata(gui, 'project');
end
textFontSize = 10;
%headerFontSize = 12;
minGridBorder = 1;
ROI = [];
ROIimg = [];
plotHandleList = [];
cursorHandle = [];
selectionMode = 'normal';
addCount = 0;
ROImode = 'all';
currentCmap = gray;

realSize = false;
avgImg = experiment.avgImg;
bpp = experiment.bpp;
autoLevelsReset = true;
[~, ROIselectionOptionsCurrent] = preloadOptions(experiment, ROIselectionOptions, gui, false, false);
experiment.ROIselectionOptionsCurrent = ROIselectionOptionsCurrent;
  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Create components
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
hs.mainWindow = figure('Visible','off',...
                       'Resize','on',...
                       'Toolbar', 'figure',...
                       'Tag','viewRecording', ...
                       'NumberTitle', 'off',...
                       'MenuBar', 'none',...
                       'DockControls','off',...
                       'Name', ['ROI viewer: ' experiment.name],...
                       'SizeChangedFcn', @mainWindowResize,...
                       'CloseRequestFcn', @closeCallback,...
                       'WindowButtonMotionFcn', @ROIWindowButtonMotionFcn);
hFigW = hs.mainWindow;
hFigW.Position = setFigurePosition(gui, 'width', 900, 'height', 700);
if(~isempty(gui))
  setappdata(hFigW, 'logHandle', getappdata(gcbf, 'logHandle'));
  setappdata(hFigW, 'project', project);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Create components
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
hs.menu.file.root = uimenu(hs.mainWindow, 'Label', 'File');
uimenu(hs.menu.file.root, 'Label', 'Exit and discard changes', 'Callback', {@closeCallback, false});
uimenu(hs.menu.file.root, 'Label', 'Exit and save changes', 'Callback', {@closeCallback, false});
uimenu(hs.menu.file.root, 'Label', 'Exit (default)', 'Callback', @closeCallback);

hs.menuAdd  = uimenu(hs.mainWindow, 'Label', 'Add ROI');
hs.menuAutomatic = uimenu(hs.menuAdd, 'Label', 'Automatic', 'Callback', @autoROI);

hs.menuActive = uimenu(hs.menuAdd, 'Label', 'Active contour', 'Callback', @activeROIButton, 'Accelerator', 'A');
hs.menuIndividual = uimenu(hs.menuAdd, 'Label', 'Individual');
hs.menuIndividualSquare = uimenu(hs.menuIndividual, 'Label', 'Square', 'Callback', @addSquare, 'Accelerator', 'S');
hs.menuIndividualCircle = uimenu(hs.menuIndividual, 'Label', 'Circle', 'Callback', @addCircle, 'Accelerator', 'C');
hs.menuGrid = uimenu(hs.menuAdd, 'Label', 'Grid', 'Callback', @menuAddGrid);
% hs.menuGridCircle2 = uimenu(hs.menuGrid, 'Label', 'Circle (center + radius)', 'Callback', @menuCircle2);
% hs.menuGridCircle3 = uimenu(hs.menuGrid, 'Label', 'Circle (3 perimeter points)', 'Callback', @menuCircle3);
% hs.menuRectangleFull = uimenu(hs.menuGrid, 'Label', 'Rectangle (whole image)', 'Callback', @menuRectangleFull);
% hs.menuRectangleRegion = uimenu(hs.menuGrid, 'Label', 'Rectangle (subregion)', 'Callback', @menuRectangleRegion);
hs.menuImportROI = uimenu(hs.menuAdd, 'Label', 'Import from another experiment', 'Callback', @menuImportROI);

hs.menuModify  = uimenu(hs.mainWindow, 'Label', 'Modify ROI');
hs.menuMoveROI = uimenu(hs.menuModify, 'Label', 'Move all ROIs', 'Callback', @menuMoveROI);
hs.menuResizeROI = uimenu(hs.menuModify, 'Label', 'Resize all ROIs', 'Callback', @menuResizeROI);
hs.menuResizeROI = uimenu(hs.menuModify, 'Label', 'Fix ROI overlaps', 'Callback', @fixROIoverlapsButton);
hs.menuResizeROI = uimenu(hs.menuModify, 'Label', 'Fix ROI shapes', 'Callback', @fixROIshapeButton);
hs.menuModifyReassign = uimenu(hs.menuModify, 'Label', 'Reassign All IDs', 'Enable', 'on', 'Callback', @menuModifyReassign);

hs.menuDelete  = uimenu(hs.mainWindow, 'Label', 'Delete ROI');
hs.menuDeleteClear = uimenu(hs.menuDelete, 'Label', 'All', 'Callback', @menuClear);
hs.menuDeleteIndividual = uimenu(hs.menuDelete, 'Label', 'Individual', 'Callback', @menuDelete, 'Accelerator', 'D');
hs.menuDeleteArea = uimenu(hs.menuDelete, 'Label', 'Area', 'Callback', @menuDeleteArea);

hs.menuPreferences = uimenu(hs.mainWindow, 'Label', 'Preferences');
hs.menuPreferencesList = uimenu(hs.menuPreferences, 'Label', 'General', 'Callback', @preferences);
hs.menuPreferencesRealSize = uimenu(hs.menuPreferences, 'Label', 'Real Size', 'Enable', 'on', 'Callback', @menuPreferencesRealSize);

hs.menuHotkeys = uimenu(hs.mainWindow, 'Label', 'Hotkeys');
hs.menuHotkeysPan = uimenu(hs.menuHotkeys, 'Label', 'Pan', 'Accelerator', 'P', 'Callback', @hotkeyPan);

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

% Left buttons

hs.mainWindowLeftButtons = uix.VBox( 'Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowLeftButtons);
uicontrol('Parent', hs.mainWindowLeftButtons, 'String', 'Load ROI', 'FontSize', textFontSize, 'callback', {@loadROIButton, 'reset'});
uicontrol('Parent', hs.mainWindowLeftButtons, 'String', 'Load ROI (legacy)', 'FontSize', textFontSize, 'callback', @loadROILegacyButton);
uicontrol('Parent', hs.mainWindowLeftButtons, 'String', 'Append ROI', 'FontSize', textFontSize, 'callback', {@loadROIButton, 'append'});
uicontrol('Parent', hs.mainWindowLeftButtons, 'String', 'Save ROI', 'FontSize', textFontSize, 'callback', @saveROIButton);
uicontrol('Parent', hs.mainWindowLeftButtons, 'String', 'Save ROI centers', 'FontSize', textFontSize, 'callback', @saveROIcentersButton);
%uicontrol('Parent', hs.mainWindowLeftButtons, 'String', 'Load Image', 'FontSize', textFontSize, 'callback', @loadImageButton);

b = uix.VButtonBox( 'Parent', hs.mainWindowLeftButtons);
uicontrol('Parent', b, 'Style','text',...
          'String','Image:', 'FontSize', textFontSize, 'HorizontalAlignment', 'left');
imageStr = {};
if(isfield(experiment, 'avgImg'))
  imageStr{end+1} = 'average';
end
if(isfield(experiment, 'percentileImg'))
  imageStr{end+1} = 'percentile';
end
if(isfield(experiment, 'avgImgDenoised'))
  imageStr{end+1} = 'denoised average';
end
if(isfield(experiment, 'avgPSD'))
  for it = 1:length(experiment.avgPSD)
    imageStr{end+1} = sprintf('average PSD %d', it);
  end
end
imageStr{end+1} = 'custom';

uicontrol('Parent', b, 'Style', 'popup', 'Units', 'pixel', 'String', imageStr, 'Callback', @setCurrentImage, 'FontSize', textFontSize);
set(b, 'ButtonSize', [200 15], 'Spacing', 20, 'Padding', 0);

%uix.Empty('Parent', hs.mainWindowLeftButtons);

uicontrol('Parent', hs.mainWindowLeftButtons, 'String', 'Show ROI', 'FontSize', textFontSize, 'Callback', {@showROImode, 'all'});
uicontrol('Parent', hs.mainWindowLeftButtons, 'String', 'Hide ROI', 'FontSize', textFontSize, 'Callback', {@showROImode, 'none'});
hs.numROItext = uicontrol('Parent', hs.mainWindowLeftButtons, 'Style','text', 'String', 'no ROI present', 'FontSize', textFontSize, 'HorizontalAlignment', 'left');

uix.Empty('Parent', hs.mainWindowLeftButtons);

set(hs.mainWindowLeftButtons, 'Heights', [-1 25 25 25 25 25 100 25 25 25 -1], 'Padding', 5);

% Below left buttons
uix.Empty('Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowGrid);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% COLUMN START
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
uix.Empty('Parent', hs.mainWindowGrid);
% Frames panel
hs.mainWindowFramesPanel = uix.Panel('Parent', hs.mainWindowGrid, 'Padding', 5, 'BorderType', 'none');
hs.mainWindowFramesAxes = axes('Parent', hs.mainWindowFramesPanel);
currFrame = avgImg;

%currFrame(currFrame > me+10*se) = NaN;

imData = imagesc(currFrame);
axis equal tight;
maxIntensity = max(currFrame(:));
minIntensity = min(currFrame(:));
set(hs.mainWindowFramesAxes, 'XTick', []);
set(hs.mainWindowFramesAxes, 'YTick', []);
set(hs.mainWindowFramesAxes, 'LooseInset', [0,0,0,0]);
box on;
hold on;
ROIimgData = imagesc(ones(size(currFrame)));
valid = zeros(size(currFrame));
set(ROIimgData, 'AlphaData', valid);

hold off;

% Below image panel
uix.Empty('Parent', hs.mainWindowGrid);

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
          'String', num2str(maxIntensity), 'FontSize', textFontSize, 'HorizontalAlignment', 'left', 'callback', {@intensityChange, 'max'});
uicontrol('Parent', b, 'Style', 'text', 'String', 'Maximum', 'FontSize', textFontSize, 'HorizontalAlignment', 'left');
set(b, 'Widths', [30 -1], 'Spacing', 5, 'Padding', 0);

uix.Empty('Parent', hs.mainWindowRightButtons);

b = uix.VButtonBox( 'Parent', hs.mainWindowRightButtons);
uicontrol('Parent', b, 'Style','text',...
          'String','Colormap:', 'FontSize', textFontSize, 'HorizontalAlignment', 'left');

htmlStrings = getHtmlColormapNames({'gray', 'parula', 'morgenstemning', 'jet', 'isolum'}, 115, 12);
uicontrol('Parent', b, 'Style','popup', 'Units','pixel', 'String', htmlStrings, 'Callback', @setmap, 'FontSize', textFontSize);
uicontrol('Parent', b, 'Units','pixel', 'String', 'Invert Colormap', 'Callback', @invertMap, 'FontSize', textFontSize);

set(b, 'ButtonSize', [200 15], 'Spacing', 20, 'Padding', 0);
uicontrol('Parent', hs.mainWindowRightButtons, 'String', 'Auto levels', 'FontSize', textFontSize, 'Callback', @autoLevels);
uicontrol('Parent', hs.mainWindowRightButtons, 'String', 'Remove background', 'FontSize', textFontSize, 'Callback', @removeBackground);
uicontrol('Parent', hs.mainWindowRightButtons, 'String', 'Reset image', 'FontSize', textFontSize, 'Callback', @resetImage);

uix.Empty('Parent', hs.mainWindowRightButtons);

b = uix.HBox( 'Parent', hs.mainWindowRightButtons);
minIntensityText = uicontrol('Parent', b, 'Style','edit',...
          'String', num2str(minIntensity), 'FontSize', textFontSize, 'HorizontalAlignment', 'left', 'callback', {@intensityChange, 'min'});
uicontrol('Parent', b, 'Style','text', 'String', 'Minimum', 'FontSize', textFontSize, 'HorizontalAlignment', 'left');
set(b, 'Widths', [30 -1], 'Spacing', 5, 'Padding', 0);

set(hs.mainWindowRightButtons, 'Heights', [20 -1 100 25 25 25 -1 20], 'Padding', 5);
%set(hs.mainWindowRightButtons, 'ButtonSize', [100 35], 'Spacing', 55);


% Below right buttons
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
%%% Fianl init
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

colormap(currentCmap);

set(hs.mainWindowGrid, 'Widths', [minGridBorder 200 -1 25 200 minGridBorder], 'Heights', [minGridBorder -1 5 minGridBorder]);
%set(hs.mainWindowGrid, 'Widths', [size(currFrame,2) 25 -1], 'Heights', [size(currFrame,1) -1]);
cleanMenu();
preloadROI();

mainWindowResize(gcbo);
try
  autoLevels();
catch ME
  logMsg(ME.message, 'e');
end

hs.mainWindow.Visible = 'on';

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
if(isempty(gui))
  waitfor(hFigW);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Callbacks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function mainWindowResize(~, ~)
    set(hs.mainWindowGrid, 'Widths', [minGridBorder 200 -1 25 200 minGridBorder], 'Heights', [minGridBorder -1 5 minGridBorder]);
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

      minWidth = curPos(3) + 25 + 400 + minGridBorder*2;
      minHeight = curPos(4) + 5 + minGridBorder*2+100;

      newPos = setFigurePosition([], 'width', minWidth, 'height', minHeight);
      if(newPos(3) ~= minWidth || newPos(4) ~= minHeight)
        logMsg('Screen not big enough for real size');
        realSize = false;
      end
      hs.mainWindow.Position = newPos;
    end
    curRatio = curPos(3)/curPos(4);
    updateImage();
    if(curRatio > realRatio)
      set(hs.mainWindowGrid, 'Widths', [-1 200 max(400, curPos(4)*realRatio) 25 200 -1], 'Heights', [-1 max(400, curPos(4)) 5 -1]);
    else
      set(hs.mainWindowGrid, 'Widths', [-1 200 max(400, curPos(3)) 25 200 -1], 'Heights', [-1 max(400,curPos(3)/realRatio) 5 -1]);
    end
    %[pos(3) pos(4) realRatio curRatio]
end

%--------------------------------------------------------------------------
function setmap(hObject, ~)
    val = hObject.Value;
    maps = hObject.String;

    newmap = maps{val};
    mapNamePosition = strfind(newmap, 'png">');
    currentCmap = eval(newmap(mapNamePosition+5:end));
    colormap(currentCmap);
end
%--------------------------------------------------------------------------
function invertMap(~, ~)
  currentCmap = currentCmap(end:-1:1, :);
  colormap(currentCmap);
end

%--------------------------------------------------------------------------
function setCurrentImage(hObject, ~)
  
  currentSelection = hObject.String{hObject.Value};
  switch currentSelection
    case 'average'
      avgImg = experiment.avgImg;
      currFrame = avgImg;
      bpp = experiment.bpp;
      autoLevels([], [], true);
    case 'percentile'
      avgImg = experiment.percentileImg;
      currFrame = avgImg;
      bpp = experiment.bpp;
      autoLevels([], [], true);
    case 'denoised average'
      avgImg = experiment.avgImgDenoised;
      currFrame = avgImg;
      bpp = experiment.bpp;
      autoLevels([], [], true);
    case 'custom'
      loadImageButton();
      bpp = experiment.bpp;
      autoLevels([], [], true);
  end
  k = strfind(currentSelection, 'average PSD');
  if(~isempty(k))
    k = k + length('average PSD ');
    selImage = str2num(currentSelection(k:end));
    avgImg = experiment.avgPSD{selImage};
    % Normalize it and turn it to 16 bits
    avgImg = uint16((avgImg'-min(avgImg(:)))/(max(avgImg(:))-min(avgImg(:)))*(2^16-1));
    bpp = 16;
    currFrame = avgImg;
    autoLevels([], [], true);
  end
  
  updateImage();
  %displayROI();
end

% ImageJ old auto version
%--------------------------------------------------------------------------
function autoLevels(~, ~, reset)
  if(nargin >= 3)
    autoLevelsReset = reset;
  end
  [minIntensity, maxIntensity] = autoLevelsFIJI(currFrame, bpp, autoLevelsReset);
  maxIntensityText.String = sprintf('%.2f', maxIntensity);
  minIntensityText.String = sprintf('%.2f', minIntensity);
  updateImage();
  autoLevelsReset = false;
end

%--------------------------------------------------------------------------
function resetImage(~, ~)
  currFrame = avgImg;
  bpp = experiment.bpp;
  maxIntensity = max(currFrame(:));
  minIntensity = min(currFrame(:));
  maxIntensityText.String = sprintf('%.2f', maxIntensity);
  minIntensityText.String = sprintf('%.2f', minIntensity);
  [minIntensity, maxIntensity] = autoLevelsFIJI(currFrame, bpp, true);
  updateImage();
end

%--------------------------------------------------------------------------
function removeBackground(~, ~)
  [success, backgroundRemovalOptionsCurrent] = preloadOptions(experiment, backgroundRemovalOptions, gui, true, false);
  if(~success)
    return;
  end
  experiment.backgroundRemovalOptionsCurrent = backgroundRemovalOptionsCurrent;
  if(experiment.bpp == 8 || experiment.bpp == 16)
    bpp = experiment.bpp;
  else
    bpp = 8;
  end
  currFrame = round((2^bpp-1)*(normalizeImage(currFrame, 'lowerSaturation', experiment.backgroundRemovalOptionsCurrent.saturationThresholds(1), 'upperSaturation', experiment.backgroundRemovalOptionsCurrent.saturationThresholds(2))));
  currFrame = currFrame - imgaussfilt(currFrame, experiment.backgroundRemovalOptionsCurrent.characteristicCelSize/2);
  currFrame(currFrame <0) = 0;
  [minIntensity, maxIntensity] = autoLevelsFIJI(currFrame, bpp, true);
  updateImage();
end

%--------------------------------------------------------------------------
function menuModifyReassign(~, ~, ~)
  choice = questdlg('This will reassign all ROI IDs (so that they are consecutive numbers). Are you sure?', ...
                            'Changing ROI IDs', ...
                            'Yes', 'No', 'Cancel', 'Cancel');
  switch choice
    case 'Yes'
      for i = 1:length(ROI)
        ROI{i}.ID = i;
      end
      logMsg('ROI IDs reassigned');
    otherwise
      return;
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
function autoROI(~, ~)
  [success, ROIautomaticOptionsCurrent] = preloadOptions(experiment, ROIautomaticOptions, gui, true, false);
  if(~success)
    return;
  end
  ROI = autoDetectROI(currFrame, ROIautomaticOptionsCurrent);
  experiment.ROIautomaticOptionsCurrent = ROIautomaticOptionsCurrent;
  if(~isempty(gui))
    project = getappdata(gui, 'project');
    if(~isempty(project))
      project.ROIautomaticOptionsCurrent = ROIautomaticOptionsCurrent;
    end
    setappdata(gui, 'project', project);
  end
  
  displayROI();
  updateImage();
  logMsg([num2str(length(ROI)) ' ROI generated']);
end

%--------------------------------------------------------------------------
function menuAddGrid(~, ~)
  [success, addROIgridOptionsCurrent, experiment] = preloadOptions(experiment, addROIgridOptions, gui, true, false);
  if(~success)
    return;
  end
  switch experiment.addROIgridOptionsCurrent.gridType
    case '2 point circle'
      menuCircle2(experiment.addROIgridOptionsCurrent.rows, experiment.addROIgridOptionsCurrent.cols, experiment.addROIgridOptionsCurrent.resetROI, experiment.addROIgridOptionsCurrent.deleteSmallROI);
    case '3 point circle'
      menuCircle3(experiment.addROIgridOptionsCurrent.rows, experiment.addROIgridOptionsCurrent.cols, experiment.addROIgridOptionsCurrent.resetROI, experiment.addROIgridOptionsCurrent.deleteSmallROI);
    case 'rectangle (subregion)'
      menuRectangleRegion(experiment.addROIgridOptionsCurrent.rows, experiment.addROIgridOptionsCurrent.cols, experiment.addROIgridOptionsCurrent.resetROI);
    case 'rectangle (whole image)'
      menuRectangleFull(experiment.addROIgridOptionsCurrent.rows, experiment.addROIgridOptionsCurrent.cols, experiment.addROIgridOptionsCurrent.resetROI);
  end
    
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
    deleted = false;
    deletedCount = 0;
    for j = 1:size(coordList,1)
        mask = zeros(size(avgImg));
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
end

%--------------------------------------------------------------------------
function showROImode(~, ~, mode)
  ROImode = mode;
  switch ROImode
    case 'none'
      displayROI('none');
    otherwise
      displayROI();
  end
  updateImage();
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
    for i = 1:length(x_range)
        for j = 1:length(y_range)
            it = it + 1;
            plist(it, :) = [x_range(i) y_range(j)];
        end
    end
    pixelList = sub2ind(size(avgImg), plist(:,2), plist(:,1));
    invalid = [];
    for i = 1:length(ROI)
       if(any(ismember(ROI{i}.pixels, pixelList)))
           invalid = [invalid; i];
       end
    end
    ROI(invalid) = [];
    delete(h);
    if(~isempty(invalid))
        displayROI();
        logMsg([num2str(length(invalid)) ' ROI deleted']);
        logMsg([num2str(length(ROI)) ' ROI present']);
    end
end

%--------------------------------------------------------------------------
function menuCircle2(rows, cols, reset, deleteSmallROI)
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
    
    rows = rows + 1;
    cols = cols + 1;
    [x,y] = meshgrid(round(linspace(x_min, x_max, cols)), round(linspace(y_min, y_max, rows)));
    ROIsize = (x(1,2)-x(1,1)+1)*(y(2,1)-y(1,1)+1);
    newROI = cell((rows-1)*(cols-1), 1);
    idx = 0;
    invalid = [];
    for i = 1:(size(x,1)-1)
        for j = 1:(size(x,2)-1)
            idx = idx + 1;
            x_range = x(i,j):(x(i,j+1)-1);
            y_range = y(i,j):(y(i+1,j)-1);
            [tx, ty] = meshgrid(x_range, y_range);
            pixelList = [tx(:) ty(:)];
            valid = find((pixelList(:,1) - center(1)).^2 + (pixelList(:,2) - center(2)).^2 <= radius.^2 & pixelList(:,1) >= 1 & pixelList(:,1) <= size(avgImg, 2) & pixelList(:,2) >= 1 & pixelList(:,2) <= size(avgImg, 1));
            if(~isempty(valid) && (length(valid) >= ROIsize/5 || ~deleteSmallROI))
                pixelList = sub2ind(size(avgImg), pixelList(valid,2), pixelList(valid,1));
                newROI{idx}.ID = idx;
                newROI{idx}.pixels = pixelList';
                [yb, xb] = ind2sub(size(avgImg), newROI{idx}.pixels(:));
                newROI{idx}.center = [mean(xb), mean(yb)];
                newROI{idx}.maxDistance = max(sqrt((newROI{idx}.center(1)-xb).^2+(newROI{idx}.center(2)-yb).^2));
            else
                invalid = [invalid; idx];
            end
        end
    end
    newROI(invalid) = [];
    if(reset)
      ROI = newROI;
    else
      curCount = length(ROI);
      for it = 1:length(newROI)
        ROI{end+1} = newROI{it};
        ROI{end}.ID = curCount+it;
      end
    end
    displayROI();
    logMsg([num2str(length(newROI)) ' ROI generated']);
end

%--------------------------------------------------------------------------
function menuCircle3(rows, cols, reset, deleteSmallROI)
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
    
    rows = rows + 1;
    cols = cols + 1;
    [x,y] = meshgrid(round(linspace(x_min, x_max, cols)), round(linspace(y_min, y_max, rows)));
    ROIsize = (x(1,2)-x(1,1)+1)*(y(2,1)-y(1,1)+1);
    newROI = cell((rows-1)*(cols-1), 1);
    idx = 0;
    invalid = [];
    for i = 1:(size(x,1)-1)
        for j = 1:(size(x,2)-1)
            idx = idx + 1;
            x_range = x(i,j):(x(i,j+1)-1);
            y_range = y(i,j):(y(i+1,j)-1);
            [tx, ty] = meshgrid(x_range, y_range);
            pixelList = [tx(:) ty(:)];
            valid = find((pixelList(:,1) - center(1)).^2 + (pixelList(:,2) - center(2)).^2 <= radius.^2 & pixelList(:,1) >= 1 & pixelList(:,1) <= size(avgImg, 2) & pixelList(:,2) >= 1 & pixelList(:,2) <= size(avgImg, 1));
            if(~isempty(valid) && (length(valid) >= ROIsize/5 || ~deleteSmallROI))
                pixelList = sub2ind(size(avgImg), pixelList(valid,2), pixelList(valid,1));
                newROI{idx}.ID = idx;
                newROI{idx}.pixels = pixelList';
                [yb, xb] = ind2sub(size(avgImg), newROI{idx}.pixels(:));
                newROI{idx}.center = [mean(xb), mean(yb)];
                newROI{idx}.maxDistance = max(sqrt((newROI{idx}.center(1)-xb).^2+(newROI{idx}.center(2)-yb).^2));
            else
                invalid = [invalid; idx];
            end
        end
    end
    newROI(invalid) = [];
    if(reset)
      ROI = newROI;
    else
      curCount = length(ROI);
      for it = 1:length(newROI)
        ROI{end+1} = newROI{it};
        ROI{end}.ID = curCount+it;
      end
    end
    displayROI();
    logMsg([num2str(length(newROI)) ' ROI generated']);
end

%--------------------------------------------------------------------------
function menuRectangleFull(rows, cols, reset)
    x_min = 1;
    x_max = size(avgImg, 2);
    y_min = 1;
    y_max = size(avgImg, 1);
    
    
    rows = rows + 1;
    cols = cols + 1;
    [x,y] = meshgrid(round(linspace(x_min, x_max, cols)), round(linspace(y_min, y_max, rows)));
    ROIsize = (x(1,2)-x(1,1)+1)*(y(2,1)-y(1,1)+1);
    newROI = cell((rows-1)*(cols-1), 1);
    idx = 0;
    invalid = [];
    for i = 1:(size(x,1)-1)
        for j = 1:(size(x,2)-1)
            idx = idx + 1;
            x_range = x(i,j):(x(i,j+1)-1);
            y_range = y(i,j):(y(i+1,j)-1);
            [tx, ty] = meshgrid(x_range, y_range);
            pixelList = [tx(:) ty(:)];
            valid = find(pixelList(:,1) >= 1 & pixelList(:,1) <= size(avgImg, 2) & pixelList(:,2) >= 1 & pixelList(:,2) <= size(avgImg, 1));
            if(~isempty(valid) && length(valid) >= ROIsize/5)
                pixelList = sub2ind(size(avgImg), pixelList(valid,2), pixelList(valid,1));
                newROI{idx}.ID = idx;
                newROI{idx}.pixels = pixelList';
                [yb, xb] = ind2sub(size(avgImg), newROI{idx}.pixels(:));
                newROI{idx}.center = [mean(xb), mean(yb)];
                newROI{idx}.maxDistance = max(sqrt((newROI{idx}.center(1)-xb).^2+(newROI{idx}.center(2)-yb).^2));
            else
                invalid = [invalid; idx];
            end
        end
    end
    newROI(invalid) = [];
    if(reset)
      ROI = newROI;
    else
      curCount = length(ROI);
      for it = 1:length(newROI)
        ROI{end+1} = newROI{it};
        ROI{end}.ID = curCount+it;
      end
    end
    displayROI();
    logMsg([num2str(length(newROI)) ' ROI generated']);
end

%--------------------------------------------------------------------------
function menuRectangleRegion(rows, cols, reset)
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
    
    rows = rows + 1;
    cols = cols + 1;
    [x,y] = meshgrid(round(linspace(x_min, x_max, cols)), round(linspace(y_min, y_max, rows)));
    ROIsize = (x(1,2)-x(1,1)+1)*(y(2,1)-y(1,1)+1);
    newROI = cell((rows-1)*(cols-1), 1);
    idx = 0;
    invalid = [];
    for i = 1:(size(x,1)-1)
        for j = 1:(size(x,2)-1)
            idx = idx + 1;
            x_range = x(i,j):(x(i,j+1)-1);
            y_range = y(i,j):(y(i+1,j)-1);
            [tx, ty] = meshgrid(x_range, y_range);
            pixelList = [tx(:) ty(:)];
            valid = find(pixelList(:,1) >= 1 & pixelList(:,1) <= size(avgImg, 2) & pixelList(:,2) >= 1 & pixelList(:,2) <= size(avgImg, 1));
            if(~isempty(valid) && length(valid) >= ROIsize/5)
                pixelList = sub2ind(size(avgImg), pixelList(valid,2), pixelList(valid,1));
                newROI{idx}.ID = idx;
                newROI{idx}.pixels = pixelList';
                [yb, xb] = ind2sub(size(avgImg), newROI{idx}.pixels(:));
                newROI{idx}.center = [mean(xb), mean(yb)];
                newROI{idx}.maxDistance = max(sqrt((newROI{idx}.center(1)-xb).^2+(newROI{idx}.center(2)-yb).^2));
            else
                invalid = [invalid; idx];
            end
        end
    end
    newROI(invalid) = [];
    if(reset)
      ROI = newROI;
    else
      curCount = length(ROI);
      for it = 1:length(newROI)
        ROI{end+1} = newROI{it};
        ROI{end}.ID = curCount+it;
      end
    end
    displayROI();
    logMsg([num2str(length(newROI)) ' ROI generated']);
end

%--------------------------------------------------------------------------
function menuMoveROI(~, ~)
  answer = inputdlg({'Pixel displacement in X (columns, negative to the left)','Pixel displacement in Y (rows, negative for up)'}, 'Move ROI', [1 60],{'0','0'});
  if(isempty(answer))
      return;
  end
  %[answer{1} answer{2}]
  markedForDeletion = [];
  for idx = 1:length(ROI)
      [row, col] = ind2sub(size(avgImg), ROI{idx}.pixels);
      row = row+str2double(answer{2});
      col = col+str2double(answer{1});
%         row(row < 1) = 1;
%         col(col < 1) = 1;
%         row(row > size(avgImg, 1)) = size(avgImg, 1);
%         col(col > size(avgImg, 2)) = size(avgImg, 2);
%         pixelList = sub2ind(size(avgImg), row, col);
      row(row < 1) = 0;
      col(col < 1) = 0;
      row(row > size(avgImg, 1)) = 0;
      col(col > size(avgImg, 2)) = 0;
      invalid = find(row == 0 | col == 0);
      row(invalid) = [];
      col(invalid) = [];
      if(~isempty(row))
        pixelList = sub2ind(size(avgImg), row, col);
        ROI{idx}.pixels = pixelList';
        ROI{idx}.center = [mean(col), mean(row)];
        ROI{idx}.maxDistance = max(sqrt((ROI{idx}.center(1)-col).^2+(ROI{idx}.center(2)-row).^2));
      else
        markedForDeletion = [markedForDeletion; idx];
      end
  end
  ROI(markedForDeletion) = [];
  displayROI();
end

%--------------------------------------------------------------------------
function menuResizeROI(~, ~)
  [success, ROIresizeOptionsCurrent] = preloadOptions(experiment, ROIresizeOptions, gui, true, false);
  if(~success)
    return;
  end
  experiment.ROIresizeOptionsCurrent = ROIresizeOptionsCurrent;

  ncbar.automatic('Resizing ROI...');
  
  % Grid only used for circles
  [gridX, gridY] = meshgrid(1:size(avgImg,2), 1:size(avgImg, 1));
  for idx = 1:length(ROI)
    %pos = round(ROI{idx}.center);
    % For some reason in some versions the ROI centers coordinates are swapped, get it from the pixels
    % Now it works as expected
    [y, x] = ind2sub(size(avgImg), ROI{idx}.pixels);

    % Modify the ROI
    mask = zeros(size(avgImg));
    switch experiment.ROIresizeOptionsCurrent.shape
      case 'square'
        pos = round([mean(x), mean(y)]);
        x = pos(1);
        y = pos(2);
        r = floor(experiment.ROIresizeOptionsCurrent.size/2);
        minX = max(x-r, 1);
        maxX = min(x+r, size(avgImg, 2));
        minY = max(y-r, 1);
        maxY = min(y+r, size(avgImg, 1));
        mask(minY:maxY, minX:maxX) = 1;
      case 'circle'
        pos = [mean(x), mean(y)];
        x = pos(1);
        y = pos(2);
        r = experiment.ROIresizeOptionsCurrent.size/2;
        mask((gridX-x).^2+(gridY-y).^2 < (r+0.5).^2) = 1;
    end
    B = bwconncomp(mask);
    ROI{idx}.pixels = B.PixelIdxList{1}';
    % Let's change the center
    ROI{idx}.center = [x, y];
    [y, x] = ind2sub(size(avgImg), ROI{end}.pixels);
    ROI{idx}.maxDistance = max(sqrt((ROI{idx}.center(1)-x).^2+(ROI{idx}.center(2)-y).^2));
  end
  ncbar.close();
  displayROI();
end

%--------------------------------------------------------------------------
function menuImportROI(~, ~)
  [selection, ok] = listdlg('PromptString', 'Select experiment to import ROIs from', 'ListString', namesWithLabels(), 'SelectionMode', 'single');
  if(~ok)
    return;
  end
  experimentFile = [project.folderFiles project.experiments{selection} '.exp'];
  newExperiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
  
  if(~isfield(newExperiment, 'ROI') || isempty(newExperiment.ROI))
    logMsg('No ROI found', 'w');
    return;
  end
  ROI = newExperiment.ROI;

  displayROI();
  logMsg([num2str(length(ROI)) ' ROI imported']);
end

%--------------------------------------------------------------------------
function activeROIButton(~, ~)
    changeSelectionMode('normal');
%     for i = 1:length(plotHandleList)
%         delete(plotHandleList(i));
%     end
    delete(plotHandleList);
    hold on;
    plotHandleList = [];
    I = uint16(avgImg);
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
end

%--------------------------------------------------------------------------
function menuClear(~, ~, ~)
    hold off;
    cla(hs.mainWindowFramesAxes);
    imData = imagesc(currFrame);
    axis equal tight;
    maxIntensity = max(currFrame(:));
    minIntensity = min(currFrame(:));
    set(hs.mainWindowFramesAxes, 'XTick', []);
    set(hs.mainWindowFramesAxes, 'YTick', []);
    set(hs.mainWindowFramesAxes, 'LooseInset', [0,0,0,0]);
    box on;
    hold on;
    ROIimgData = imagesc(ones(size(currFrame)));
    valid = zeros(size(currFrame));
    set(ROIimgData, 'AlphaData', valid);

    ROI = [];
    displayROI();
    logMsg('ROI cleared');
end

%--------------------------------------------------------------------------
function loadROILegacyButton(~, ~)
    [fpa, ~, ~] = fileparts(experiment.handle);
    [fileName, pathName] = uigetfile('*', 'Select ROI file', fpa);
    fileName = [pathName fileName];
    if(~fileName | ~exist(fileName, 'file')) %#ok<BDSCI,OR2,BDLGI>
        logMsg('Invalid ROI file', 'e');
        return;
    end
    try
      ROI = loadROI(experiment, fileName);
    catch
      logMsg('Looks like the ROI file might be in the new format. Updating...','w');
      ROI = loadROI(experiment, fileName, 'overwriteMode', 'rawNew');
    end
    
    displayROI();
end

%--------------------------------------------------------------------------
function loadROIButton(~, ~, mode)
    [fpa, ~, ~] = fileparts(experiment.handle);
    [fileName, pathName] = uigetfile('*', 'Select ROI file', fpa);
    fileName = [pathName fileName];
    if(~fileName | ~exist(fileName, 'file')) %#ok<BDSCI,OR2,BDLGI>
        logMsg('Invalid ROI file', 'e');
        return;
    end
    switch mode
      case 'reset'
        ROI = loadROI(experiment, fileName, 'overwriteMode', 'rawNew');
      case 'add'
        newROI = loadROI(experiment, fileName, 'overwriteMode', 'rawNew');
        curCount = length(ROI);
        for it = 1:length(newROI)
          ROI{end+1} = newROI{it};
          ROI{end}.ID = curCount+it;
        end
    end

    displayROI();
end


%--------------------------------------------------------------------------
function loadImageButton()
    [fpa, ~, ~] = fileparts(experiment.handle);
    [fileName, pathName] = uigetfile('*', 'Select Image file', fpa);
    fileName = [pathName fileName];
    if(~fileName | ~exist(fileName, 'file')) %#ok<BDSCI,OR2,BDLGI>
        logMsg('Invalid image file', 'e');
        return;
    end
    % Do something
    imgInfo = imfinfo(fileName);
    newImg = imread(fileName);
    bpp = imgInfo.BitDepth;
    if(size(newImg,1) ~= size(avgImg, 1) || size(newImg,2) ~= size(avgImg, 2))
        logMsg('Wrong image sie', 'e');
        return;
    end
    % For now it works
    %avgImg = uint8(newImg);
    avgImg = newImg;
    avgImg = avgImg(:, :, 1);
    currFrame = avgImg;
    [minIntensity, maxIntensity] = autoLevelsFIJI(currFrame, bpp, true);
end

%--------------------------------------------------------------------------
function fixROIoverlapsButton(~, ~)
    ROI = refineROI(avgImg, ROI);
    newImg = avgImg;
    displayROI();
end

%--------------------------------------------------------------------------
function fixROIshapeButton(~, ~)
  [success, refineROIthresholdOptionsCurrent] = preloadOptions(experiment, refineROIthresholdOptions, gui, true, false);
  if(success)
    ROI = refineROIthreshold(normalizeImage(avgImg, 'intensityRange', [minIntensity maxIntensity]), ROI, refineROIthresholdOptionsCurrent);
    setappdata(gui, 'refineROIthresholdOptionsCurrent', refineROIthresholdOptionsCurrent);
    displayROI();
  end
end

%--------------------------------------------------------------------------
function saveROIButton(~, ~)
    saveROI(experiment, ROI);
end

%--------------------------------------------------------------------------
function saveROIcentersButton(~, ~)
  [success, exportROIcentersOptionsCurrent] = preloadOptions(experiment, exportROIcentersOptions, gui, true, false);
  if(success)
    experiment = exportROIcenters(experiment, exportROIcentersOptionsCurrent);
    experiment.exportROIcentersOptionsCurrent = exportROIcentersOptionsCurrent;
  end
end

%--------------------------------------------------------------------------
function closeCallback(~, ~, varargin)

  experiment.ROI = ROI;

% Now compare what happens
  % Consistency checks
  ROIchanged = false;
  if(isfield(experiment, 'ROI') && isfield(oldExperiment, 'ROI'))
       if(length(oldExperiment.ROI) ~= length(experiment.ROI))
           ROIchanged = true;
       else
           for it = 1:length(experiment.ROI)
               if(oldExperiment.ROI{it}.center(1) ~= experiment.ROI{it}.center(1) || oldExperiment.ROI{it}.center(2) ~= experiment.ROI{it}.center(2))
                   ROIchanged = true;
                   break;
               end
           end
       end
%        for it = 1:length(experiment.ROI)
%          if(oldExperiment.ROI{it}.ID ~= experiment.ROI{it}.ID)
%            ROIchanged = true;
%            break;
%          end
%        end
      % ROI
      if(ROIchanged && isfield(experiment, 'rawTraces'))
          choice = questdlg('ROI length have changed. Do you want to remove the old traces?', ...
                            'ROI length changed', ...
                            'Yes', 'No', 'Cancel', 'Cancel');
          switch choice
              case 'Yes'
                  if(isfield(experiment, 'rawTraces'))
                      experiment = rmfield(experiment, 'rawTraces');
                      experiment = rmfield(experiment, 'rawT');
                  end
                  if(isfield(experiment, 'traces'))
                      experiment = rmfield(experiment, 'traces');
                      experiment = rmfield(experiment, 't');
                  end
                  if(isfield(experiment, 'features'))
                      experiment = rmfield(experiment, 'features');
                  end
                  if(isfield(experiment, 'similarityMatrix'))
                      experiment = rmfield(experiment, 'similarityMatrix');
                      experiment = rmfield(experiment, 'similarityOrder');
                  end
                  if(isfield(experiment, 'spikes'))
                      experiment = rmfield(experiment, 'spikes');
                  end
                   if(isfield(experiment, 'spikeFeatures'))
                      experiment = rmfield(experiment, 'spikeFeatures');
                      experiment = rmfield(experiment, 'spikeFeaturesNames');
                  end
              case 'No'
              case 'Cancel'
                experiment = oldExperiment;
                  return;
            otherwise
                experiment = oldExperiment;
                  return;
          end
      end
  end
  if(isequaln(oldExperiment, experiment))
    experimentChanged = false;
  else
    experimentChanged = true;
  end
  guiSave(experiment, experimentChanged, varargin{:});
  if(~isempty(gui))
    resizeHandle = getappdata(gui, 'ResizeHandle');
    if(isa(resizeHandle,'function_handle'))
      resizeHandle([], []);
    end
  end
  % Finally close the figure
  delete(hFigW);
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
            if(x >= 1+r && x <= size(avgImg, 2)-r && y >= 1+r && y <= size(avgImg, 1)-r)
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
            if(x >= 1+r && x <= size(avgImg, 2)-r && y >= 1+r && y <= size(avgImg, 1)-r)
                hold on;
                cursorHandle = rectangle('Position', [x-r, y-r, 2*r, 2*r], 'LineWidth', 2, 'EdgeColor', 'r');
            end

        end

    else
        %set(gcf,'Pointer','arrow');
    end

end

function hotkeyPan(~, ~, ~)
    changeSelectionMode('normal');
    pan;
    
end

function preferences(~, ~)
  [success, ROIselectionOptionsCurrent] = preloadOptions(experiment, ROIselectionOptions, gui, true, false);
  if(success)
    experiment.ROIselectionOptionsCurrent = ROIselectionOptionsCurrent;
  end
end

%--------------------------------------------------------------------------
function addSquare(~, ~, ~)
    changeSelectionMode('square');
    
    delete(plotHandleList);
    hold on;
    plotHandleList = [];
    I = uint16(avgImg);
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
        for j = 1:length(x)
            coord = floor([x(j), y(j)]);
            coordList = [coordList; coord];
            r = ROIselectionOptionsCurrent.sizeManual/2;
            if(x >= 1+r && x <= size(avgImg, 2)-r && y >= 1+r && y <= size(avgImg, 1)-r)
                % Add the ROI
                plotHandleList = [plotHandleList; rectangle('Position', [x-r, y-r, 2*r, 2*r], 'LineWidth', 2, 'EdgeColor', 'r')];
                mask = zeros(size(avgImg));
                mask(round(y-r):round(y+r), round(x-r):round(x+r)) = 1;
                B = bwconncomp(mask);
                ROI = [ROI(:)' cell(1)']';
                ROI{end}.ID = length(ROI);
                ROI{end}.pixels = B.PixelIdxList{1}';
                ROI{end}.center = [x, y];
                [y, x] = ind2sub(size(I), ROI{end}.pixels);
                ROI{end}.maxDistance = max(sqrt((ROI{end}.center(1)-x).^2+(ROI{end}.center(2)-y).^2));
                addCount = addCount + 1;
            end
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
    I = uint16(avgImg);
    %L = false(size(I));
    coordList = [];
    theta = linspace(0,2*pi, 50);
    r = ROIselectionOptionsCurrent.sizeManual/2;
    [gridX, gridY] = meshgrid(1:size(avgImg,2), 1:size(avgImg, 1));
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
        for j = 1:length(x)
            coord = floor([x(j), y(j)]);
            coordList = [coordList; coord];
            if(x >= 1+r && x <= size(avgImg, 2)-r && y >= 1+r && y <= size(avgImg, 1)-r)
                % Add the ROI
                plotHandleList = [plotHandleList; plot(x+r*cos(theta), y+r*sin(theta), 'r', 'LineWidth', 2)];
                mask = zeros(size(avgImg));
                
                mask((gridX-x).^2+(gridY-y).^2 <= r.^2) = 1;
                B = bwconncomp(mask);
                ROI = [ROI(:)' cell(1)']';
                ROI{end}.ID = length(ROI);
                ROI{end}.pixels = B.PixelIdxList{1}';
                ROI{end}.center = [x, y];
                [y, x] = ind2sub(size(I), ROI{end}.pixels);
                ROI{end}.maxDistance = max(sqrt((ROI{end}.center(1)-x).^2+(ROI{end}.center(2)-y).^2));
                addCount = addCount + 1;
            end
        end
    end
    changeSelectionMode('normal');
end

            
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Utility functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------------------------------------------------------------
function preloadROI()
    if(isfield(experiment, 'ROI'))
        ROI = experiment.ROI;
    end
    if(isempty(ROI))
        return
    end
    displayROI();
end

%--------------------------------------------------------------------------
function displayROI(varargin)
  if(isempty(varargin))
      mode = 'fast';
  else
      mode = varargin{1};
  end
  newImg = avgImg;
  switch mode
    case ' fast'
      ROIimg = visualizeROI(zeros(size(newImg)), ROI, 'plot', false, 'color', true, 'mode', mode);      
      %ROIimg = visualizeROI(zeros(size(newImg)), ROI, 'plot', false, 'color', true, 'mode', 'edgeHard');
      %ROIimg = visualizeROI(zeros(experiment.height, experiment.width), ROI, 'plot', false, 'color', true, 'mode','edgeHard', 'cmap', cmap);
      nROIimg = bwperim(sum(ROIimg,3) > 0);
      nROIimg = cat(3, nROIimg, nROIimg, nROIimg);
      ROIimg(~nROIimg) = ROIimg(~nROIimg)*0.25;
      ROIimg(nROIimg) = ROIimg(nROIimg)*2;
      ROIimg(ROIimg > 255) = 255;
      invalid = (ROIimg(:,:,1) == 0 & ROIimg(:,:,2) == 0 & ROIimg(:,:,3) == 0);
      alpha = ones(size(ROIimg,1), size(ROIimg,2))*0.5;
      alpha(invalid) = 0;
    case 'none'
      ROIimg = zeros(size(newImg));
      alpha = zeros(size(ROIimg,1), size(ROIimg,2));
    otherwise
      %ncbar.automatic('Plotting ROI...');
      %ROIimg = visualizeROI(zeros(size(newImg)), ROI, 'plot', false, 'color', true, 'mode', mode);      
      if(~isempty(ROI) && isfield(ROI{1}, 'weights'))
        ROIimg = visualizeROI(zeros(size(newImg)), ROI, 'plot', false, 'color', true, 'mode', 'edgeHard');
      else
        ROIimg = visualizeROI(zeros(size(newImg)), ROI, 'plot', false, 'color', true, 'mode', mode);
      end
      invalid = (ROIimg(:,:,1) == 0 & ROIimg(:,:,2) == 0 & ROIimg(:,:,3) == 0);
      alpha = ones(size(ROIimg,1), size(ROIimg,2))*0.25;
      alpha(invalid) = 0;
      %ncbar.close();
  end
  
  updateImage();

  set(ROIimgData, 'CData', ROIimg);
  set(ROIimgData, 'AlphaData', alpha);
    
end

%--------------------------------------------------------------------------
function updateImage()
    set(imData, 'CData', currFrame);
    caxis([minIntensity maxIntensity]);
    
    if(isempty(ROI))
      hs.numROItext.String = 'No ROI present';
    else
      hs.numROItext.String = sprintf('%d ROI present', length(ROI));
    end
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
            logMsg([num2str(addCount) ' ROI added']);
            logMsg([num2str(length(ROI)) ' ROI present']);
            addCount = 0;
        end
    end
    selectionMode = mode;
    if(~isempty(cursorHandle))
        delete(cursorHandle)
        cursorHandle = [];
    end
    updateImage();
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
