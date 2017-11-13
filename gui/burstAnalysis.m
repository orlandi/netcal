function [hFigW, experiment] = burstAnalysis(experiment)
% BURSTANALYSIS performs burst analysis on the given experiment
%
% USAGE:
%    burstAnalysis(gui, experiment)
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
%    hFigW = burstAnalysis(gui, experiment)
%
% Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also loadExperiment

%#ok<*AGROW>
%#ok<*ASGLU>
%#ok<*FXUP>

%% Initialization
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
gui = gcbf;
textFontSize = 10;
minGridBorder = 1;
selectionTitle = [];
selectedTraces = [];
selectedT = [];
currentOrder = [];

learningMode = 'none';
buttonDown = false;
detectionType = 'schmitt'; % schmitt
rectangleH = [];
rectangleStart = [];
originalExperiment = experiment;

if(~isempty(gui))
  project = getappdata(gui, 'project');
else
  project = [];
end

lastID = 0;
[success, burstPatternOptionsCurrent] = preloadOptions(experiment, burstPatternOptions, gui, false, false);
experiment.burstPatternOptionsCurrent = burstPatternOptionsCurrent;
[success, burstDetectionOptionsCurrent] = preloadOptions(experiment, burstDetectionOptions, gui, false, false);
experiment.burstDetectionOptionsCurrent = burstDetectionOptionsCurrent;

experiment = checkGroups(experiment);

%% Create components
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

hs.mainWindow = figure('Visible','off',...
                       'Resize','on',...
                       'Toolbar', 'figure',...
                       'Tag','burstAnalysis', ...
                       'DockControls','off',...
                       'NumberTitle', 'off',...
                       'ResizeFcn', @resizeCallback, ...
                       'CloseRequestFcn', @closeCallback,...
                       'MenuBar', 'none',...
                       'WindowButtonUpFcn', @rightClickUp, ...
                       'WindowButtonMotionFcn', @buttonMotion, ...
                       'Name', ['Burst analysis: ' experiment.name]);
hFigW = hs.mainWindow;
hFigW.Position = setFigurePosition(gui, 'width', 1000, 'height', 650);
setappdata(hFigW, 'experiment', experiment);

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


hs.menu.patterns.root = uimenu(hs.mainWindow, 'Label', 'Patterns');
hs.menu.patterns.view = uimenu(hs.menu.patterns.root, 'Label', 'View patterns', 'Callback', @menuViewPatterns);

% This order due to cross references
hs.menu.sort = [];

% Finish the selection menus
hs.menu.traces.selection = generateSelectionMenu(experiment, hs.menu.traces.root);

hs.menuExport = uimenu(hs.mainWindow, 'Label', 'Export');
hs.menuExportFigure = uimenu(hs.menuExport, 'Label', 'Figure', 'Callback', @exportTraces);

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
hs.mainWindowBottom = uix.VBox( 'Parent', hs.mainWindowGrid);
hs.mainWindowBottomButtons = uix.HButtonBox( 'Parent', hs.mainWindowBottom);
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'Burst detection', 'FontSize', textFontSize, 'callback', @burstDetectionButton);
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'Burst statistics', 'FontSize', textFontSize, 'callback', @burstStatistics);
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'Pattern selection', 'FontSize', textFontSize, 'callback', @burstPatternSelection);
set(hs.mainWindowBottomButtons, 'ButtonSize', [150 15], 'Padding', 0, 'Spacing', 15);

% Learning module ---------------------------------------------------------
hs.mainWindowLearningPanel = uix.Panel( 'Parent', hs.mainWindowBottom, 'Title', 'Learning module', 'Padding', 5, 'TitlePosition', 'centertop', 'Visible', 'off');

hs.mainWindowLearningButtons = uix.HBox( 'Parent', hs.mainWindowLearningPanel);
hs.mainWindowLearningGroupSelectionNtraces = uicontrol('Parent', hs.mainWindowLearningButtons, 'Style', 'text', 'String', 'X bursts assigned', 'FontSize', textFontSize, 'HorizontalAlignment', 'left');
uix.Empty('Parent', hs.mainWindowLearningButtons);

