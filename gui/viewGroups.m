function [hFigW, experiment] = viewGroups(experiment)
% VIEWGROUPS shows the groups of a given experiment
%
% USAGE:
%    [hFigW, experiment] = viewGroups(experiment)
%
% INPUT arguments:
%    experiment - experiment structure from loadExperiment
%
% OUTPUT arguments:
%    hFigW - figure handle
%
%    experiment - experiment structure from loadExperiment
%
% EXAMPLE:
%    [hFigW, experiment] = viewGroups(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also loadExperiment

%#ok<*AGROW>
%#ok<*ASGLU>
%#ok<*FXUP>

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
headerFontSize = 12;
minGridBorder = 1;
populationsOverlay = [];
framePopulationsColor =[];
populationsPixels = [];
legendText = {};
showPopulations = false;
showLegend = true;
ROIid = getROIid(experiment.ROI);
realSize = false;
avgImg = experiment.avgImg;
bpp = experiment.bpp;
import uiextras.jTree.*;

fieldList = {'traceGroups', 'traceGroupsNames', 'traceGroupsOrder', 'traceBursts'}; % To be completed, but only first 2 should really be relevant
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Create components
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
hs.mainWindow = figure('Visible','off',...
                       'Resize','on',...
                       'Toolbar', 'figure',...
                       'Tag','viewGroups', ...
                       'NumberTitle', 'off',...
                       'MenuBar', 'none',...
                       'DockControls','off',...
                       'Name', ['Group viewer: ' experiment.name],...
                       'SizeChangedFcn', @mainWindowResize,...
                       'CloseRequestFcn', @closeCallback);
hFigW = hs.mainWindow;
hFigW.Position = setFigurePosition(gui, 'width', 1000, 'height', 600);
if(~isempty(gui))
  setappdata(hFigW, 'logHandle', getappdata(gcbf, 'logHandle'));
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Create components
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% The menu
hs.menu.file.root = uimenu(hs.mainWindow, 'Label', 'File');
uimenu(hs.menu.file.root, 'Label', 'Exit and discard changes', 'Callback', {@closeCallback, false});
uimenu(hs.menu.file.root, 'Label', 'Exit and save changes', 'Callback', {@closeCallback, true});
uimenu(hs.menu.file.root, 'Label', 'Exit (default)', 'Callback', @closeCallback);


hs.menuPreferences = uimenu(hs.mainWindow, 'Label', 'Preferences');
hs.menuPreferencesRealSize = uimenu(hs.menuPreferences, 'Label', 'Real Size', 'Enable', 'on', 'Callback', @menuPreferencesRealSize);
hs.menuPreferencesShowLegend = uimenu(hs.menuPreferences, 'Label', 'Show Legend', 'Enable', 'on', 'Checked', 'on', 'Callback', @menuPreferencesShowLegend);

hs.menu.stats.root = uimenu(hs.mainWindow, 'Label', 'Statistics');
hs.menu.stats.nn = uimenu(hs.menu.stats.root, 'Label', 'Aggregation level', 'Callback', @statsNearestNeighbor);

hs.menu.groups.root = uimenu(hs.mainWindow, 'Label', 'Groups');
hs.menu.groups.export = uimenu(hs.menu.groups.root, 'Label', 'Export', 'Callback', @exportGroups);
hs.menu.groups.import = uimenu(hs.menu.groups.root, 'Label', 'Import from file', 'Callback', {@importGroups, 'file'});
hs.menu.groups.importProject = uimenu(hs.menu.groups.root, 'Label', 'Import from another experiment', 'Callback', {@importGroups, 'project'});

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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% COLUMN START
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Groups column
uix.Empty('Parent', hs.mainWindowGrid);

hs.groupPanel = uix.Panel('Parent', hs.mainWindowGrid, ...
                               'BorderType', 'none', 'FontSize', textFontSize, ...
                               'Title', 'Groups list');
                             

uix.Empty('Parent', hs.mainWindowGrid);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% COLUMN START
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
uix.Empty('Parent', hs.mainWindowGrid);
% Frames panel
hs.mainWindowFramesPanel = uix.Panel('Parent', hs.mainWindowGrid, 'Padding', 5, 'BorderType', 'none');
hs.mainWindowFramesAxes = axes('Parent', hs.mainWindowFramesPanel);
currFrame = avgImg;

imData = imagesc(currFrame);
axis equal tight;
maxIntensity = max(currFrame(:));
minIntensity = min(currFrame(:));
set(hs.mainWindowFramesAxes, 'XTick', []);
set(hs.mainWindowFramesAxes, 'YTick', []);
set(hs.mainWindowFramesAxes, 'LooseInset', [0,0,0,0]);
box on;
hold on;
overlayData = imagesc(ones(size(currFrame)), 'HitTest', 'off');

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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% COLUMN START
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
uix.Empty('Parent', hs.mainWindowGrid);

% Right buttons
hs.mainWindowRightButtons = uix.VBox('Parent', hs.mainWindowGrid);


b = uix.HBox( 'Parent', hs.mainWindowRightButtons);
maxIntensityText = uicontrol('Parent', b, 'Style','edit',...
          'String', num2str(maxIntensity), 'FontSize', textFontSize, 'HorizontalAlignment', 'left', 'callback', @maxIntensityChange);
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
uicontrol('Parent', hs.mainWindowRightButtons, 'String', 'Shuffle colors', 'FontSize', textFontSize, 'Callback', @shuffleColors);
uicontrol('Parent', hs.mainWindowRightButtons, 'String', 'Reset image', 'FontSize', textFontSize, 'Callback', @resetImage);

uix.Empty('Parent', hs.mainWindowRightButtons);

b = uix.HBox( 'Parent', hs.mainWindowRightButtons);
minIntensityText = uicontrol('Parent', b, 'Style','edit',...
          'String', num2str(minIntensity), 'FontSize', textFontSize, 'HorizontalAlignment', 'left', 'callback', @minIntensityChange);
uicontrol('Parent', b, 'Style','text', 'String', 'Minimum', 'FontSize', textFontSize, 'HorizontalAlignment', 'left');
set(b, 'Widths', [30 -1], 'Spacing', 5, 'Padding', 0);

set(hs.mainWindowRightButtons, 'Heights', [20 -1 100 25 25 25 -1 20], 'Padding', 5);

% Below right buttons
uix.Empty('Parent', hs.mainWindowGrid);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% COLUMN START
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Empty right
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

groupTree = [];
% Prepare the multiple experiment panel
groupTreeContextMenu = [];
groupTreeContextMenuRoot = [];

colormap(gray);

set(hs.mainWindowGrid, 'Widths', [minGridBorder 200 -1 25 200 minGridBorder], ...
    'Heights', [minGridBorder -1 minGridBorder]);
%set(hs.mainWindowGrid, 'Widths', [size(currFrame,2) 25 -1], 'Heights', [size(currFrame,1) -1]);
cleanMenu();

mainWindowResize(gcbo);
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
% Righ click menu
hs.rightClickMenu.root = uicontextmenu;
hs.mainWindowFramesAxes.UIContextMenu = hs.rightClickMenu.root;
hs.rightClickMenu.showTraceRaw = uimenu(hs.rightClickMenu.root, 'Label','Show neuron raw trace', 'Callback', {@rightClickPlotNeuronTrace, 'raw'});
hs.rightClickMenu.showTraceSmoothed = uimenu(hs.rightClickMenu.root, 'Label','Show neuron smoothed trace', 'Callback', {@rightClickPlotNeuronTrace, 'smoothed'});
if(~isfield(experiment, 'traces'))
  hs.rightClickMenu.showTraceRaw.Enable = 'off';
  hs.rightClickMenu.showTraceSmoothed.Enable = 'off';
end

updateGroupTree();

mainWindowResize();

if(isempty(gui))
  waitfor(hFigW);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Callbacks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function mainWindowResize(~, ~)
    set(hs.mainWindowGrid, 'Widths', [minGridBorder 200 -1 25 200 minGridBorder], ...
        'Heights', [minGridBorder -1 minGridBorder]);
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
        
        minWidth = curPos(3) + 200 + 25 + 200 + minGridBorder*2;
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
        set(hs.mainWindowGrid, 'Widths', [-1 200 curPos(4)*realRatio 25 200 -1], ...
            'Heights', [-1 curPos(4) -1]);
    else
        set(hs.mainWindowGrid, 'Widths', [-1 200 curPos(3) 25 200 -1], ...
           'Heights', [-1 curPos(3)/realRatio -1]);
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
    colormap(newmap);
end

% ImageJ old auto version
%--------------------------------------------------------------------------
function autoLevels(~, ~)
  [minIntensity, maxIntensity] = autoLevelsFIJI(currFrame, bpp);
  maxIntensityText.String = sprintf('%.2f', maxIntensity);
  minIntensityText.String = sprintf('%.2f', minIntensity);
  updateImage();
end

%--------------------------------------------------------------------------
function shuffleColors(~, ~)
  
  cmap = rand(length(framePopulationsColor), 3);
  
  for i = 1:length(framePopulationsColor)  
    framePopulationsColor{i} = cmap(i, :);
  end
  updateImage();
end

%--------------------------------------------------------------------------
function resetImage(~, ~)
  currFrame = experiment.avgImg;
  bpp = experiment.bpp;
  maxIntensity = max(currFrame(:));
  minIntensity = min(currFrame(:));
  maxIntensityText.String = sprintf('%.2f', maxIntensity);
  minIntensityText.String = sprintf('%.2f', minIntensity);
  updateImage();
end
%--------------------------------------------------------------------------
function menuPreferencesShowLegend(hObject, ~)
  showLegend = ~showLegend;
  updateImage();
  if(showLegend)
    hObject.Checked = 'on';
  else
    hObject.Checked = 'off';
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
function maxIntensityChange(hObject, ~)
    input = str2double(get(hObject,'string'));
    if isnan(input)
        errordlg('You must enter a numeric value','Invalid Input','modal')
        uicontrol(hObject)
    return
    else
        if(input <= minIntensity)
            errordlg('Maximum intensity has to be greater than minimum intensity','Invalid Input','modal');
            uicontrol(hObject);
        else
            maxIntensity = input;
            updateImage();
        end
    end
end

%--------------------------------------------------------------------------
function minIntensityChange(hObject, ~)
    input = str2double(get(hObject,'string'));
    if isnan(input)
        errordlg('You must enter a numeric value','Invalid Input','modal')
        uicontrol(hObject)
    return
    else
        if(input >= maxIntensity)
            errordlg('Maximum intensity has to be greater than minimum intensity','Invalid Input','modal');
            uicontrol(hObject);
        else
            minIntensity = input;
            updateImage();
        end
    end
end

%--------------------------------------------------------------------------
function closeCallback(~, ~, varargin)
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
function statsNearestNeighbor(~, ~)
  % Define the options
  optionsClass = groupsStatisticsOptions;
  if(~isempty(optionsClass))
    [success, optionsClassCurrent] = preloadOptions(experiment, optionsClass, gui, true, false);
    if(~success)
      return;
    end
  end
  groupsStatisticsOptionsCurrent = optionsClassCurrent;
  experiment.groupsStatisticsOptionsCurrent = groupsStatisticsOptionsCurrent;
  groupNames = getExperimentGroupsNames(experiment);
  [selectedPopulations, success] = listdlg('PromptString', 'Select groups', 'SelectionMode', 'multiple', 'ListString', groupNames);
  if(~success)
    return;
  end
  selectedPopulations = groupNames(selectedPopulations);
  Npopulations = length(selectedPopulations);
  
  fullStatCell = cell(Npopulations, 1);
  pVals = cell(Npopulations, 1);
  for it2 = 1:Npopulations
    % Here we will call the function with the subset
    [experiment, stats] = computeNearestNeighborStatistics(experiment, selectedPopulations{it2});
    switch groupsStatisticsOptionsCurrent.nearestNeighborMeasure
      case 'absolute'
        fullStatCell{it2} = stats.listNNdist(:);
      case 'relative'
        fullStatCell{it2} = stats.listNNdist(:)-stats.randMeanNNdist;
    end
    pVals{it2} = stats.pValRandNNdist;
  end
  
  % Now the plot
  hfig = figure;
  ax = axes('Parent',hfig);
  currentColormap = eval(['@' groupsStatisticsOptionsCurrent.colormap]);
  cmap = currentColormap(Npopulations+1);
  cmap = cmap(2:end, :);
  hold on;
  lh = [];

  pc = fullStatCell;
  switch groupsStatisticsOptionsCurrent.distributionType
    case 'violin'
      edgeCol = cmap*1.1;
      edgeCol(edgeCol>1) = 1;
      [h, L] = violin(pc', 'facecolor', cmap, 'edgecolor', 'k', 'facealpha', 0.2, 'medc', []);
      lh = [lh; h(1)];
    case 'boxplot'
      rowData = [];
      groupData = [];
      for kr = 1:Npopulations
        if(isempty(pc{kr}))
          rowData = [rowData; NaN];
          groupData = [groupData; kr];
        else
          rowData = [rowData; pc{kr}];
          groupData = [groupData; ones(size(pc{kr}))*kr];
        end
      end
      h = boxplot(rowData, groupData); 
      lh = [lh; h];
    case 'notboxplot'
      rowData = [];
      groupData = [];
      for kr = 1:Npopulations
        if(isempty(pc{kr}))
          rowData = [rowData; NaN];
          groupData = [groupData; kr];
        else
          rowData = [rowData; pc{kr}];
          groupData = [groupData; ones(size(pc{kr}))*kr];
        end
      end
      h = notBoxPlotv2(rowData, groupData);
      lh = [lh; h];
    case 'univarscatter'
      rowData = [];
      groupData = [];
      for kr = 1:Npopulations
        if(isempty(pc{kr}))
          rowData = [rowData; NaN];
          groupData = [groupData; kr];
        else
          rowData = [rowData; pc{kr}];
          groupData = [groupData; ones(size(pc{kr}))*kr];
        end
      end
      c = table(rowData(:), arrayfun(@(x){num2str(x)}, groupData(:)));
      edgeCol = cmap*1.3;
      edgeCol(edgeCol>1) = 1;
      UnivarScatter(c, 'MarkerFaceColor',cmap,'SEMColor', edgeCol,'StdColor',edgeCol/2, 'PointStyle', '.');

      %lh = [lh; h];
  end
  switch groupsStatisticsOptionsCurrent.showAboveBars
    case 'stars'
      for k = 1:Npopulations
        if(pVals{k} > 0.05)
          stars = 'n.s.';
        elseif(pVals{k} > 0.01)
          stars = '*';
        elseif(pVals{k} > 0.001)
          stars = '**';
        elseif(pVals{k} > 0.001)
          stars = '***';
        else
          stars = '****';
        end
        text(k, max(fullStatCell{k})*1.05, stars,...
            'HorizontalAlignment','center',...
            'VerticalAlignment','bottom', 'FontSize', 12);
      end
    case 'pvalue'
      for k = 1:Npopulations
        text(k, max(fullStatCell{k})*1.05, sprintf('p=%.2e', pVals{k}),...
              'HorizontalAlignment','center',...
              'VerticalAlignment','bottom', 'FontSize', 12);
      end
    case 'none'
  end
  legend('off');
  xlim(ax, [0.5 Npopulations+0.5]);
  yl = ylim(ax);
  ylim(ax, [yl(1) yl(2)*1.15]);
  ui = uimenu(hfig, 'Label', 'Export');
  switch groupsStatisticsOptionsCurrent.nearestNeighborMeasure
    case 'absolute'
      ylabel(ax, 'Nearest Neighbor distance (pixels)');
    case 'relative'
      ylabel(ax, 'Relative nearest Neighbor distance (pixels)');
      hold on;
      xl = xlim;
      plot(xl, [0 0], 'k--');
  end
  title(ax,['Nearest neighbor distances : ' experiment.name]);
  figNameShortcut = 'nnDistances';
  uimenu(ui, 'Label', 'Image',  'Callback', {@exportFigCallback, {'*.png'; '*.tiff'; '*.pdf'; '*.eps'}, [experiment.folder figNameShortcut]});
  uimenu(ui, 'Label', 'Data', 'Callback', {@exportDataCallback, {'*.xlsx'}, ...
          [experiment.folder 'Data' figNameShortcut], ...
          fullStatCell, ...
          strrep(selectedPopulations,'_','\_')', ...
          figNameShortcut});
  
  set(ax, 'XTick', 1:Npopulations);
  set(gca, 'XTickLabel', strrep(selectedPopulations,'_','\_'));
  set(gca, 'XTickLabelRotation', groupsStatisticsOptionsCurrent.xLabelsRotation);
  box on;
  setappdata(gui, 'groupsStatisticsOptionsCurrent', groupsStatisticsOptionsCurrent);
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
      [selection, ok] = listdlg('PromptString', 'Select experiment to import from', 'ListString', namesWithLabels([], gui), 'SelectionMode', 'single');
      if(~ok)
        return;
      end
      experimentFile = [project.folderFiles project.experiments{selection} '.exp'];
      newExperiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
      groupsStruct = newExperiment;
  end
  [selectedPopulations, groupsStruct] = treeGroupsSelection(groupsStruct, 'Select groups to import', true, true);
  if(isempty(groupsStruct))
    return;
  end
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
          tmpExperiment.traceGroups.(namesGroups{it2}) = {};
        end
        if(~isfield(tmpExperiment.traceGroupsNames, namesGroups{it2}))
          tmpExperiment.traceGroupsNames.(namesGroups{it2}) = {};
        end
        tmpExperiment.traceGroups.(namesGroups{it2}){end+1} = groupsStruct.traceGroups.(namesGroups{it2}){it3};
        tmpExperiment.traceGroupsNames.(namesGroups{it2}){end+1} = groupsStruct.traceGroupsNames.(namesGroups{it2}){it3};
      end
    end
  end
  logMsg('Groups successfully imported');
  experiment = tmpExperiment;
  updateGroupTree();
  
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Utility functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------------------------------------------------------------
function [experiment, stats] = computeNearestNeighborStatistics(experiment, pop)
  [field, idx] = getExperimentGroupCoordinates(experiment, pop);
  
  experiment = checkROIconsistency(experiment);
  subset = getExperimentGroupMembers(experiment, pop);
  % Get the available region (range between min and max centers)
  minX = inf;
  maxX = -inf;
  minY = inf;
  maxY = -inf;
  for i = 1:length(experiment.ROI)
    minX = min(minX, experiment.ROI{i}.center(1));
    maxX = max(maxX, experiment.ROI{i}.center(1));
    minY = min(minY, experiment.ROI{i}.center(2));
    maxY = max(maxY, experiment.ROI{i}.center(2));
  end
  distX = maxX-minX;
  distY = maxY-minY;
  
  distList = zeros(length(subset), 2);
  for i = 1:length(subset)
    distList(i, :) = experiment.ROI{subset(i)}.center;
  end
  allDist = squareform(pdist(distList, 'euclidean'));
  allDist(1:length(allDist)+1:end) = NaN;
  minDist = min(allDist);
  density = length(subset)/distX/distY; % Number of elements per unit pixel
  minDistRandom = 0.5*sqrt(1/density);
  
  %[h,p] = ztest(minDist, minDistRandom, minDistRandom, 'Alpha', 0.05);
  %[h,p] = ztest(minDist, minDistRandom, minDistRandom, 'Alpha', 0.05);
  %[h,p] = ztest(minDist, minDistRandom, minDistRandom/2, 'Alpha', 0.05);
  [h,p] = ttest(minDist-minDistRandom);
  %[mean(minDist)-minDistRandom 1.96*std(minDist)/sqrt(length(subset))]
  %[mean(minDist) minDistRandom std(minDist)]
  stats = struct;
  stats.N = length(subset);
  stats.density = density;
  stats.meanNNdist = mean(minDist);
  stats.stdNNdist = std(minDist);
  stats.randMeanNNdist = minDistRandom;
  stats.rejRandNNdist = h;
  stats.pValRandNNdist = p;
  stats.listNNdist = minDist;
  experiment.traceGroupsNNStats.(field){idx} = stats;
end

%--------------------------------------------------------------------------
function experiment = checkROIconsistency(experiment)
  ROI = experiment.ROI;
  for idx = 1:length(ROI)
    [yb, xb] = ind2sub(size(experiment.avgImg), ROI{idx}.pixels(:));
    ROI{idx}.center = [mean(xb), mean(yb)];
    ROI{idx}.maxDistance = max(sqrt((ROI{idx}.center(1)-xb).^2+(ROI{idx}.center(2)-yb).^2));
  end
  experiment.ROI = ROI;
end

%--------------------------------------------------------------------------
function updateImage()
  set(imData, 'CData', currFrame);
   
  caxis([minIntensity maxIntensity]);
  
  plotPopulations();
  
  if(showLegend && ~isempty(legendText))
    delete(overlayData);
    axes(hs.mainWindowFramesAxes);
    overlayData = imagesc(zeros([experiment.height experiment.width 3]), 'HitTest', 'off');
  
    validText = {};
    validColor = [];
    validPosition = [];
    for i = 1:length(legendText)
      if(~isempty(legendText{i}))
        validText{end+1} = legendText{i};
        validColor = [validColor; framePopulationsColor{i}];
        validPosition = [validPosition; 5, 1+size(validPosition,1)*44];
      end
    end
    if(~isempty(validText))
      %ar = rgb2gray(insertText(zeros(size(currFrame)), validPosition, validText', 'TextColor', validColor, 'BoxColor', 'black', 'FontSize', 32));
      ar = insertText(zeros(size(currFrame)), validPosition, validText', 'TextColor', validColor, 'BoxColor', 'white', 'FontSize', 24, 'BoxOpacity', 0.1);
      set(overlayData, 'CData', ar);
      %set(overlayData, 'CData', double(maxIntensity)*ones(size(currFrame)));
      set(overlayData, 'AlphaData', ~~rgb2gray(ar));
    else
      set(overlayData, 'CData', double(maxIntensity)*ones(size(currFrame)));
      set(overlayData, 'AlphaData', zeros(size(currFrame)));
    end
  else
    set(overlayData, 'CData', double(maxIntensity)*ones(size(currFrame)));
    set(overlayData, 'AlphaData', zeros(size(currFrame)));
  end
end

%--------------------------------------------------------------------------
function plotPopulations()
  if(~isempty(populationsOverlay))
    delete(populationsOverlay);
  end
  if(~showPopulations)
    return;
  end
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
    overlayFrameR(populationsPixels{curIdx}) = overlayFrameR(populationsPixels{curIdx})+framePopulationsColor{curIdx}(1);
    overlayFrameG(populationsPixels{curIdx}) = overlayFrameG(populationsPixels{curIdx})+framePopulationsColor{curIdx}(2);
    overlayFrameB(populationsPixels{curIdx}) = overlayFrameB(populationsPixels{curIdx})+framePopulationsColor{curIdx}(3);
  end
  %legend(legendNames);
  % Set alpha = 1 only for perimeters
  overlayFrameP = ~~overlayFrameA;
  overlayFrameP = bwperim(overlayFrameP,4);
  overlayFrameA(overlayFrameP) = 1;
  overlayFrameR(overlayFrameR > 1) = 1;
  overlayFrameG(overlayFrameG > 1) = 1;
  overlayFrameB(overlayFrameB > 1) = 1;

  set(populationsOverlay, 'CData', cat(3, overlayFrameR, overlayFrameG, overlayFrameB));
  set(populationsOverlay, 'AlphaData', overlayFrameA);
end


%--------------------------------------------------------------------------
function plotSingleNeuronTrace(clickedPoint, type)
  [experiment, success] = loadTraces(experiment, 'all');
  if(~success)
    return;
  end
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
function updateShowGroups(groupNames)
  
  showPopulations = false;
  framePopulationsColor = {};
  populationsPixels = {};
  legendText = {};
  if(length(groupNames) > 7)
    cmap = rand(length(groupNames), 3);
  else
    cmap = lines(length(groupNames));
  end
  for curIdx = 1:length(groupNames)
    populationsType = strsplit(groupNames{curIdx}, ': ');
    if(~isfield(experiment.traceGroups, populationsType{1}))
      logMsg(['No populations found for: ' groupNames{curIdx}], 'w');
      continue;
    end
    subgroupNames = experiment.traceGroupsNames.(populationsType{1});
    if(length(populationsType) > 1)
      groupIdx = find(strcmp(populationsType{2}, subgroupNames));
    else
      groupIdx = 1;
    end
    if(isempty(groupIdx) || length(groupIdx) > 1)
      logMsg(['No populations found for: ' subgroupNames{curIdx}], 'w');
    end
    
    members = experiment.traceGroups.(populationsType{1}){groupIdx};
    
    framePopulationsColor{end+1} = cmap(curIdx, :);
    % Get the mask
    validPixels = [];
    for i = 1:length(members)
      validPixels = [validPixels; experiment.ROI{members(i)}.pixels(:)];
    end
    validPixels = unique(validPixels);
    populationsPixels{end+1} = validPixels;
    %legendText{end+1} = [populationsType{1} ': ' experiment.traceGroupsNames.(populationsType{1}){groupIdx}];
    legendText{end+1} = groupNames{curIdx};
    showPopulations = true;
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

%--------------------------------------------------------------------------
function updateGroupTree(~, ~)
  import uiextras.jTree.*;
  
  if(~isempty(groupTree))
    if(isprop(groupTree, 'Root'))
      delete(groupTree.Root)
    end
    delete(groupTree)
  end
   if(~isempty(groupTreeContextMenu))
    delete(groupTreeContextMenu)
  end
  if(~isempty(groupTreeContextMenuRoot))
    delete(groupTreeContextMenuRoot)
  end
  
  groupTree = uiextras.jTree.CheckboxTree('Parent', hs.groupPanel, 'RootVisible', false);
  % Even tho it does nothing
  if(isunix && ~ismac)
    groupTree.FontName = 'Bitstream Vera Sans Mono';
  else
    groupTree.FontName = 'Courier New';
  end
  Icon1 = fullfile(matlabroot,'toolbox','matlab','icons','foldericon.gif');
  groups = experiment.traceGroupsNames;
  groupNames = fieldnames(groups);
  
  % Create the context menus
  groupTreeContextMenu = uicontextmenu('Parent', hFigW);
  %uimenu(groupTreeContextMenu, 'Label', 'Move up (UNFINISHED)', 'Callback', {@moveMethod, groupTree, 'up'});
  %uimenu(groupTreeContextMenu, 'Label', 'Move down (UNFINISHED)', 'Callback', {@moveMethod, groupTree, 'down'});
  %uimenu(groupTreeContextMenu, 'Label', 'Move X positions (UNFINISHED)', 'Callback', {@moveMethod, groupTree, 'x'});
  uimenu(groupTreeContextMenu, 'Label', 'Rename', 'Callback', {@renameMethod, groupTree});
  %uimenu(groupTreeContextMenu, 'Label', 'Clone (UNFINISHED)', 'Callback', {@cloneMethod, groupTree});
  uimenu(groupTreeContextMenu, 'Label', 'Delete', 'Callback', {@deleteMethod, groupTree}, 'Separator', 'on');
  
  groupTreeContextMenuRoot = uicontextmenu('Parent', hFigW);
  uimenu(groupTreeContextMenuRoot, 'Label', 'Sort by name', 'Callback', {@sortMethod, groupTree, 'name'});
  uimenu(groupTreeContextMenuRoot, 'Label', 'Sort by name (inverse)', 'Callback', {@sortMethod, groupTree, 'nameInverse'});

  uimenu(groupTreeContextMenuRoot, 'Label', 'Check all', 'Separator', 'on', 'Callback', {@selectMethod, groupTree, 'all'});
  uimenu(groupTreeContextMenuRoot, 'Label', 'Check none', 'Callback', {@selectMethod, groupTree, 'none'});
  groupTree.Editable = true;
  groupTree.SelectionType = 'discontiguous';
  
  % Create the nodes
  nodeGlobalIdx = 1;
  for i = 1:length(groupNames)
    if(strcmpi(groupNames{i}, 'everything'))
      fullString = sprintf('%s (%d traces)', groupNames{i}, length(experiment.traceGroups.everything{1}));
      groupMemberNode = uiextras.jTree.CheckboxTreeNode('Name', fullString, 'TooltipString', groupNames{i}, 'Parent', groupTree.Root);
      groupMemberNode.UserData = {'everything', nodeGlobalIdx};
      nodeGlobalIdx = nodeGlobalIdx + 1;
      set(groupMemberNode, 'UIContextMenu', groupTreeContextMenu)
      continue;
    end
    groupNode = uiextras.jTree.CheckboxTreeNode('Name', groupNames{i}, 'TooltipString', groupNames{i}, 'Parent', groupTree.Root);
    groupNode.UserData = {groupNames{i}, nodeGlobalIdx};
    nodeGlobalIdx = nodeGlobalIdx + 1;
    set(groupNode, 'UIContextMenu', groupTreeContextMenu)
    %cmenu = uicontextmenu('Parent', hFigW);
    %uimenu(cmenu,'Label','Rename', 'Callback', {@renameMethod, groupNode});
    %set(groupNode,'UIContextMenu',cmenu)
    
    setIcon(groupNode, Icon1);
    groupMembers = groups.(groupNames{i});
    for j = 1:length(groupMembers)
      fullString = sprintf('%s (%d traces)', groupMembers{j}, length(experiment.traceGroups.(groupNames{i}){j}));
      groupMemberNode = uiextras.jTree.CheckboxTreeNode('Name', fullString, 'TooltipString', groupMembers{j}, 'Parent', groupNode);
      groupMemberNode.UserData = {[groupNames{i} ': ' groupMembers{j}], nodeGlobalIdx};
      nodeGlobalIdx = nodeGlobalIdx + 1;
      set(groupMemberNode, 'UIContextMenu', groupTreeContextMenu)
      %cmenu = uicontextmenu('Parent', hFigW);
      %uimenu(cmenu,'Label','Rename', 'Callback', {@renameMethod, groupMemberNode});
      %set(groupMemberNode, 'UIContextMenu', cmenu)
    end
  end
   
  set(groupTree, 'UIContextMenu', groupTreeContextMenuRoot);
  groupTree.CheckboxClickedCallback = @checkedMethod;
  
  % Now the callbacks
  %------------------------------------------------------------------------
  function checkedMethod(hObject, ~)
    checkedNodesNames = {};
    checkedNodesNamesOrder = [];
    % If root is selected is because all nodes are selected
    if(length(hObject.CheckedNodes) == 1 && strcmp(hObject.CheckedNodes.Name, 'Root'))
      checkedNodes = hObject.Root.Children;
    else
      checkedNodes = hObject.CheckedNodes;
    end
    for i = 1:length(checkedNodes)
      if(~isempty(checkedNodes(i).Children))
        for j = 1:length(checkedNodes(i).Children)
          checkedNodesNames{end+1} = checkedNodes(i).Children(j).UserData{1};
          checkedNodesNamesOrder = [checkedNodesNamesOrder; checkedNodes(i).Children(j).UserData{2}];
        end
      else
        checkedNodesNames{end+1} = checkedNodes(i).UserData{1};
        checkedNodesNamesOrder = [checkedNodesNamesOrder; checkedNodes(i).UserData{2}];
      end
    end
    [~, idx] = sort(checkedNodesNamesOrder);
    updateShowGroups(checkedNodesNames(idx));
  end
  
  %------------------------------------------------------------------------
  function renameMethod(hObject, eventData, handle)
    success = false;
    for curIdx = 1:length(handle.SelectedNodes)
      nodeName = handle.SelectedNodes(curIdx).UserData{1};
      populationsType = strsplit(nodeName, ': ');
      if(~isfield(experiment.traceGroups, populationsType{1}))
        logMsg(['No populations found for: ' populationsType{1}], 'w');
        continue;
      end
      
      subgroupNames = experiment.traceGroupsNames.(populationsType{1});
      if(length(populationsType) > 1)
        groupIdx = find(strcmp(populationsType{2}, subgroupNames));
      elseif(strcmp(populationsType, 'everything'))
        logMsg('Group everything cannot be changed', 'w');
        continue;
      else
        groupIdx = -1;
      end
      if(isempty(groupIdx) || length(groupIdx) > 1)
        logMsg(['No populations found for: ' subgroupNames{curIdx}], 'w');
      end
      % That's for the root names
      if(groupIdx < 0)
        oldName = populationsType{1};
        answer = inputdlg('Enter the new group name',...
                          'Group rename', [1 60], {oldName});
        if(isempty(answer))
          continue;
        end
        newName = strtrim(answer{1});
        % Update all relevant fields
        for it = 1:length(fieldList)
          if(isfield(experiment, fieldList{it}) && isfield(experiment.(fieldList{it}), oldName))
            [experiment.(fieldList{it}).(newName)] = experiment.(fieldList{it}).(oldName);
            experiment.(fieldList{it}) = rmfield(experiment.(fieldList{it}), oldName);
          end
        end
        success = true;
      else
        oldName = experiment.traceGroupsNames.(populationsType{1}){groupIdx};
        answer = inputdlg('Enter the new group name',...
                          'Group rename', [1 60], {oldName});
        if(isempty(answer))
          continue;
        end
        newName = strtrim(answer{1});
        experiment.traceGroupsNames.(populationsType{1}){groupIdx} = newName;
        success = true;
      end
%      handle.SelectedNodes(i).TooltipString
    end
    if(success == true)
      updateGroupTree();
      updateImage();
    end
  end
  %------------------------------------------------------------------------
  function deleteMethod(hObject, eventData, handle)
    success = false;
    for curIdx = 1:length(handle.SelectedNodes)
      nodeName = handle.SelectedNodes(curIdx).UserData{1};
      populationsType = strsplit(nodeName, ': ');
      if(~isfield(experiment.traceGroups, populationsType{1}))
        logMsg(['No populations found for: ' populationsType{1}], 'w');
        continue;
      end
      
      subgroupNames = experiment.traceGroupsNames.(populationsType{1});
      if(length(populationsType) > 1)
        groupIdx = find(strcmp(populationsType{2}, subgroupNames));
      elseif(strcmp(populationsType, 'everything'))
        logMsg('Group everything cannot be changed', 'w');
        continue;
      else
        groupIdx = -1;
      end
      if(isempty(groupIdx) || length(groupIdx) > 1)
        logMsg(['No populations found for: ' subgroupNames{curIdx}], 'w');
      end
      % That's for the root names
      if(groupIdx < 0)
        oldName = populationsType{1};
        choice = questdlg(sprintf('Are you sure you want to delete group %s ?', oldName), ...
          'Delete group', ...
          'Yes', 'No', 'Cancel', 'Cancel');
        switch choice
          case 'Yes'
            % Continue (ugh)
          case 'No'
            continue;
          case 'Cancel'
            continue;
        end
        % Update all relevant fields
        for it = 1:length(fieldList)
          if(isfield(experiment, fieldList{it}) && isfield(experiment.(fieldList{it}), oldName))
            experiment.(fieldList{it}) = rmfield(experiment.(fieldList{it}), oldName);
          end
        end
        success = true;
      else
        oldName = experiment.traceGroupsNames.(populationsType{1}){groupIdx};
        choice = questdlg(sprintf('Are you sure you want to delete group %s : %s ?', populationsType{1}, oldName), ...
          'Delete group', ...
          'Yes', 'No', 'Cancel', 'Cancel');
        switch choice
          case 'Yes'
            % Continue (ugh)
          case 'No'
            continue;
          case 'Cancel'
            continue;
        end
        % Update all relevant fields
        for it = 1:length(fieldList)
          % Leave traceGroupsNames for last
          if(~strcmp(fieldList{it}, 'traceGroupsNames') && isfield(experiment, fieldList{it}) && isfield(experiment.(fieldList{it}), populationsType{1}) && strcmp(experiment.traceGroupsNames.(populationsType{1}){groupIdx}, oldName))
            %experiment.(fieldList{it}) = rmfield(experiment.(fieldList{it}), oldName);
            if(length(experiment.(fieldList{it}).(populationsType{1})) >= groupIdx)
              experiment.(fieldList{it}).(populationsType{1})(groupIdx) = [];
            end
          end
        end
        experiment.traceGroupsNames.(populationsType{1})(groupIdx) = [];
        success = true;
      end
%      handle.SelectedNodes(i).TooltipString
    end
    if(success == true)
      updateGroupTree();
      updateImage();
    end
  end
  
  %------------------------------------------------------------------------
  function selectMethod(hObject, eventData, handle, mode)
    switch mode
      case 'all'
        handle.Root.Checked = true;
      case 'none'
      handle.Root.Checked = true;
      handle.Root.Checked = false;
    end
  end
  
  %------------------------------------------------------------------------
  function sortMethod(hObject, eventData, handle, mode)
    % Get the tree node that was expanded
    for it = 1:length(fieldList)
      if(~isfield(experiment, fieldList{it}))
        continue;
      end
      groupNames = fieldnames(experiment.(fieldList{it}));
      [~, idx] = sort(groupNames);
      switch mode
        case 'name'
          idx = idx(1:end); % Duh
        case 'nameInverse'
          idx = idx(end:-1:1);
      end
      experiment.(fieldList{it}) = orderfields(experiment.(fieldList{it}), idx);
    end
    updateGroupTree();
    updateImage();
  end
  
end

end


