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
currFrame = experiment.avgImg;
currFrameBlockIdx = zeros(size(currFrame));
gridImg = zeros(size(currFrame));

bpp = experiment.bpp;
autoLevelsReset = true;
[~, denoiseRecordingOptionsCurrent] = preloadOptions(experiment, denoiseRecordingOptions, gui, false, false);
experiment.denoiseRecordingOptionsCurrent = denoiseRecordingOptionsCurrent;
  
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
uicontrol('Parent', hs.mainWindowRightButtons, 'String', 'Show components', 'FontSize', textFontSize, 'Callback', @showComponentsMenu);
uix.Empty('Parent', hs.mainWindowRightButtons);
uicontrol('Parent', hs.mainWindowRightButtons, 'String', 'Show latent factors', 'FontSize', textFontSize, 'Callback', @showLatent);
uicontrol('Parent', hs.mainWindowRightButtons, 'String', 'Show denoised movie', 'FontSize', textFontSize, 'Callback', @showMovie);
uix.Empty('Parent', hs.mainWindowRightButtons);

b = uix.HBox( 'Parent', hs.mainWindowRightButtons);
minIntensityText = uicontrol('Parent', b, 'Style','edit',...
          'String', num2str(minIntensity), 'FontSize', textFontSize, 'HorizontalAlignment', 'left', 'callback', {@intensityChange, 'min'});
uicontrol('Parent', b, 'Style','text', 'String', 'Minimum', 'FontSize', textFontSize, 'HorizontalAlignment', 'left');
set(b, 'Widths', [30 -1], 'Spacing', 5, 'Padding', 0);

set(hs.mainWindowRightButtons, 'Heights', [20 -1 100 25 25 25 25 25 25 25 25 25 25 -1 20], 'Padding', 5);
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
  currFrame = experiment.avgImg;
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
  N = 16; % Hard coded number of blocks - let's concatenate data
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
  [minIntensity, maxIntensity] = autoLevelsFIJI(currFrame, bpp, autoLevelsReset);
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
  experiment = denoiseRecording(experiment, experiment.denoiseRecordingOptionsCurrent, 'training', true, 'trainingBlock', blockSelected);
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
%  selectedFrames = experiment.denoisedDataTraining(1).frames(1):experiment.denoisedDataTraining(1).frames(2);
%  blockSize = experiment.denoisedDataTraining(1).blockSize;
%  largestComponent = experiment.denoisedDataTraining(1).blockSize;
  
%  img = zeros(blockSize(1), blockSize(2), length(selectedFrames));
%   ncbar('Generating denoised movie');
%   for f = 1:length(selectedFrames)
%     pimg = zeros(blockSize(1), blockSize(2));
%     selectedFrame = selectedFrames(f);
%     
%     Xapprox = experiment.denoisedDataTraining(1).score(selectedFrame, 1:largestComponent) * experiment.denoisedDataTraining(1).coeff(:, 1:largestComponent)';
%     Xapprox = bsxfun(@plus,experiment.denoisedDataTraining(1).means, Xapprox); % add the mean back in
% 
%     Xapprox = reshape(Xapprox, [blockSize(1) blockSize(2)]);
%     % Heh, it's actually the opposite probably
%     if(~experiment.denoisedDataTraining(1).needsTranspose)
%       Xapprox = Xapprox';
%     end
%     pimg(:) = Xapprox;
%     img(:, :, f) = pimg';
%     ncbar.update(f/length(selectedFrames));
%   end
%   ncbar.close();
  %img = (img-min(img(:)))/(max(img(:))-min(img(:)));
  % Create the necessary fields to load the recording viewer