hs.eventButtonLengthText = uicontrol('Parent', hs.mainWindowLearningButtons, 'Style', 'text', 'String', 'Event sampling length (s):', 'FontSize', textFontSize, 'HorizontalAlignment', 'left', 'Visible', 'on');
hs.eventButtonLengthEdit = uicontrol('Parent', hs.mainWindowLearningButtons, 'Style', 'edit', 'String', '1', 'Callback', @eventLengthChange, 'Visible', 'on');

hs.eventButtonSizeText = uicontrol('Parent', hs.mainWindowLearningButtons, 'Style', 'text', 'String', 'Minimum event size (s)', 'FontSize', textFontSize, 'HorizontalAlignment', 'left', 'Visible', 'on');
hs.eventButtonSizeEdit = uicontrol('Parent', hs.mainWindowLearningButtons, 'Style', 'edit', 'String', '1', 'Callback', @eventMinSizeChange, 'Visible', 'on');

hs.eventButtonThresholdText = uicontrol('Parent', hs.mainWindowLearningButtons, 'Style', 'text', 'String', 'Event threshold:', 'FontSize', textFontSize, 'HorizontalAlignment', 'left', 'Visible', 'on');
hs.eventButtonThresholdEdit = uicontrol('Parent', hs.mainWindowLearningButtons, 'Style', 'edit', 'String', '1', 'Callback', @eventThresholdChange, 'Visible', 'on');

uix.Empty('Parent', hs.mainWindowLearningButtons);
hs.mainWindowLearningFinish = uicontrol('Parent', hs.mainWindowLearningButtons, 'Style', 'pushbutton', 'String', 'Finish', 'Callback', @learningFinish, 'Visible', 'on');

set(hs.mainWindowLearningButtons, 'Widths', [125 -1 100 50 100 50 100 50 -1 100], 'Padding', 0, 'Spacing', 15);

set(hs.mainWindowBottom, 'Heights', [35 70], 'Padding', 5, 'Spacing', 10);

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
setappdata(hFigW, 'currentOrder', currentOrder);
if(isfield(experiment, 'traces'))
  menuTracesType([], [], 'smoothed');
  hs.menu.traces.typeSmoothed.Checked = 'on';
else
  menuTracesType([], [], 'raw');
  hs.menu.traces.typeRaw.Checked = 'on';
end
hs.mainWindow.Visible = 'on';
selectGroup([], [], 'everything', 1, [], hFigW);

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

updateButtons();
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
  
  updateImage();
end

%--------------------------------------------------------------------------
function resizeCallback(~, ~)
  updateImage();
end

%--------------------------------------------------------------------------
function menuViewPatterns(~, ~)
  [~, experiment] = viewPatterns(experiment, 'bursts');
end


%--------------------------------------------------------------------------
function patternsBurstDetection(~, ~)
  [groupType, groupIdx] = getCurrentGroup();
  avgTrace = mean(selectedTraces(:, currentOrder),2);
  bursts = obtainPatternBasedBursts(experiment, avgTrace, selectedT);
  
  burstStart = zeros(length(bursts), 1);
  burstFrames = cell(length(bursts), 1);
  
  % Sort bursts
  for i = 1:length(bursts)
      burstFrames{i} = bursts{i}.frames;
      burstT = selectedT(burstFrames{i});
      burstStart(i) = burstT(1);
  end
  [a, idx] = sort(burstStart);
  bursts = bursts(idx);
  

  burstAmplitude = zeros(length(bursts), 1);  
  burstStart = zeros(length(bursts), 1);
  burstFrames = cell(length(bursts), 1);
  for i = 1:length(bursts)
      burstFrames{i} = bursts{i}.frames;
      burstT = selectedT(burstFrames{i});
      burstF = avgTrace(burstFrames{i});
      burstAmplitude(i) = max(burstF);
      burstStart(i) = burstT(1);
      burstDuration(i) = burstT(end)-burstT(1);
      
      % The new duration - until it decays 1/e of the amximum
