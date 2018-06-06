%% View ROI
%#ok<*AGROW>
%#ok<*ASGLU>
%#ok<*FXUP>
function [hFigW, experiment] = viewDenoiser(experiment)
% VIEWDENOISER
% More help about the program

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Initialization
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if(isfield(experiment, 'gliaAverageFrame'))
  choice = questdlg('What movie do you want to denoise?', 'Movie to denoise', 'original', 'glia', 'original');
  currentMovie = choice;
else
  currentMovie = 'original';
end
oldExperiment = experiment;
gui = gcbf;
hFigW = [];
if(~isempty(gui))
  project = getappdata(gui, 'project');
end
textFontSize = 10;
%headerFontSize = 12;
minGridBorder = 1;
currentPage = 1;

blockPointer = [];
blockSelected = [];
totalPages = 1;
currentMode = 'block'; % block / components
overlayData = [];

realSize = false;
switch currentMovie
  case 'original'
    currFrame = experiment.avgImg;
  case 'glia'
    currFrame = experiment.gliaAverageFrame;
  otherwise
    currFrame = experiment.avgImg;
end
currFrameBlockIdx = zeros(size(currFrame));
gridImg = zeros(size(currFrame));

bpp = experiment.bpp;
autoLevelsReset = true;
[~, denoiseRecordingOptionsCurrent] = preloadOptions(experiment, denoiseRecordingOptions, gui, false, false);
experiment.denoiseRecordingOptionsCurrent = denoiseRecordingOptionsCurrent;
experiment.denoiseRecordingOptionsCurrent.movie = currentMovie;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Create components
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
hs.mainWindow = figure('Visible','off',...
                       'Resize','on',...
                       'Toolbar', 'figure',...
                       'Tag','viewDenoiser', ...
                       'NumberTitle', 'off',...
                       'MenuBar', 'none',...
                       'DockControls','off',...
                       'Name', ['Denoiser viewer: ' experiment.name],...
                       'KeyPressFcn', @KeyPress, ...
                       'WindowButtonUpFcn', @rightClickUp, ...
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


hs.menuPreferences = uimenu(hs.mainWindow, 'Label', 'Preferences');
hs.menuPreferencesRealSize = uimenu(hs.menuPreferences, 'Label', 'Real Size', 'Enable', 'on', 'Callback', @menuPreferencesRealSize);

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
hs.mainWindowFramesPanel = uix.Panel('Parent', hs.mainWindowGrid, 'Padding', 5, 'BorderType', 'none');
hs.mainWindowFramesAxes = axes('Parent', hs.mainWindowFramesPanel);

imData = imagesc(currFrame);
hold on;
gridImgData = imagesc(ones(size(currFrame)));
valid = zeros(size(currFrame));
set(gridImgData, 'AlphaData', valid);

axis equal tight;
maxIntensity = max(currFrame(:));
minIntensity = min(currFrame(:));
set(hs.mainWindowFramesAxes, 'XTick', []);
set(hs.mainWindowFramesAxes, 'YTick', []);
set(hs.mainWindowFramesAxes, 'LooseInset', [0,0,0,0]);
box on;

% Below image panel

% Pages buttons -----------------------------------------------------------
hs.mainWindowBottomButtons = uix.HBox( 'Parent', hs.mainWindowGrid, 'Visible', 'off');
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', '< Previous PCs', 'FontSize', textFontSize, 'callback', {@changeComponentsPage, -1});
uix.Empty('Parent', hs.mainWindowBottomButtons);

hs.mainWindowBottomButtonsCurrentPage = uix.HBox( 'Parent', hs.mainWindowBottomButtons);
uicontrol('Parent', hs.mainWindowBottomButtonsCurrentPage, 'Style', 'text', 'String', 'Current page:', 'FontSize', textFontSize, 'HorizontalAlignment', 'right');

hs.currentPageText = uicontrol('Parent', hs.mainWindowBottomButtonsCurrentPage, 'Style','edit',...
          'String', '1', 'FontSize', textFontSize, 'HorizontalAlignment', 'left', 'Callback', @currentPageChange);
hs.totalPagesText = uicontrol('Parent', hs.mainWindowBottomButtonsCurrentPage, 'Style', 'text', 'String', ['/' num2str(totalPages)], 'FontSize', textFontSize, 'HorizontalAlignment', 'left');
set(hs.mainWindowBottomButtonsCurrentPage, 'Widths', [120 35 100], 'Spacing', 5, 'Padding', 0);


uix.Empty('Parent', hs.mainWindowBottomButtons);
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'Next PCs >', 'FontSize', textFontSize, 'callback', {@changeComponentsPage, 1});