%   dummyExperiment = struct;
%   dummyExperiment.virtual = true;
%   dummyExperiment.width = size(img, 2);
%   dummyExperiment.height = size(img, 1);
%   dummyExperiment.name = [experiment.name 'denoiser'];
%   dummyExperiment.numFrames = size(img, 3);
%   dummyExperiment.fps = experiment.fps;
%   dummyExperiment.bpp = experiment.bpp;
%   dummyExperiment.denoisedData(1) = experiment.denoisedDataTraining(1);
%   dummyExperiment.denoisedData(1).block = [1 1];
%   dummyExperiment.denoisedData(1).blockCoordinates = [1 1];
%   dummyExperiment.denoisedData(1).pixelList = 1:dummyExperiment.width*dummyExperiment.height;
%   dummyExperiment.folder = experiment.folder;
%   dummyExperiment.handle = 'dummy';
%   dummyExperiment.extension = 'dummy';
%   viewRecording(dummyExperiment);
  dummyExperiment = experiment;
  dummyExperiment.virtual = true;
  dummyExperiment.tag = 'dummy';
  dummyExperiment = rmfield(dummyExperiment, 'denoisedData');
  dummyExperiment.denoisedData(1) = experiment.denoisedDataTraining(1);
  dummyExperiment.numFrames = dummyExperiment.denoisedData(1).frames(2)-dummyExperiment.denoisedData(1).frames(1)+1;
  viewRecording(dummyExperiment);
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
  set(imData, 'CData', currFrame);
  caxis([minIntensity maxIntensity]);

  switch currentMode
    case 'block'
      hs.mainWindowBottomButtons.Visible = 'off';
      plotGrid();
    case 'components'
      hs.mainWindowBottomButtons.Visible = 'on';
      plotComponents();
      %plotComponentsGrid();
  end
end

%--------------------------------------------------------------------------
function plotGrid()
  blockSize = experiment.denoiseRecordingOptionsCurrent.blockSize;
  currentBlock = 0;
  gridImg = zeros(size(currFrame));
  gridImgFull = cat(3, gridImg, gridImg, gridImg);

  % For some reason I have to change ordering here...
  for blockIt1 = 1:experiment.height/blockSize(1)
    for blockIt2 = 1:experiment.width/blockSize(2)
      currentBlock = currentBlock + 1;
      BID1 = blockIt1;
      BID2 = blockIt2;

      idx1 = blockSize(1)*(BID1-1)+1;
      idx2 = blockSize(2)*(BID2-1)+1;
      currFrameBlockIdx(idx1:idx1+blockSize(1)-1, idx2:idx2+blockSize(2)-1) = currentBlock;
      if(~isempty(blockSelected) && blockSelected == currentBlock)
        colorIdx = 1;
        gridImgFull(idx1:idx1+blockSize(1)-1, idx2:idx2+blockSize(2)-1, colorIdx) = 0.4;
      else
        colorIdx = 1:3;
      end
      % Now the lines - keep t simple
      gridImgFull(idx1, idx2:idx2+blockSize(2)-1, colorIdx) = 2^experiment.bpp-1;
      gridImgFull(idx1+blockSize(1)-1, idx2:idx2+blockSize(2)-1, colorIdx) = 2^experiment.bpp-1;
      gridImgFull(idx1:idx1+blockSize(1)-1, idx2, colorIdx) = 2^experiment.bpp-1;
      gridImgFull(idx1:idx1+blockSize(1)-1, idx2+blockSize(2)-1, colorIdx) = 2^experiment.bpp-1;
    end
  end
  
  set(gridImgData, 'CData', gridImgFull);
  set(gridImgData, 'AlphaData', squeeze(gridImgFull(:, :, 1)));
  recreateOverlayText([], [], {});
end

%--------------------------------------------------------------------------
function plotComponents()
  N = 16; % Hard coded number of blocks - let's concatenate data
  %experiment.denoisedDataTraining(1)
  coeff = experiment.denoisedDataTraining(1).coeff;
  blockSize = experiment.denoiseRecordingOptionsCurrent.blockSize;
  largestComponent = experiment.denoisedDataTraining(1).largestComponent;
  % Coeff1
  currFrame = zeros(blockSize(1)*4, blockSize(2)*4);
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
      % First entry is special, plot the average of the selected components
      if(it1 == 1 && it2 == 1 && currentPage == 1)
        avgData = zeros(blockSize(1), blockSize(2));
        for k = 1:largestComponent
          zData = sum(coeff(:, k),2);
          zData = zData + experiment.denoisedDataTraining(1).means';
          zData = reshape(zData, [blockSize(1), blockSize(2)]);
          avgData = avgData + zData;
        end
        zData = avgData/largestComponent;
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
        zData = sum(coeff(:, coeffIdx),2);
        zData = reshape(zData, [blockSize(1), blockSize(2)]);
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