%       [~, maxP] = max(burstF);
%       maxP = burstFrames{i}(maxP);
% 
%       bs = maxP + 1 - find(avgTrace(maxP:-1:1) <= (0.9)*burstAmplitude(i), 1, 'first');
%       be = maxP - 1 + find(avgTrace(maxP:end) <= (0.3716)*burstAmplitude(i), 1, 'first');
%       if(isempty(bs))
%         bs = 1;
%       end
%       if(isempty(be))
%         be = length(avgTrace);
%       end
%       sprintf('%.2f ', selectedT([maxP, bs, be])')
%       burstFrames{i} = bs:be;
%       burstT = selectedT(burstFrames{i});
%       %burstF = avgTrace(burstFrames{i});
%       burstStart(i) = burstT(1);
%       burstDuration(i) = burstT(end)-burstT(1);
  end
 
  % Fix the starting points so there is no overlap
  for i = 1:(length(bursts)-1)
    if(burstFrames{i}(end) >= burstFrames{i+1}(1))
      %sprintf('%.2f ', [burstStart(i) burstStart(i)+burstDuration(i)])
      %[burstFrames{i}(1) burstFrames{i}(end) burstFrames{i+1}(1) burstFrames{i+1}(end)]
      if(isempty(burstFrames{i}(1):(burstFrames{i+1}(1)-1)))
        continue;
      end
      burstFrames{i} = burstFrames{i}(1):(burstFrames{i+1}(1)-1);
      
      burstT = selectedT(burstFrames{i});
      burstStart(i) = burstT(1);
      burstDuration(i) = burstT(end)-burstT(1);
      %sprintf('%.2f ', [burstStart(i) burstStart(i)+burstDuration(i)])
    end
  end
  
  
  IBI = diff(sort(burstStart));
  burstStructure = struct;
  burstStructure.duration = burstDuration;
  burstStructure.amplitude = burstAmplitude;
  burstStructure.start = burstStart;
  burstStructure.IBI = IBI;
  burstStructure.frames = burstFrames;
  burstStructure.thresholds = [nan nan];
  
  experiment.traceBursts.(groupType){groupIdx} = burstStructure;

  logMsg(sprintf('%d bursts detected', length(burstStructure.start)));
  logMsg(sprintf('%.2f s mean duration', mean(burstStructure.duration)));
  logMsg(sprintf('%.2f mean maximum amplitude', mean(burstStructure.amplitude)));
  logMsg(sprintf('%.2f s mean IBI', mean(burstStructure.IBI)));
  logMsgHeader('Done', 'finish');
  updateImage(true);     
end

%--------------------------------------------------------------------------
function rightClick(hObject, eventData, ~)
  currentOrder = getappdata(hFigW, 'currentOrder');
  if(strcmp(learningMode, 'event') && eventData.Button == 1)
    hFig = ancestor(hObject, 'Figure');
    if(strcmpi(hFig.SelectionType, 'extend'))
      % get top left corner of rectangle
      buttonDown = true;
      rectangleStart = get(gca,'CurrentPoint');
      return;
    end
    clickedPoint = get(hs.mainWindowFramesAxes,'currentpoint');

    [~, closestT] = min(abs(selectedT-clickedPoint(1)));
    eventTraceF = mean(selectedTraces(:, currentOrder),2);
    % Only use part of the trace around closestT
    
    range = round(closestT+[-1, 1]*experiment.burstPatternOptionsCurrent.samplingSize/2*experiment.fps);
    range(1) = max(1, range(1));
    range(2) = min(length(eventTraceF), range(2));
    range = range(1):range(2);
    meanF = mean(eventTraceF(range));
    stdF = std(eventTraceF(range));
    threshold = meanF+stdF*experiment.burstPatternOptionsCurrent.eventLearningThreshold;
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

    if(length(lowerLimit:upperLimit) <= experiment.burstPatternOptionsCurrent.minEventSize*experiment.fps)
      logMsg(sprintf('Event too small at t=%.2f s', selectedT(closestT)), 'w');
      return;
    end
    [groupType, groupIdx] = getCurrentGroup();
    if(~isfield(experiment, 'burstPatterns'))
      experiment.burstPatterns = [];
    end
    if(~isfield(experiment.burstPatterns, groupType))
      experiment.burstPatterns.(groupType) = cell(size(experiment.traceGroups.(groupType)));
    end
    if(length(experiment.burstPatterns.(groupType)) < groupIdx)
      experiment.burstPatterns.(groupType){groupIdx} = [];
    end
    
    eventList = experiment.burstPatterns.(groupType){groupIdx};

    % If the event already exists, delete it
    for i = 1:length(eventList)
      if(~isempty(intersect(eventList{i}.x', (lowerLimit:upperLimit))))
        eventList(i) = [];
        experiment.burstPatterns.(groupType){groupIdx} = eventList;
        updateImage(true);
        updateButtons();
        return;
        % Else, delete it and break (so it is added to the current group)
      end
    end
    % Else, add it
    lastID = lastID + 1;
    eventList{length(eventList)+1}.id = lastID;
    eventList{end}.x = (lowerLimit:upperLimit);
    eventList{end}.y = eventTraceF(lowerLimit:upperLimit);
    eventList{end}.group = 'bursts'; 
    eventList{end}.basePattern = 'bursts';
    eventList{end}.threshold = experiment.burstPatternOptionsCurrent.defaultCorrelationThreshold;
    
    experiment.burstPatterns.(groupType){groupIdx} = eventList;
    updateButtons();
    updateImage(true);
  end
end

%--------------------------------------------------------------------------
function rightClickUp(hObject, eventData, ~)
  if(~buttonDown)
    return;
  end
  if(strcmp(learningMode, 'event'))
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
    
    eventTraceF = mean(selectedTraces(:, currentOrder),2);
    % Only use part of the trace around closestT
    range = frameRange;
    %[~, closestT] = max(eventTraceF(range));
    %closestT = closestT + range(1) - 1;
    closestT = round(mean(range));
    meanF = mean(eventTraceF(range));
    stdF = std(eventTraceF(range));
    threshold = meanF+stdF*experiment.burstPatternOptionsCurrent.eventLearningThreshold;
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

    if(length(lowerLimit:upperLimit) <= experiment.burstPatternOptionsCurrent.minEventSize*experiment.fps)
      logMsg(sprintf('Event too small at t=%.2f s', selectedT(closestT)), 'w');
      return;
    end
    
    [groupType, groupIdx] = getCurrentGroup();
    if(~isfield(experiment, 'burstPatterns'))
      experiment.burstPatterns = [];
    end
    if(~isfield(experiment.burstPatterns, groupType))
      experiment.burstPatterns.(groupType) = cell(size(experiment.traceGroups.(groupType)));
    end
    if(length(experiment.burstPatterns.(groupType)) < groupIdx)
      experiment.burstPatterns.(groupType){groupIdx} = [];
    end
    
    eventList = experiment.burstPatterns.(groupType){groupIdx};
    
    % If the event already exists, delete it
    for i = 1:length(eventList)
      if(~isempty(intersect(eventList{i}.x', (lowerLimit:upperLimit))))
        eventList(i) = [];
        experiment.burstPatterns.(groupType){groupIdx} = eventList;
        updateImage(true);
        updateButtons();
        return;
        % Else, delete it and break (so it is added to the current group)
      end
    end
    % Else, add it
    lastID = lastID + 1;
    eventList{length(eventList)+1}.id = lastID;
    eventList{end}.x = (lowerLimit:upperLimit);
    eventList{end}.y = eventTraceF(lowerLimit:upperLimit);
    eventList{end}.group = 'bursts'; 
    eventList{end}.basePattern = 'bursts';
    eventList{end}.threshold = experiment.burstPatternOptionsCurrent.defaultCorrelationThreshold;
    
    experiment.burstPatterns.(groupType){groupIdx} = eventList;
    updateButtons();
    updateImage(true);
  end
end
  

%--------------------------------------------------------------------------
function buttonMotion(~, ~)
  
  if(strcmp(learningMode, 'event') && ~isempty(buttonDown) && buttonDown)
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
      currentColor = 'r';
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
function eventLengthChange(hObject, ~)
  experiment.burstPatternOptionsCurrent.samplingSize = str2double(hObject.String);
end

%--------------------------------------------------------------------------
function eventMinSizeChange(hObject, ~)
  experiment.burstPatternOptionsCurrent.minEventSize = str2double(hObject.String);
end

%--------------------------------------------------------------------------
function eventThresholdChange(hObject, ~)
  experiment.burstPatternOptionsCurrent.eventLearningThreshold = str2double(hObject.String);
end

%--------------------------------------------------------------------------
function learningFinish(~, ~)
  learningMode = 'none';
  hs.mainWindowLearningPanel.Visible = 'off';
  updateButtons();
  updateImage(true);
end

%--------------------------------------------------------------------------
function burstPatternSelection(~, ~)
  switch learningMode
    case 'none'
      [success, burstPatternOptionsCurrent] = preloadOptions(experiment, burstPatternOptions, gui, true, false);
      if(~success)
        return;
      end
      experiment.burstPatternOptionsCurrent = burstPatternOptionsCurrent;
      learningMode = 'event';
      hs.eventButtonLengthEdit.String = num2str(burstPatternOptionsCurrent.samplingSize);
      hs.eventButtonSizeEdit.String = num2str(burstPatternOptionsCurrent.minEventSize);
      hs.eventButtonThresholdEdit.String = num2str(burstPatternOptionsCurrent.eventLearningThreshold);
          hs.mainWindowLearningPanel.Visible = 'on';
    case 'event'
      learningMode = 'none';
      hs.mainWindowLearningPanel.Visible = 'off';
  end
  updateButtons();
  updateImage();
   
 %experiment.traceBursts.(groupType){groupIdx} = burstStructure;
        %[field, idx] = getExperimentGroupCoordinates(experiment, name)
end

%--------------------------------------------------------------------------
function burstDetectionButton(~, ~)
  [groupType, groupIdx] = getCurrentGroup();
  curName = getExperimentGroupsNames(experiment, groupType, groupIdx);
  oldGroup = experiment.burstDetectionOptionsCurrent.group;
  experiment.burstDetectionOptionsCurrent.group = {curName{:}, ''};
  
  [success, burstDetectionOptionsCurrent, experiment] = preloadOptions(experiment, burstDetectionOptions, gui, true, false);
  if(success)
    experiment.burstDetectionOptionsCurrent = burstDetectionOptionsCurrent;
    experiment = burstDetection(experiment, burstDetectionOptionsCurrent);
    updateImage(true);
  else
    experiment.burstDetectionOptionsCurrent.group = oldGroup;
  end
end

%--------------------------------------------------------------------------
function exportTraces(~, ~)
    exportFigCallback([], [], {'*.png';'*.tiff'}, [experiment.folder 'bursts_' selectionTitle]);
end

%--------------------------------------------------------------------------
function closeCallback(~, ~, varargin)
  % Since the bigFields might have been loaded (but shouldn't have changed), let's reassign them
  bigFields = {'rawTraces', 'traces', 'baseLine', 'modelTraces', 'denoisedData', 'rawTracesDenoised'};
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
function burstStatistics(~, ~, ~)
  currentOrder = getappdata(hFigW, 'currentOrder');
  [groupType, groupIdx] = getCurrentGroup();
  if(isempty(groupType) || isempty(groupIdx))
    return;
  end
  selectionTitle = getExperimentGroupsNames(experiment,groupType, groupIdx);
  selectionTitle = strrep(selectionTitle{1}, ': ', '-');
  
  if(isfield(experiment, 'traceBursts') && isfield(experiment.traceBursts, groupType) && numel(experiment.traceBursts.(groupType)) >= groupIdx)
    bursts = experiment.traceBursts.(groupType){groupIdx};
  else
    bursts = [];
  end
  
  if(isempty(bursts) || ~isfield(bursts, 'frames') || isempty(bursts.duration))
    logMsg('No bursts found', 'e');
    return;
  end
  
    hFig = figure('Position', [200 200 650 220]);
    ax = multigap_subplot(1, 3, 'margin_LR', [0.1 0.1], 'gap_C', 0.07, 'margin_TB', 0.15);
    
    %h = subplot(1, 3, 1);
    h = ax(1);
    axes(h);
    nbins = sshist(bursts.IBI);
    if(nbins < 6)
      nbins = 10;
    end
    [a, b] = hist(h, bursts.IBI, nbins);
    bar(b, a/trapz(b, a), 'FaceColor', [1 1 1]*0.8, 'EdgeColor', [1 1 1]*0.6);
    hold on;
    [f, xi] = ksdensity(bursts.IBI); % Not using support
    valid = find(xi > 0);
    hk = plot(xi(valid), f(valid), 'LineWidth', 2);
    hx = xlabel(h, 'IBI (s)');
    %hx.Units = 'normalized';
    ylabel(h, 'PDF');
    legend(hk, sprintf('<>= %.2f s', mean(bursts.IBI)));
    legend('boxoff');
    
    %h = subplot(1, 3, 2);
    h = ax(2);
    axes(h);
    nbins = sshist(bursts.duration);
    if(nbins < 6)
      nbins = 10;
    end
    [a, b] = hist(h, bursts.duration, nbins);
    bar(b, a/trapz(b, a), 'FaceColor', [1 1 1]*0.8, 'EdgeColor', [1 1 1]*0.6);
    hold on;
    [f, xi] = ksdensity(bursts.duration);
    valid = find(xi > 0);
    hk = plot(xi(valid), f(valid), 'LineWidth', 2);
    xlabel(h, 'Burst duration (s)');
    ylabel(h, 'PDF');
    hold on;
    legend(hk, sprintf('<>= %.2f s', mean(bursts.duration)));
    legend('boxoff');
    
    %h = subplot(1, 3, 3);
    h = ax(3);
    axes(h);
    nbins = sshist(bursts.amplitude);
    if(nbins < 6)
      nbins = 10;
    end
    [a, b] = hist(h, bursts.amplitude, nbins);
    bar(b, a/trapz(b, a), 'FaceColor', [1 1 1]*0.8, 'EdgeColor', [1 1 1]*0.6);
    hold on;
    [f, xi] = ksdensity(bursts.amplitude);
    valid = find(xi > 0);
    hk = plot(xi(valid), f(valid), 'LineWidth', 2);
    hxf = xlabel(h, 'Burst amplitude (au)');
    %hxf.Units = 'normalized';
    ylabel(h, 'PDF');
    legend(hk, sprintf('<>= %.2f au', mean(bursts.amplitude)));
    legend('boxoff');
    %hxf.Position(2) = hx.Position(2);
    
    %suptitle(['Burst statistics for population: ' selectionTitle]);
    mtit(hFig, ['Burst statistics for: ' selectionTitle], 'yoff', 0.05);
    
    uimenu(hFig, 'Label', 'Export',  'Callback', {@exportFigCallback, {'*.png';'*.tiff'}, [experiment.folder 'burstStatistics_' selectionTitle]});
    
end

%% Utility functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------------------------------------------------------------
function updateMenus()
    
end

%--------------------------------------------------------------------------
function updateImage(varargin)
  if(nargin < 1)
    keepAxis = false;
  else
    keepAxis = varargin{1};
  end
  if(keepAxis)
    oldXL = hs.mainWindowFramesAxes.XLim;
    oldYL = hs.mainWindowFramesAxes.YLim;
  end
  currentOrder = getappdata(hFigW, 'currentOrder');
  [groupType, groupIdx] = getCurrentGroup();
  if(isempty(groupType) || isempty(groupIdx))
    return;
  end
  selectionTitle = getExperimentGroupsNames(experiment,groupType, groupIdx);
  selectionTitle = strrep(selectionTitle{1}, ': ', '-');
  
  if(isfield(experiment, 'traceBursts') && isfield(experiment.traceBursts, groupType) && numel(experiment.traceBursts.(groupType)) >= groupIdx)
    bursts = experiment.traceBursts.(groupType){groupIdx};
  else
    bursts = [];
  end
  axes(hs.mainWindowFramesAxes);
  cla(hs.mainWindowFramesAxes);
  set(hs.mainWindowFramesAxes, 'ButtonDownFcn', @rightClick);
  cmap = parula(10);
  set(hs.mainWindowFramesAxes, 'ColorOrder', cmap);
  axis tight;
  avgTrace = mean(selectedTraces(:, currentOrder),2);
  switch learningMode
    case 'none'
      h = plot(selectedT, avgTrace);
      h.ButtonDownFcn = @rightClick;
      if(~isempty(bursts) && isfield(bursts, 'frames') && ~isempty(bursts.frames))
        hold on;
        frames = bursts.frames;
        for i = 1:length(frames)
          plot(selectedT(frames{i}), avgTrace(frames{i}), 'LineWidth', 2);
        end
        burstThresholdLower = bursts.thresholds(1);
        burstThresholdUpper = bursts.thresholds(2);
      
      if(length(varargin) >= 1 && varargin{1} == true)
        if(strcmp(detectionType, 'schmitt') && isfield(experiment.burstPatternOptionsCurrent, 'schmittThresholdType'))
          switch experiment.burstPatternOptionsCurrent.schmittThresholdType
            case 'relative'
              if(~isnan(burstThresholdUpper))
                avgMean = mean(avgTrace);
                avgStd = std(avgTrace);
                xl = xlim;
                plot(xl, [1,1]*(avgMean+burstThresholdUpper*avgStd), 'r--');
                plot(xl, [1,1]*(avgMean+burstThresholdLower*avgStd), 'b--');
              end
            case 'absolute'
              xl = xlim;
              plot(xl, [1,1]*(burstThresholdUpper), 'r--');
              plot(xl, [1,1]*(burstThresholdLower), 'b--');
          end
        end
      end
    end
    case 'event'
      h = plot(selectedT, avgTrace, 'k');
      h.ButtonDownFcn = @rightClick;
      hold on;
      % Event based
      if(isfield(experiment, 'burstPatterns') && isfield(experiment.burstPatterns, groupType) && length(experiment.burstPatterns.(groupType)) >= groupIdx)
        eventList = experiment.burstPatterns.(groupType){groupIdx};
        for j = 1:length(eventList)
          plot(hs.mainWindowFramesAxes, selectedT(eventList{j}.x), avgTrace(eventList{j}.x),'-', 'Color', 'r');
        end
      end
  end
  
  xlim([selectedT(1) selectedT(end)]);
  
  if(keepAxis)
    xlim(oldXL);
    ylim(oldYL);
  end
  
  xlabel('time (s)');
  ylabel('average fluorescence (a.u.)');
  title(['Average fluorescence trace (' selectionTitle ')']);

%  ylabel('Fluoresence (a.u.)');
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

%--------------------------------------------------------------------------
function updateButtons()
  [groupType, groupIdx] = getCurrentGroup();
  if(~isfield(experiment, 'burstPatterns'))
    experiment.burstPatterns = [];
  end
  if(~isfield(experiment.burstPatterns, groupType))
    experiment.burstPatterns.(groupType) = cell(size(experiment.traceGroupsNames.(groupType)));
  end
  if(length(experiment.burstPatterns.(groupType)) < groupIdx)
    experiment.burstPatterns.(groupType){groupIdx} = [];
  end
  hs.mainWindowLearningGroupSelectionNtraces.String = sprintf('%d bursts assigned', length(experiment.burstPatterns.(groupType){groupIdx}));
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

end