set(hs.mainWindowBottomButtons, 'Widths', [100 -1 250 -1 100], 'Padding', 0, 'Spacing', 15);

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

htmlStrings = getHtmlColormapNames({'gray','parula', 'morgenstemning', 'jet', 'isolum'}, 115, 12);
uicontrol('Parent', b, 'Style','popup',   'Units','pixel', 'String', htmlStrings, 'Callback', @setmap, 'FontSize', textFontSize);

set(b, 'ButtonSize', [200 15], 'Spacing', 20, 'Padding', 0);
uicontrol('Parent', hs.mainWindowRightButtons, 'String', 'Auto levels', 'FontSize', textFontSize, 'Callback', @autoLevels);
uix.Empty('Parent', hs.mainWindowRightButtons);
uicontrol('Parent', hs.mainWindowRightButtons, 'String', 'Configure', 'FontSize', textFontSize, 'Callback', @configureDenoiser);
uicontrol('Parent', hs.mainWindowRightButtons, 'String', 'Run', 'FontSize', textFontSize, 'Callback', @trainDenoiser);
uix.Empty('Parent', hs.mainWindowRightButtons);
uicontrol('Parent', hs.mainWindowRightButtons, 'String', 'Show blocks', 'FontSize', textFontSize, 'Callback', @showBlocksMenu);
uicontrol('Parent', hs.mainWindowRightButtons, 'String', 'Show spatial components', 'FontSize', textFontSize, 'Callback', @showComponentsMenu);
uicontrol('Parent', hs.mainWindowRightButtons, 'String', 'Show temporal components', 'FontSize', textFontSize, 'Callback', @showComponentsTemporalMenu);
uix.Empty('Parent', hs.mainWindowRightButtons);
uicontrol('Parent', hs.mainWindowRightButtons, 'String', 'Show latent factors', 'FontSize', textFontSize, 'Callback', @showLatent);
uicontrol('Parent', hs.mainWindowRightButtons, 'String', 'Show denoised movie', 'FontSize', textFontSize, 'Callback', @showMovie);
uix.Empty('Parent', hs.mainWindowRightButtons);

b = uix.HBox( 'Parent', hs.mainWindowRightButtons);
minIntensityText = uicontrol('Parent', b, 'Style','edit',...
          'String', num2str(minIntensity), 'FontSize', textFontSize, 'HorizontalAlignment', 'left', 'callback', {@intensityChange, 'min'});
uicontrol('Parent', b, 'Style','text', 'String', 'Minimum', 'FontSize', textFontSize, 'HorizontalAlignment', 'left');
set(b, 'Widths', [30 -1], 'Spacing', 5, 'Padding', 0);

set(hs.mainWindowRightButtons, 'Heights', [20 -1 100 25 25 25 25 25 25 25 25 25 25 25 -1 20], 'Padding', 5);
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

colormap(gray);

set(hs.mainWindowGrid, 'Widths', [minGridBorder -1 25 200 minGridBorder], 'Heights', [minGridBorder -1 25 minGridBorder]);
cleanMenu();

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
    set(hs.mainWindowGrid, 'Widths', [minGridBorder -1 25 200 minGridBorder], 'Heights', [minGridBorder -1 25 minGridBorder]);
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
        minHeight = curPos(4) + 25 + minGridBorder*2+100;

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
        set(hs.mainWindowGrid, 'Widths', [-1 curPos(4)*realRatio 25 200 -1], 'Heights', [-1 curPos(4) 25 -1]);
    else
        set(hs.mainWindowGrid, 'Widths', [-1 curPos(3) 25 200 -1], 'Heights', [-1 curPos(3)/realRatio 25 -1]);
    end
end

%--------------------------------------------------------------------------
function rightClickUp(~, ~, ~)
  if(~strcmp(currentMode, 'block'))
    return;
  end
  if(~isempty(blockSelected) && (blockPointer == blockSelected))
    return;
  else
    blockSelected = blockPointer;
    updateImage();
  end
end

%--------------------------------------------------------------------------
function KeyPress(~, eventData)
  switch eventData.Key
    case {'rightarrow', 'd'}
      changeComponentsPage([], [], 1);
    case {'leftarrow', 'a'}
      changeComponentsPage([], [], -1);
    case {'uparrow', 'w'}
      changeComponentsPage([], [], 5);
    case {'downarrow', 's'}
      changeComponentsPage([], [], -5);
  end
end

%--------------------------------------------------------------------------
function showBlocksMenu(~, ~)
  currentMode = 'block';
  switch currentMovie
    case 'original'
      currFrame = experiment.avgImg;
    case 'glia'
      currFrame = experiment.gliaAverageFrame;
  end
  updateImage();
  autoLevels([], [], true);
end

%--------------------------------------------------------------------------
function showComponentsMenu(~, ~)
  if(~isfield(experiment, 'denoisedDataTraining'))
    logMsg('No training data found. Run the denoiser first.', 'w');
    return;
  end
  currentMode = 'components';
  
  updateImage();
  autoLevels([], [], true);
end

%--------------------------------------------------------------------------
function showComponentsTemporalMenu(~, ~)
  if(~isfield(experiment, 'denoisedDataTraining'))
    logMsg('No training data found. Run the denoiser first.', 'w');
    return;
  end
  currentMode = 'componentsTemporal';
  updateImage();
  end

%--------------------------------------------------------------------------
function currentPageChange(hObject, ~)
  input = round(str2double(get(hObject,'string')));
  if isnan(input)
    errordlg('You must enter a numeric value','Invalid Input','modal')
    uicontrol(hObject)
    return;
  end
  currentPage = input;
  changeComponentsPage([], [], 0);
end

%--------------------------------------------------------------------------
function changeComponentsPage(~, ~, change)
  if(experiment.denoiseRecordingOptionsCurrent.blockSize(1) >= 512)
    N = 4;
  else
    N = 16; % Hard coded number of blocks - let's concatenate data
  end
  currentPage = currentPage + change;
  totalPages = ceil((experiment.denoisedDataTraining(1).Ncomponents+1)/N);
  hs.totalPagesText.String = ['/' num2str(totalPages)];
  if(currentPage < 1)
    currentPage = 1;
  elseif(currentPage > totalPages)
    currentPage = totalPages;
  end
  hs.currentPageText.String = num2str(currentPage);
  updateImage();
  autoLevels([], [], true);
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

% ImageJ old auto version
%--------------------------------------------------------------------------
function autoLevels(~, ~, reset)
  if(nargin >= 3)
    autoLevelsReset = reset;
  end
  switch currentMovie
    case 'glia'
      [minIntensity, maxIntensity] = autoLevelsFIJI(currFrame, bpp, autoLevelsReset, true, true);
    otherwise
      [minIntensity, maxIntensity] = autoLevelsFIJI(currFrame, bpp, autoLevelsReset);
  end
  
  maxIntensityText.String = sprintf('%.2f', maxIntensity);
  minIntensityText.String = sprintf('%.2f', minIntensity);
  updateImage();
  autoLevelsReset = false;
end

%--------------------------------------------------------------------------
function configureDenoiser(~, ~)
  prevBlockSize = experiment.denoiseRecordingOptionsCurrent.blockSize;
  [success, denoiseRecordingOptionsCurrent] = preloadOptions(experiment, denoiseRecordingOptions, gcbf, true, false);
  if(~success)
    return;
  end
  experiment.denoiseRecordingOptionsCurrent = denoiseRecordingOptionsCurrent;
  if(~all(prevBlockSize == experiment.denoiseRecordingOptionsCurrent.blockSize))
    blockSelected = [];
  end
  updateImage();
end

%--------------------------------------------------------------------------
function trainDenoiser(~, ~)
  if(isempty(blockSelected))
    logMsg('Please select a block first. Just click on the image. It will show in red', 'w');
    return;
  end
  experiment.denoiseRecordingOptionsCurrent.movie = currentMovie;
  experiment = denoiseRecording(experiment, experiment.denoiseRecordingOptionsCurrent, 'training', true, 'trainingBlock', blockSelected);
  setappdata(gcf, 'training', experiment.denoisedDataTraining(1));
  showComponentsMenu([], []);
  currentPage = 1;
  changeComponentsPage([], [], 0)
end

%--------------------------------------------------------------------------
function showLatent(~, ~)
  if(~isfield(experiment, 'denoisedDataTraining'))
    logMsg('No training data found. Run the denoiser first.', 'w');
    return;
  end
  latent = experiment.denoisedDataTraining(1).latent;
  largestComponent = experiment.denoisedDataTraining(1).largestComponent;
  
  figure;
  plot((1:length(latent)),latent, '.');
  hold on;
  plot(largestComponent,latent(largestComponent), 'o');

  set(gca,'XScale', 'log');
  set(gca,'YScale', 'log');

  xlabel('Ordered principal components (PC)');
  ylabel('Latent factors score');
  legend('Latent factors', sprintf('Suggested maximum PC: %d', largestComponent));
  title('Latent factors');
end

%--------------------------------------------------------------------------
function showMovie(~, ~)
  if(~isfield(experiment, 'denoisedDataTraining'))
    logMsg('No training data found. Run the denoiser first.', 'w');
    return;
  end

  dummyExperiment = experiment;
  dummyExperiment.virtual = true;
  dummyExperiment.tag = 'dummy';
  if(isfield(dummyExperiment, 'denoisedData'))
    dummyExperiment = rmfield(dummyExperiment, 'denoisedData');
  end
  dummyExperiment.denoisedData(1) = experiment.denoisedDataTraining(1);
  dummyExperiment.numFrames = dummyExperiment.denoisedData(1).frames(2)-dummyExperiment.denoisedData(1).frames(1)+1;
  % Component killing
  %dummyExperiment.denoisedData(1).coeff(:, 3) = 0;
  %componentSurvival = 7:size(dummyExperiment.denoisedData(1).coeff, 2);
  %componentSurvival = 20:40;
%   figure;
%   ar = dummyExperiment.denoisedData(1).score;
%   for it = 1:size(ar, 2)
%     ar(:, it) = zscore(abs(ar(:, it)));
%   end
%   imagesc(ar);
%   hold on;
%   for it2 = 5:15
%     fval = zeros(1, 299);
%     curComponent = it2;
%     for it = 1:299
%       fval(it) = mean(dummyExperiment.denoisedData(1).score(it, curComponent)*dummyExperiment.denoisedData(1).coeff(:, curComponent)');
%     end
%     plot(fval);
%   end

  %figure;
  %plot(mean(abs(dummyExperiment.denoisedData(1).coeff)));
  
  %componentSurvival = 3;
  %dummyExperiment.denoisedData(1).coeff(:, setxor(1:size(dummyExperiment.denoisedData(1).coeff, 2), componentSurvival)) = 0;
  % Mean killing
  %dummyExperiment.denoisedData(1)
  %dummyExperiment.denoisedData(1).means = dummyExperiment.denoisedData(1).means*0;
  %dummyExperiment.denoisedData(1).needsTranspose = 0;
  
  switch currentMovie
    case 'glia'
      viewGlia(dummyExperiment);
  otherwise
    viewRecording(dummyExperiment);
  end
  %viewRecording(dummyExperiment);
  %implay(img);
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
function closeCallback(~, ~, varargin)
  % We do not want to keep training data
  if(isfield(experiment, 'denoisedDataTraining'))
    experiment = rmfield(experiment, 'denoisedDataTraining');
  end
  if(isequaln(oldExperiment, experiment))
    experimentChanged = false;
  else
    experimentChanged = true;
  end
  guiSave(experiment, experimentChanged, varargin{:});
  
  resizeHandle = getappdata(gui, 'ResizeHandle');
  if(isa(resizeHandle,'function_handle'))
    resizeHandle([], []);
  end
  % Finally close the figure
  delete(hFigW);
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
function ROIWindowButtonMotionFcn(~, ~, ~)
  hObj = hittest(gcf);
  if(isa(hObj, 'matlab.graphics.primitive.Image'))
    %set(gcf,'Pointer','cross');
    %cursorHandle
    if(strcmp(currentMode, 'block'))
      C = get (gca, 'CurrentPoint');
      x = round(C(1,1));
      y = round(C(1,2));
      blockPointer = currFrameBlockIdx(y, x);
    end
  end
end
            
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Utility functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------------------------------------------------------------
function updateImage()
  switch currentMode
    case 'block'
      hs.mainWindowBottomButtons.Visible = 'off';
      plotGrid();
      set(imData, 'CData', currFrame);
      caxis([minIntensity maxIntensity]);
    case 'components'
      hs.mainWindowBottomButtons.Visible = 'on';
      plotComponents();
      set(imData, 'CData', currFrame);
      caxis([minIntensity maxIntensity]);
    case 'componentsTemporal'
      plotComponentsTemporal();
      %plotComponentsGrid();
  end
  
end

%--------------------------------------------------------------------------
function plotGrid()
  axes(hs.mainWindowFramesAxes);
  cla;
  imData = imagesc(currFrame);
  axis square ij;
  set(gca,'XTick',[]);
  set(gca,'YTick',[]);
  xlim([1 size(currFrame, 2)]);
  ylim([1 size(currFrame, 1)]);
  hold on;
  gridImgData = imagesc(ones(size(currFrame)));
  
  blockSize = experiment.denoiseRecordingOptionsCurrent.blockSize;
  blockOverlap = experiment.denoiseRecordingOptionsCurrent.blockOverlap;
  currentBlock = 0;
  gridImg = zeros(size(currFrame));
  gridImgFull = cat(3, gridImg, gridImg, gridImg);

  % Let's generate the block positions
  height = size(gridImg, 2);
  width = size(gridImg, 1);
  numRowBlocks = ceil((height-blockSize(1))/(blockSize(1)-blockOverlap(1)))+1;
  numColBlocks = ceil((width-blockSize(2))/(blockSize(2)-blockOverlap(2)))+1;
  blockRowCoordinates = 1+((1:numRowBlocks)-1)*(blockSize(1)-blockOverlap(1));
  blockColCoordinates = 1+((1:numColBlocks)-1)*(blockSize(2)-blockOverlap(2));
  
  % For some reason I have to change ordering here...
  for blockIt1 = 1:length(blockRowCoordinates)
    for blockIt2 = 1:length(blockColCoordinates)
      currentBlock = currentBlock + 1;

      idx1 = blockRowCoordinates(blockIt1);
      idx2 = blockColCoordinates(blockIt2);
      idx1Last = min(idx1+blockSize(1)-1, height);
      idx2Last = min(idx2+blockSize(2)-1, width);
      currFrameBlockIdx(idx1:idx1Last, idx2:idx2Last) = currentBlock;
      if(~isempty(blockSelected) && blockSelected == currentBlock)
        colorIdx = 1;
        gridImgFull(idx1:idx1Last, idx2:idx2Last, colorIdx) = 0.4;
      else
        colorIdx = 1:3;
      end
      % Now the lines - keep t simple
      gridImgFull(idx1, idx2:idx2Last, colorIdx) = 2^experiment.bpp-1;
      gridImgFull(idx1Last, idx2:idx2Last, colorIdx) = 2^experiment.bpp-1;
      gridImgFull(idx1:idx1Last, idx2, colorIdx) = 2^experiment.bpp-1;
      gridImgFull(idx1:idx1Last, idx2Last, colorIdx) = 2^experiment.bpp-1;
    end
  end
  
  set(gridImgData, 'CData', gridImgFull);
  set(gridImgData, 'AlphaData', squeeze(gridImgFull(:, :, 1)));
  recreateOverlayText([], [], {});
end

%--------------------------------------------------------------------------
function plotComponents()
  axes(hs.mainWindowFramesAxes);
  cla;
  imData = imagesc(currFrame);
  axis square ij;
  set(gca,'XTick',[]);
  set(gca,'YTick',[]);
  xlim([1 size(currFrame, 2)]);
  ylim([1 size(currFrame, 1)]);
  hold on;
  gridImgData = imagesc(ones(size(currFrame)));
  
  if(experiment.denoiseRecordingOptionsCurrent.blockSize(1) >= 512)
    N = 4;
  else
    N = 16; % Hard coded number of blocks - let's concatenate data
  end
  %experiment.denoisedDataTraining(1)
  coeff = experiment.denoisedDataTraining(1).coeff;
  score = experiment.denoisedDataTraining(1).score;
  blockSize = experiment.denoiseRecordingOptionsCurrent.blockSize;
  largestComponent = experiment.denoisedDataTraining(1).largestComponent;
  % Coeff1
  currFrame = zeros(blockSize(1)*sqrt(N), blockSize(2)*sqrt(N));
  gridImg = zeros(size(currFrame));
  gridImgFull = cat(3, gridImg, gridImg, gridImg);
  
  %coeffIdx = 0;
  coeffIdx = N*(currentPage-1);
  % 1 less than expected
  if(currentPage > 1)
    coeffIdx = coeffIdx - 1;
  end
  textX = [];
  textY = [];
  textText = {};
  % Ugh
  %normalizationMask = zeros(size(currFrame));
  for it1 = 1:sqrt(N)
    for it2= 1:sqrt(N)
      % First entry is special, plot the SUM of the selected components
      if(it1 == 1 && it2 == 1 && currentPage == 1)
        avgData = zeros(blockSize(1), blockSize(2));
        for k = 1:largestComponent
          zData = sum(coeff(:, k),2);
          %zData = zData + experiment.denoisedDataTraining(1).means';
          zData = reshape(zData, [blockSize(1), blockSize(2)]);
          avgData = avgData + zData;
        end
        %zData = avgData/largestComponent;
        zData = avgData;
        zData = (zData-min(zData(:)))/(max(zData(:))-min(zData(:)));
        rangeR = ((it1-1)*blockSize(1):it1*blockSize(1)-1)+1;
        rangeC = ((it2-1)*blockSize(2):it2*blockSize(2)-1)+1;
        currFrame(rangeR, rangeC) = zData'*(2^experiment.bpp-1);
        %normalizationMask(rangeR, rangeC) = 1;
        textX = [textX, rangeC(1)];
        textY = [textY, rangeR(1)];
        textText{end+1} = 'avg selected';
        %figure;plot(currFrame(:),'.');
      else
        coeffIdx = coeffIdx + 1;
        if(coeffIdx > experiment.denoisedDataTraining(1).Ncomponents)
          continue;
        end
        %zData = sum(coeff(:, coeffIdx),2);
        zData = mean(score(:, coeffIdx)*coeff(:, coeffIdx)');
        zData = reshape(zData, [blockSize(1), blockSize(2)]);
        pmin = prctile(zData(:), 0.1);
        pmax = prctile(zData(:), 99.9);
        zData(zData < pmin) = pmin;
        zData(zData > pmax) = pmax;
        
        zData = (zData-min(zData(:)))/(max(zData(:))-min(zData(:)));
        rangeR = ((it1-1)*blockSize(1):it1*blockSize(1)-1)+1;
        rangeC = ((it2-1)*blockSize(2):it2*blockSize(2)-1)+1;
        currFrame(rangeR, rangeC) = zData';
        currFrame(rangeR, rangeC) = zData'*(2^experiment.bpp-1);
        % Now color code the components
        if(coeffIdx <= largestComponent)
          colorIdx = 1;
          gridImgFull(rangeR, rangeC, colorIdx) = 0.;
          % Now the lines - keep t simple
          gridImgFull(rangeR(1), rangeC) = 2^experiment.bpp-1;
          gridImgFull(rangeR(end), rangeC, colorIdx) = 2^experiment.bpp-1;
          gridImgFull(rangeR, rangeC(1), colorIdx) = 2^experiment.bpp-1;
          gridImgFull(rangeR, rangeC(end), colorIdx) = 2^experiment.bpp-1;
        end
        textX = [textX, rangeC(1)];
        textY = [textY, rangeR(1)];
        textText{end+1} = sprintf('%d PC', coeffIdx);
      end
    end
  end
  %valid = find(~normalizationMask);
  %currFrame(valid) = (currFrame(valid)-min(currFrame(valid)))/(max(currFrame(valid))-min(currFrame(valid)))*2^experiment.bpp-1;
  set(gridImgData, 'CData', gridImgFull);
  set(gridImgData, 'AlphaData', squeeze(gridImgFull(:, :, 1)));
  % For now, just hide the grid
  %set(gridImgData, 'CData', zeros(size(currFrame)));
  %set(gridImgData, 'AlphaData', zeros(size(currFrame)));
  recreateOverlayText(textX, textY, textText);
end

%--------------------------------------------------------------------------
function plotComponentsTemporal()
  if(experiment.denoiseRecordingOptionsCurrent.blockSize(1) >= 512)
    N = 4;
  else
    N = 16; % Hard coded number of blocks - let's concatenate data
  end
  %experiment.denoisedDataTraining(1)
  coeff = experiment.denoisedDataTraining(1).coeff;
  scores = experiment.denoisedDataTraining(1).score;
  means = experiment.denoisedDataTraining(1).means;
  blockSize = experiment.denoiseRecordingOptionsCurrent.blockSize;
  largestComponent = experiment.denoisedDataTraining(1).largestComponent;
  % Coeff1
  currFrame = zeros(blockSize(1)*sqrt(N), blockSize(2)*sqrt(N));
  gridImg = zeros(size(currFrame));
  gridImgFull = cat(3, gridImg, gridImg, gridImg);
  
  %coeffIdx = 0;
  coeffIdx = N*(currentPage-1);
  % 1 less than expected
  if(currentPage > 1)
    coeffIdx = coeffIdx - 1;
  end
  textX = [];
  textY = [];
  textText = {};
  % Ugh
  %normalizationMask = zeros(size(currFrame));
  axes(hs.mainWindowFramesAxes);
  cla;
  hold on;
  axis square xy;
  coeffIdxInitial = coeffIdx;
  xlim([1 size(scores, 1)]);
  xl = xlim;
  for it1 = 1:sqrt(N)
    for it2= 1:sqrt(N)
      % First entry is special, plot the average of the selected components
      if(it1 == 1 && it2 == 1 && currentPage == 1)
%         avgData = zeros(blockSize(1), blockSize(2));
%         for k = 1:largestComponent
%           zData = sum(coeff(:, k),2);
%           zData = zData + experiment.denoisedDataTraining(1).means';
%           zData = reshape(zData, [blockSize(1), blockSize(2)]);
%           avgData = avgData + zData;
%         end
%         zData = avgData/largestComponent;
%         zData = (zData-min(zData(:)))/(max(zData(:))-min(zData(:)));
        rangeR = ((it1-1)*blockSize(1):it1*blockSize(1)-1)+1;
        rangeC = ((it2-1)*blockSize(2):it2*blockSize(2)-1)+1;
%         currFrame(rangeR, rangeC) = zData'*(2^experiment.bpp-1);
        %normalizationMask(rangeR, rangeC) = 1;
        textX = [textX, rangeC(1)];
        textY = [textY, rangeR(1)];
        textText{end+1} = 'avg selected';
        %figure;plot(currFrame(:),'.');
      else
        coeffIdx = coeffIdx + 1;
        if(coeffIdx > experiment.denoisedDataTraining(1).Ncomponents)
          continue;
        end
        %tr = scores(:, coeffIdx)*mean(coeff(:, coeffIdx));
        %tr = scores(:, coeffIdx);
        tr = mean(scores(:, coeffIdx)*coeff(:, coeffIdx)',2);
        val = max(abs(tr));
        tr = (tr-min(tr(:)))/(max(tr(:))-min(tr(:)));
        plot(1:length(tr), tr+coeffIdx-0.5);
        %val = max(selectedTraces(:, currentOrder(firstTrace+i-1)))-min(selectedTraces(:, currentOrder(firstTrace+i-1)));
        text(xl(2)*0.9, coeffIdx-0.5, sprintf('%.1f', val/mean(means)));

%         zData = sum(coeff(:, coeffIdx),2);
%         zData = reshape(zData, [blockSize(1), blockSize(2)]);
%         zData = (zData-min(zData(:)))/(max(zData(:))-min(zData(:)));
        
%         currFrame(rangeR, rangeC) = zData';
%         currFrame(rangeR, rangeC) = zData'*(2^experiment.bpp-1);
        % Now color code the components
       end
    end
  end
  set(gca,'XTick', [1 length(tr)]);
  set(gca,'YTick', coeffIdxInitial:coeffIdx);
  ylim([coeffIdxInitial coeffIdx+1]);
  %set(gridImgData, 'CData', gridImgFull);
  %set(gridImgData, 'AlphaData', squeeze(gridImgFull(:, :, 1)));

%  recreateOverlayText(textX, textY, textText);
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
function recreateOverlayText(textX, textY, textText)
  blockSize = experiment.denoiseRecordingOptionsCurrent.blockSize;
  if(~isempty(overlayData))
    for it = 1:length(overlayData)
      if(ishandle(overlayData(it)) && isvalid(overlayData(it)))
        delete(overlayData(it))
      end
    end
  end
  for it = 1:length(textX)
    overlayData = [overlayData, text(hs.mainWindowFramesAxes, textX(it)+blockSize(2)*0.05, textY(it)+blockSize(1)*0.05, textText{it}, 'Color','w','FontSize', 12)];
  end
end

end
