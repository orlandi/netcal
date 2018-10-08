function [hFigW, project] = viewCompareExperiments(project, experiment, populationsBefore, populationsTransitions)
% VIEWCOMPAREEXPERIMENTS performs burst analysis on the given experiment
%
% USAGE:
%    viewCompareExperiments(gui, experiment)
%
% INPUT arguments:
%    project - experiment structure from loadExperiment
%
% OUTPUT arguments:
%    hFigW - figure handle
%
% EXAMPLE:
%    hFigW = viewCompareExperiments(gui, experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
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



%% Create components
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

hs.mainWindow = figure('Visible','off',...
                       'Resize','on',...
                       'Toolbar', 'figure',...
                       'Tag','compareExperiments', ...
                       'DockControls','off',...
                       'NumberTitle', 'off',...
                       'ResizeFcn', @resizeCallback, ...
                       'CloseRequestFcn', @closeCallback,...
                       'MenuBar', 'none',...
                       'Name', ['Compare experiments: ' project.name]);
hFigW = hs.mainWindow;
if(~verLessThan('MATLAB','9.5'))
  addToolbarExplorationButtons(hFigW);
end
hFigW.Position = setFigurePosition(gui, 'width', 800, 'height', 700);
resizeHandle = hFigW.ResizeFcn;
setappdata(hFigW, 'ResizeHandle', resizeHandle);
if(~isempty(gui))
  setappdata(hFigW, 'logHandle', getappdata(gcbf, 'logHandle'));
end


hs.menuExport = uimenu(hs.mainWindow, 'Label', 'Export');
hs.menuExportFigure = uimenu(hs.menuExport, 'Label', 'Figure', 'Callback', @exportFigure);
hs.menuExportData = uimenu(hs.menuExport, 'Label', 'Data', 'Callback', @exportData);

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
mainAxes = axes('Parent', hs.mainWindowFramesPanel);
set(mainAxes, 'ButtonDownFcn', @rightClick);


% Pages buttons -----------------------------------------------------------
% Below image panel
hs.mainWindowBottomButtons = uix.HButtonBox( 'Parent', hs.mainWindowGrid);
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'Linear', 'FontSize', textFontSize, 'callback', {@plotType, 'linear'});
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'Circular', 'FontSize', textFontSize, 'callback', {@plotType, 'circular'});
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'Bars', 'FontSize', textFontSize, 'callback', {@plotType, 'bars'});
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'Squares', 'FontSize', textFontSize, 'callback', {@plotType, 'squares'});
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'Squares compressed', 'FontSize', textFontSize, 'callback', {@plotType, 'squaresCompressed'});
%uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'Box plot', 'FontSize', textFontSize, 'callback', {@plotType, 'boxPlot'});
set(hs.mainWindowBottomButtons, 'ButtonSize', [100 15], 'Padding', 0, 'Spacing', 15);

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
  'Heights', [minGridBorder -1 20 100 minGridBorder]);
cleanMenu();
updateMenus();

mainAxes.Units ='normalized';
mainAxes.Position=[0 0 1 1];

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

if(isfield(project, 'linearTransitionsOptionsCurrent'))
  optc = project.linearTransitionsOptionsCurrent;
else
  optc = linearTransitionsOptions;
  optc = optc.setDefaults();
end

try
  optc = optc.setExperimentDefaults(experiment);
  plotLinear(mean(populationsBefore, 1), mean(populationsTransitions, 3), optc);
  project.linearTransitionsOptionsCurrent = optc;
catch ME
  logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
end

updateImage();
%if(isempty(gui))
%waitfor(hFigW);
%end

%% Callbacks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------------------------------------------------------------
function resizeCallback(~, ~)
  updateImage();
end


function exportFigure(~, ~)
  [fileName, pathName] = uiputfile({'*.png'; '*.pdf'; '*.tiff';'*.eps'}, 'Save figure', [project.folder filesep 'compareExperiments']);
  if(fileName ~= 0)
    %[fpa, fpb, fpc] = fileparts(fileName);
    ncbar.automatic('Exporting figure');
    set(gcf,'renderer','opengl');
    export_fig([pathName fileName], '-r300', mainAxes);
    ncbar.close();
  end
end

function exportData(~, ~)
  %populationsBefore
  %populationsTransitions
  checkedExperiments = find(project.checkedExperiments);
  experimentsNames = {};
  for i = 1:2:length(checkedExperiments)
    experimentsNames{end+1} = [project.experiments{checkedExperiments(i)} ' - ' project.experiments{checkedExperiments(i+1)}];
  end
  
  populationsNames = ...
    [cellfun(@(x)[x(:)' ' before'], experiment.traceGroupsNames.classifier, 'UniformOutput', false); ...
    cellfun(@(x)[x(:)' ' after'], experiment.traceGroupsNames.classifier, 'UniformOutput', false)];

  
  populationsAfter = squeeze(sum(populationsTransitions, 1))';
  fullFile = exportDataCallback([], [], {'*.xlsx'}, ...
                            [project.folder 'experimentComparison'], ...
                            [populationsBefore, populationsAfter], ...
                            populationsNames, ...
                            'global', ...
                            experimentsNames);
  if(isempty(fullFile))
    return;
  end
  % Now the transitions
  for i = 1:size(populationsTransitions, 3)
    exportDataCallback([], [], {'*.xlsx'}, ...
                            [project.folder 'experimentComparison'], ...
                            squeeze(populationsTransitions(:, :, i)), ...
                            cellfun(@(x)[x(:)' ' after'], experiment.traceGroupsNames.classifier, 'UniformOutput', false), ...
                            experimentsNames{i}, ...
                            cellfun(@(x)[x(:)' ' before'], experiment.traceGroupsNames.classifier, 'UniformOutput', false), fullFile);
  end
end

%--------------------------------------------------------------------------
function closeCallback(~, ~, varargin)
  delete(hFigW);
end

%--------------------------------------------------------------------------
function plotType(~, ~, type)
  switch type
    case 'linear'
      curOptionsName = 'linearTransitionsOptionsCurrent';
      if(isfield(project, curOptionsName))
        optionsClass = project.(curOptionsName);
      else
        optionsClass = linearTransitionsOptions;
      end
      plotFunction = @plotLinear;
      popBefore = mean(populationsBefore, 1);
      popTrans = mean(populationsTransitions, 3);
    case 'circular'
      curOptionsName = 'circularTransitionsOptionsCurrent';
      if(isfield(project, curOptionsName))
        optionsClass = project.(curOptionsName);
      else
        optionsClass = circularTransitionsOptions;
      end
      plotFunction = @plotCircular;
      popBefore = mean(populationsBefore, 1);
      popTrans = mean(populationsTransitions, 3);
    case 'bars'
      curOptionsName = 'linearTransitionsOptionsCurrent';
      if(isfield(project, curOptionsName))
        optionsClass = project.(curOptionsName);
      else
        optionsClass = linearTransitionsOptions;
      end
      plotFunction = @plotBars;
      popBefore = populationsBefore;
      popTrans = populationsTransitions;
    case 'squares'
      curOptionsName = 'linearTransitionsOptionsCurrent';
      if(isfield(project, curOptionsName))
        optionsClass = project.(curOptionsName);
      else
        optionsClass = linearTransitionsOptions;
      end
      plotFunction = @plotSquares;
      popBefore = populationsBefore;
      popTrans = populationsTransitions;
    case 'squaresCompressed'
      curOptionsName = 'linearTransitionsOptionsCurrent';
      if(isfield(project, curOptionsName))
        optionsClass = project.(curOptionsName);
      else
        optionsClass = linearTransitionsOptions;
      end
      plotFunction = @plotSquaresCompressed;
      popBefore = populationsBefore;
      popTrans = populationsTransitions;
    case 'boxPlot'
      plotFunction = @plotBoxPlot;
      popBefore = populationsBefore;
      popTrans = populationsTransitions;
  end
  [success, curOptions] = optionsWindow(optionsClass, 'experiment', experiment);
  if(success)
    %ncbar.automatic('Plotting...');
    plotFunction(popBefore, popTrans, curOptions);
    project.(curOptionsName) = curOptions;
    %ncbar.close();
  end
  updateImage();
end

%% Utility functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------------------------------------------------------------
function plotCircular(populationsBefore, populationsTransitions, options)
  params = options.get();

  % First hack
  populationsAfter = sum(populationsTransitions);
  if(size(populationsBefore, 1) > 1)
    populationsBefore = populationsBefore';
  end
  if(size(populationsAfter, 1) > 1)
    populationsAfter = populationsAfter';
  end
  populations = [populationsBefore populationsAfter(end:-1:1)];
  N = length(populations);

  % Set parameters
  fractionsNames = params.populationsNames;
  beforeAfterNames = params.beforeAfterNames;
  titleName = params.title;
  rad1 = params.innerRadius;
  rad2 = params.outerRadius;
  delta = params.populationsGap;
  rad3 = params.transitionRadius;
  expn = params.curvatureExponent;
  maxF = params.curvatureMultiplier;
  radText = params.populationNamesPosition;
  radTextInner = params.transitionFractionsTextPosition;
  barsBlackEdges = params.barsBlackEdges;
  transitionsBlackEdges = params.transitionsBlackEdges;
  curvatureType = params.curvatureType;
  popMinSize = params.barMinSize;

  cmap = eval([params.colormap '(N+1)']);
  cmap = cmap(2:end, :);

  % Hack to duplicate the stuff
  fractionsNames = [fractionsNames, fractionsNames(end:-1:1)];  
  populationsTransitions = [zeros(size(populationsTransitions)), populationsTransitions(:,end:-1:1);
    zeros(size(populationsTransitions)), zeros(size(populationsTransitions))];
  fractionHack = 2;
  cmap = [cmap(1:2:end, :); cmap(end:-2:2, :)];

  % Now no more hack - generalized
  fractions = populations/sum(populations);

  fractionTransfers = zeros(length(populations), length(populations), 2);
  for i = 1:length(populations)
    for j = 1:length(populations)
      fractionTransfers(i,j, :) = [populationsTransitions(i,j)/populations(i), populationsTransitions(i,j)/populations(j)];
    end
  end

  cmapvals = floor(linspace(1, length(cmap), N));

  cla(mainAxes);
  axes(mainAxes);
  
  hold on;
  axis square;
  box on;
  %
  xlim([-1.2 1.2]);
  ylim([-1.2 1.2]);
  set(gca,'XTick',[]);
  set(gca,'YTick',[]);
  yl = ylim;
  plot([0 0], yl,'k--');

  initialAngle = -pi/2;
  % Modified to avoid overlap at 2PI
  fractionEdges = [0, cumsum(fractions)];

  fractionsBefore = populationsBefore/sum(populationsBefore);
  fractionsAfter = populationsAfter/sum(populationsAfter);
  fractionEdgesWithDelta = zeros(2, length(fractionsBefore)+length(fractionsAfter));


  alpha = 1-delta*(length(fractions))-popMinSize*length(fractions);

  for i = 1:length(fractionEdgesWithDelta)
    if(i ==  1)
      fractionEdgesWithDelta(1, i) = delta/2;
    else
      fractionEdgesWithDelta(1, i) = fractionEdgesWithDelta(2, i-1)+delta;
    end
    if(i == length(fractionEdgesWithDelta))
      fractionEdgesWithDelta(2, i) = 1-delta/2;
    else
      fractionEdgesWithDelta(2, i) = ...
        fractionEdgesWithDelta(1, i) + fractions(i)*alpha+popMinSize;
    end
  end

  fractionEdges = mean(fractionEdgesWithDelta);

  angles = -fractionEdgesWithDelta*2*pi + initialAngle;


  % Ok, get the new angles
  rads = zeros(N, 2);
  for i = 1:N
        rads(i, 1) = angles(1, i);
        rads(i, 2) = angles(2, i);
  end

  % Calculate the segmentet circle
  for i = 1:N
    P = plot_arc(rads(i,1),rads(i,2),0,0,rad1,rad2,100);
    %set(P,'facecolor',cmap(cmapvals(i),:),'linewidth',1, 'edgecolor','k');
    set(P,'facecolor', cmap(cmapvals(i),:),'linewidth',1);
    if(barsBlackEdges)
      set(P, 'edgecolor', 'k');
    else
      set(P, 'edgecolor', cmap(cmapvals(i),:));
    end
  end

  patchSize = [];
  patchHandles = [];
  % Quick pass to get patchSizes and then do them in order
  fractionSizes = diff(fractionEdgesWithDelta);
  for i = 1:N
    for j = 1:N
      cumsumFractionsBefore = [cumsum(fractionTransfers(i, :, 1),'reverse') 0];
      cumsumFractionsAfter = [cumsum(fractionTransfers(:, j, 2),'reverse')' 0];

      f1 = fractionEdgesWithDelta(1, i)+fractionSizes(i)*cumsumFractionsBefore(j);
      f2 = fractionEdgesWithDelta(1, i)+fractionSizes(i)*cumsumFractionsBefore(j+1);
      f3 = fractionEdgesWithDelta(1, j)+fractionSizes(j)*cumsumFractionsAfter(i);
      f4 = fractionEdgesWithDelta(1, j)+fractionSizes(j)*cumsumFractionsAfter(i+1);
      patchSize = [patchSize; i, j, f2-f1];
    end
  end

  patchSize = sortrows(patchSize, 3);

  for pit = 1:size(patchSize, 1)
    i = patchSize(pit, 1);
    j = patchSize(pit, 2);
    if(patchSize(pit, 3) == 0)
      continue;
    end
    cumsumFractionsBefore = [cumsum(fractionTransfers(i, :, 1),'reverse') 0];
    cumsumFractionsAfter = [cumsum(fractionTransfers(:, j, 2),'reverse')' 0];

    f1 = fractionEdgesWithDelta(1, i)+fractionSizes(i)*cumsumFractionsBefore(j);
    f2 = fractionEdgesWithDelta(1, i)+fractionSizes(i)*cumsumFractionsBefore(j+1);
    f3 = fractionEdgesWithDelta(1, j)+fractionSizes(j)*cumsumFractionsAfter(i);
    f4 = fractionEdgesWithDelta(1, j)+fractionSizes(j)*cumsumFractionsAfter(i+1);

    radsBefore = -[f1 f2]*2*pi + initialAngle;
    radsAfter = -[f3 f4]*2*pi + initialAngle;

    a = radsBefore(1);
    b = radsBefore(2);
    h = 0;
    k = 0;
    l = 100;
    t = linspace(a,b,l);
    x1 = rad3*cos(t) + h;
    y1 = rad3*sin(t) + k;

    a = radsAfter(1);
    b = radsAfter(2);
    h = 0;
    k = 0;
    l = 100;
    t = linspace(a,b,l);
    x2 = rad3*cos(t) + h;
    y2 = rad3*sin(t) + k;

    % Change curvature depending on x position
    switch curvatureType
      case 'custom'
        prefactor1 = maxF*(1-mean(abs([x1(1) x2(1)]))).^expn;
        prefactor2 = maxF*(1-mean(abs([x1(end) x2(end)]))).^expn;
        prefactor3 = maxF*(1-mean(abs([x1(1) x1(end) x2(1) x2(end)]))).^expn;
      case 'tangent'
        prefactor1 = maxF;
        prefactor2 = maxF;
        prefactor3 = maxF;
    end

    [nx1, ny1] = getCurvedConnection([x1(end) x2(1)], [y1(end) y2(1)], prefactor1, curvatureType);
    [nx2, ny2] = getCurvedConnection([x2(end) x1(1)], [y2(end) y1(1)], prefactor2, curvatureType);
    % Now try the patch
    patchX = [x1, nx1, x2, nx2];
    patchY = [y1, ny1, y2, ny2];

    % Now the interpolating line for colors
    [nxI, nyI] = getCurvedConnection([x1(round(length(x1)/2)) x2(round(length(x2)/2))], [y1(round(length(y1)/2)) y2(round(length(y2)/2))], prefactor3, curvatureType);
    initialColor = cmap(i, :);
    finalColor = cmap(j, :);
    cI = zeros(length(nxI), 3);
    for cc = 1:3
      cI(:, cc) = initialColor(cc)+(0:(length(nxI)-1))/(length(nxI)-1)*(finalColor(cc)-initialColor(cc));
    end
    % Now get the associated patch interpolated color
    patchC = zeros(length(patchX), 1, 3);

    closestP = [ones(size(x1)), 1:size(cI,1), ones(size(x1))*size(cI,1), size(cI,1):-1:1];
    patchC(:, 1, :) = cI(closestP, :);
    P = patch(patchX', patchY', patchC);
    if(transitionsBlackEdges)
      set(P, 'edgecolor', 'k', 'FaceAlpha', params.transparency); %0.75
    else
      set(P, 'edgecolor', 'none', 'FaceAlpha', params.transparency);
    end
    patchHandles = [patchHandles; P];
  end

  % Now the texts

  % First the titles
  text(-1.2, 1.1, beforeAfterNames{1}, 'HorizontalAlignment', 'left', ...
    'FontSize', 16, 'FontWeight', 'bold');
  text(1.2, 1.1, beforeAfterNames{2}, 'HorizontalAlignment', 'right', ...
    'FontSize', 16, 'FontWeight', 'bold');

  text(0, 1.3, titleName, 'HorizontalAlignment', 'center', ...
    'FontSize', 20, 'FontWeight', 'bold');

  % Now the populations
  textPos = fractionEdges;
  %textPos = fractionEdges(1:end-1)+diff(fractionEdges)/2;
  textAngles = -textPos*2*pi + initialAngle;
  %textPosBefore = fractionEdgesBefore;
  %textPosAfter = fractionEdgesAfter;


  for i = 1:N
      xt = radText*cos(textAngles(i));
      yt = radText*sin(textAngles(i));
      switch params.countType
        case 'relative'
          newName = {fractionsNames{i}; sprintf('%.3g%%',fractionHack*100*fractions(i))};
        case 'absolute'
          newName = {fractionsNames{i}; sprintf('%d',populations(i))};
      end
      if(xt > 0)
        angleAdd = 0;
        angleAlign = 'left';
      else
        angleAdd = 180;
        angleAlign = 'right';
      end
      a=text(xt, yt, newName, 'HorizontalAlignment', angleAlign, ...
        'FontWeight', 'bold', 'rotation', textAngles(i)/2/pi*360+angleAdd);
  end

  % Now the innerfractions
  fractionSizes = diff(fractionEdgesWithDelta);
  for pit = 1:size(patchSize, 1)
    i = patchSize(pit, 1);
    j = patchSize(pit, 2);
    if(patchSize(pit, 3) == 0)
      continue;
    end
    cumsumFractionsBefore = [cumsum(fractionTransfers(i, :, 1), 'reverse') 0];
    cumsumFractionsAfter = [cumsum(fractionTransfers(:, j, 2), 'reverse')' 0];

    f1 = fractionEdgesWithDelta(1, i)+fractionSizes(i)*cumsumFractionsBefore(j);
    f2 = fractionEdgesWithDelta(1, i)+fractionSizes(i)*cumsumFractionsBefore(j+1);
    f3 = fractionEdgesWithDelta(1, j)+fractionSizes(j)*cumsumFractionsAfter(i);
    f4 = fractionEdgesWithDelta(1, j)+fractionSizes(j)*cumsumFractionsAfter(i+1);

    radsBefore = -mean([f1 f2])*2*pi + initialAngle;
    radsAfter = -mean([f3 f4])*2*pi + initialAngle;

    xt = radTextInner*cos(radsBefore);
    yt = radTextInner*sin(radsBefore);
    if(xt > 0)
        angleAdd = 0;
        angleAlign = 'right';
      else
        angleAdd = 180;
        angleAlign = 'left';
    end
    switch params.countType
      case 'relative'
        newName = {sprintf('%.3g%%', 100*fractionTransfers(i, j, 1))};
      case 'absolute'
        newName = {sprintf('%d', populationsTransitions(i, j))};
    end

    rotationAngle = radsBefore/2/pi*360+angleAdd;
    if(isnan(rotationAngle))
      rotationAngle = 0;
    end
    a=text(xt, yt, newName, 'HorizontalAlignment', angleAlign, ...
      'FontWeight', 'bold', 'rotation', rotationAngle);

    xt = radTextInner*cos(radsAfter);
    yt = radTextInner*sin(radsAfter);
    if(xt > 0)
        angleAdd = 0;
        angleAlign = 'right';
      else
        angleAdd = 180;
        angleAlign = 'left';
    end
    switch params.countType
      case 'relative'
        newName = {sprintf('%.3g%%', 100*fractionTransfers(i, j, 2))};
      case 'absolute'
        newName = {sprintf('%d', populationsTransitions(i, j))};
    end

    rotationAngle = radsAfter/2/pi*360+angleAdd;
    if(isnan(rotationAngle))
      rotationAngle = 0;
    end
    text(xt, yt, newName, 'HorizontalAlignment', angleAlign, ...
      'FontWeight', 'bold', 'rotation', rotationAngle);
  end

  axis off equal;
end

%--------------------------------------------------------------------------
function plotLinear(populationsBefore, populationsTransitions, options)
  params = options.get();

  % Set parameters
  fractionsNames = params.populationsNames;
  beforeAfterNames = params.beforeAfterNames;
  titleName = params.title;
  barPositions = params.barPositions;
  barWidth = params.barWidth;
  delta = params.populationsGap;
  popMinSize = params.barMinSize;

  barGap = params.barGap;
  radTextGap = params.populationNamesGap;
  radTextInnerGap = params.transitionsNamesGap;
  sigmoidPrefactor = params.sigmoidPrefactor;
  barsBlackEdges = params.barsBlackEdges;
  transitionsBlackEdges = params.transitionsBlackEdges;

  populationsAfter = sum(populationsTransitions);
  if(size(populationsBefore, 1) > 1)
    populationsBefore = populationsBefore';
  end
  if(size(populationsAfter, 1) > 1)
    populationsAfter = populationsAfter';
  end

  fractionsBefore = populationsBefore/sum(populationsBefore);
  fractionsAfter = populationsAfter/sum(populationsAfter);

  fractionTransfers = zeros(length(populationsBefore), length(populationsBefore), 2);
  for i = 1:length(populationsBefore)
    for j = 1:length(populationsBefore)
      fractionTransfers(i,j, :) = [populationsTransitions(i,j)/populationsBefore(i), populationsTransitions(i,j)/populationsAfter(j)];
    end
  end

  N = length(populationsBefore);

  Ncols = N*2;
  cmap = eval([params.colormap '(Ncols+1)']);
  cmap = cmap(2:end, :);
  cmap = [cmap(1:2:end, :); cmap(2:2:end, :)];
  cmapvals = floor(linspace(1, length(cmap), Ncols));

  cla(mainAxes);
  axes(mainAxes);

  hold on;
  axis equal;
  box on;
  %
  xlim([-0.2 0.2]+barPositions);
  ylim([-0.05 1.15]);
  set(gca,'XTick',[]);
  set(gca,'YTick',[]);

  %%plot([0 0], yl,'k--');

  % Modified to avoid overlap at 2PI
  fractionEdgesBeforeWithDelta = zeros(2, length(fractionsBefore));
  fractionEdgesAfterWithDelta = zeros(2, length(fractionsAfter));

  alpha = 1-delta*(length(fractionsBefore)-1)-popMinSize*length(fractionsBefore);

  for i = 1:length(fractionEdgesBeforeWithDelta)
    if(i ==  1)
      fractionEdgesBeforeWithDelta(1, i) = 0;
      fractionEdgesAfterWithDelta(1, i) = 0;
    else
      fractionEdgesBeforeWithDelta(1, i) = fractionEdgesBeforeWithDelta(2, i-1)+delta;
      fractionEdgesAfterWithDelta(1, i) = fractionEdgesAfterWithDelta(2, i-1)+delta;
    end
    if(i == length(fractionEdgesBeforeWithDelta))
      fractionEdgesBeforeWithDelta(2, i) = 1;
      fractionEdgesAfterWithDelta(2, i) = 1;
    else
      fractionEdgesBeforeWithDelta(2, i) = ...
        fractionEdgesBeforeWithDelta(1, i) + fractionsBefore(i)*alpha+popMinSize;
      fractionEdgesAfterWithDelta(2, i) = ...
        fractionEdgesAfterWithDelta(1, i) + fractionsAfter(i)*alpha+popMinSize;
    end
  end

  fractionEdgesBefore = mean(fractionEdgesBeforeWithDelta);
  fractionEdgesAfter = mean(fractionEdgesAfterWithDelta);

  % Create the bars
  for i = 1:N
    xPatchBefore = [0 0 -1 -1]*barWidth+barPositions(1);
    yPatchBefore = [fractionEdgesBeforeWithDelta(1,i) fractionEdgesBeforeWithDelta(2,i) fractionEdgesBeforeWithDelta(2,i) fractionEdgesBeforeWithDelta(1,i)];
    xPatchAfter = [0 0 1 1]*barWidth+barPositions(2);
    yPatchAfter = [fractionEdgesAfterWithDelta(1,i) fractionEdgesAfterWithDelta(2,i) fractionEdgesAfterWithDelta(2,i) fractionEdgesAfterWithDelta(1,i)];
    P = patch(xPatchBefore, yPatchBefore, 'r');
    set(P,'facecolor', cmap(cmapvals(i),:),'linewidth',1, ...
      'edgecolor', cmap(cmapvals(i),:));
    if(barsBlackEdges)
      P.EdgeColor = 'k';
    end
    P = patch(xPatchAfter, yPatchAfter, 'r');
    if(params.useSameColors)
      set(P,'facecolor', cmap(cmapvals(i),:),'linewidth',1, ...
        'edgecolor', cmap(cmapvals(i),:));
    else
      set(P,'facecolor', cmap(cmapvals(i+N),:),'linewidth',1, ...
        'edgecolor', cmap(cmapvals(i+N),:));
    end
    if(barsBlackEdges)
      P.EdgeColor = 'k';
    end
  end

  patchSize = [];
  patchHandles = [];
  % Quick pass to get patchSizes and then do them in order
  for i = 1:N
    for j = 1:N
      fractionSizesBefore = diff(fractionEdgesBeforeWithDelta);
      fractionSizesAfter = diff(fractionEdgesAfterWithDelta);
      cumsumFractionsBefore = [0 cumsum(fractionTransfers(i, :, 1))];
      cumsumFractionsAfter = [0 cumsum(fractionTransfers(:, j, 2))'];

      f1 = fractionEdgesBeforeWithDelta(1, i)+fractionSizesBefore(i)*cumsumFractionsBefore(j);
      f2 = fractionEdgesBeforeWithDelta(1, i)+fractionSizesBefore(i)*cumsumFractionsBefore(j+1);
      f3 = fractionEdgesAfterWithDelta(1, j)+fractionSizesAfter(j)*cumsumFractionsAfter(i);
      f4 = fractionEdgesAfterWithDelta(1, j)+fractionSizesAfter(j)*cumsumFractionsAfter(i+1);
      patchSize = [patchSize; i, j, f2-f1];
    end
  end

  patchSize = sortrows(patchSize, -3);

  fullF = [];
  fullV = [];
  fullCol = [];
  fullPatchC = [];
  for pit = 1:size(patchSize, 1)
    if(patchSize(pit, 3) == 0)
      continue;
    end
    i = patchSize(pit, 1);
    j = patchSize(pit, 2);
    fractionSizesBefore = diff(fractionEdgesBeforeWithDelta);
    fractionSizesAfter = diff(fractionEdgesAfterWithDelta);
    cumsumFractionsBefore = [0 cumsum(fractionTransfers(i, :, 1))];
    cumsumFractionsAfter = [0 cumsum(fractionTransfers(:, j, 2))'];

    f1 = fractionEdgesBeforeWithDelta(1, i)+fractionSizesBefore(i)*cumsumFractionsBefore(j);
    f2 = fractionEdgesBeforeWithDelta(1, i)+fractionSizesBefore(i)*cumsumFractionsBefore(j+1);
    f3 = fractionEdgesAfterWithDelta(1, j)+fractionSizesAfter(j)*cumsumFractionsAfter(i);
    f4 = fractionEdgesAfterWithDelta(1, j)+fractionSizesAfter(j)*cumsumFractionsAfter(i+1);

    radsBefore = [f1 f2];
    radsAfter = [f3 f4];

    xBefore = [1, 1]*barPositions(1)+barGap;
    xAfter = [1, 1]*barPositions(2)-barGap;
    yBefore = [f1 f2];
    yAfter = [f3 f4];

    [xLineDown, yLineDown] = getSigmoidConnection([xBefore(1) xAfter(1)], [yBefore(1) yAfter(1)], sigmoidPrefactor);
    [xLineUp, yLineUp] = getSigmoidConnection([xBefore(2) xAfter(2)], [yBefore(2) yAfter(2)], sigmoidPrefactor);

    patchX = [xLineDown xLineUp(end:-1:1)];
    patchY = [yLineDown yLineUp(end:-1:1)];

    % Now the interpolating line for colors
    [nxI, nyI] = getSigmoidConnection([mean(xBefore) mean(xAfter)], [mean(yBefore) mean(yAfter)], sigmoidPrefactor);
    initialColor = cmap(i, :);
    finalColor = cmap(j+N, :);

    cI = zeros(length(nxI), 3);
    for cc = 1:3
      cI(:, cc) = initialColor(cc)+(0:(length(nxI)-1))/(length(nxI)-1)*(finalColor(cc)-initialColor(cc));
    end
    % Now get the associated patch interpolated color
    patchC = zeros(length(patchX), 1, 3);
    
    if(params.useSameColors)
      closestP = ones(size([1:size(cI,1), size(cI,1):-1:1]));
    else
      closestP = [1:size(cI,1), size(cI,1):-1:1];
    end

    patchC(:, 1, :) = cI(closestP, :);
    %P = patch(patchX', patchY', patchC);
    %P.CData = patchC;
    %for k = 1:(numel(patchX)/2-1)
    %  patchCoords = [k, k+1, numel(patchX)-k, numel(patchX)-(k-1)];
    %  P = patch(patchX(patchCoords)', patchY(patchCoords)', patchC(patchCoords));
    %  P.CData = patchC(patchCoords);
    v = [patchX', patchY'];
    f = [];
    col = [];

    f = length(fullV) + (1:length(patchX));
    col = patchC;
%     for k = 1:(numel(patchX)/2-1)
%       patchCoords = length(fullV) + [k, k+1, numel(patchX)-k, numel(patchX)-(k-1)];
%       f = [f; patchCoords];
%       col = [col; patchC(1)];
%       %cdata = [cdata; patchC(patchCoords, 1, :)];
%     end
    %P = patch('Faces',f,'Vertices',v,'FaceVertexCData',col,'FaceColor','flat');
    fullF = [fullF; f];
    fullV = [fullV; v];
    fullCol = [fullCol; col];
    fullPatchC = [fullPatchC; patchC];
%     P.CData = patchC;
%     %P.FaceColor = 'flat';
%       if(transitionsBlackEdges)
%         P.EdgeColor = 'k';
%       else
%         P.EdgeColor = 'flat';
%       end
%       %set(P, 'FaceAlpha', params.transparency);
%       set(P, 'FaceAlpha', 1);
%       patchHandles = [patchHandles; P];
    %end
  end
  % Let's try to do all patches as a single polygon
  %size(fullF)
  %size(fullV)
  %size(squeeze(fullCol(:,1,:)))
  %squeeze(fullCol(:, 1, :))
  P = patch('Faces',fullF,'Vertices',fullV,'FaceVertexCData',squeeze(fullCol(:,1,:)),'FaceColor','interp');
  P.CData = fullPatchC;
  if(transitionsBlackEdges)
    P.EdgeColor = 'k';
  else
    P.EdgeColor = 'none';
  end
  set(P, 'FaceAlpha', params.transparency);
  set(P, 'EdgeAlpha', params.transparency);
  
      %patchHandles = [patchHandles; P];
      %patchHandles
  % Now the texts
  % First the titles
  text(barPositions(1)-barWidth, 1.05, beforeAfterNames{1}, 'HorizontalAlignment', 'left', ...
    'FontSize', 16, 'FontWeight', 'bold');
  text(barPositions(2)+barWidth, 1.05, beforeAfterNames{2}, 'HorizontalAlignment', 'right', ...
    'FontSize', 16, 'FontWeight', 'bold');

  text(0, 1.1, titleName, 'HorizontalAlignment', 'center', ...
    'FontSize', 20, 'FontWeight', 'bold');


  % Now the populations
  textPosBefore = fractionEdgesBefore;
  textPosAfter = fractionEdgesAfter;

  for i = 1:N
      xt = barPositions(1)-barWidth-radTextGap;
      yt = textPosBefore(i);
      newName = {fractionsNames{i}; sprintf('%.3g%%',100*fractionsBefore(i))};
      switch params.countType
        case 'relative'
          newName = {fractionsNames{i}; sprintf('%.3g%%',100*fractionsBefore(i))};
        case 'absolute'
          newName = {fractionsNames{i}; sprintf('%d',round(populationsBefore(i)))};
      end
      a=text(xt, yt, newName, 'HorizontalAlignment', 'right', ...
        'FontSize', 12, 'FontWeight', 'bold');
      xt = barPositions(2)+barWidth+radTextGap;
      yt = textPosAfter(i);

      switch params.countType
        case 'relative'
          newName = {fractionsNames{i}; sprintf('%.3g%%',100*fractionsAfter(i))};
        case 'absolute'
          newName = {fractionsNames{i}; sprintf('%d', round(populationsAfter(i)))};
      end
      text(xt, yt, newName, 'HorizontalAlignment', 'left', ...
        'FontSize', 12, 'FontWeight', 'bold');
  end

  % Now the innerfractions
  for pit = 1:size(patchSize, 1)
    if(patchSize(pit, 3) == 0)
      continue;
    end
    i = patchSize(pit, 1);
    j = patchSize(pit, 2);
    fractionSizesBefore = diff(fractionEdgesBeforeWithDelta);
    fractionSizesAfter = diff(fractionEdgesAfterWithDelta);
    cumsumFractionsBefore = [0 cumsum(fractionTransfers(i, :, 1))];
    cumsumFractionsAfter = [0 cumsum(fractionTransfers(:, j, 2))'];

    f1 = fractionEdgesBeforeWithDelta(1, i)+fractionSizesBefore(i)*cumsumFractionsBefore(j);
    f2 = fractionEdgesBeforeWithDelta(1, i)+fractionSizesBefore(i)*cumsumFractionsBefore(j+1);
    f3 = fractionEdgesAfterWithDelta(1, j)+fractionSizesAfter(j)*cumsumFractionsAfter(i);
    f4 = fractionEdgesAfterWithDelta(1, j)+fractionSizesAfter(j)*cumsumFractionsAfter(i+1);

    xt = barPositions(1)+barGap+radTextInnerGap;
    yt = mean([f1 f2]);  
    switch params.countType
      case 'relative'
        newName = {sprintf('%.3g%%', 100*fractionTransfers(i, j, 1))};
      case 'absolute'
        newName = {sprintf('%d', round(populationsTransitions(i, j)))};
    end
    a=text(xt, yt, newName, 'HorizontalAlignment', 'left', ...
      'FontSize', 12, 'FontWeight', 'bold');
    xt = barPositions(2)-barGap-radTextInnerGap;
    yt = mean([f3 f4]);

    switch params.countType
      case 'relative'
        newName = {sprintf('%.3g%%', 100*fractionTransfers(i, j, 2))};
      case 'absolute'
        newName = {sprintf('%d', round(populationsTransitions(i, j)))};
    end
    text(xt, yt, newName, 'HorizontalAlignment', 'right', ...
      'FontSize', 12, 'FontWeight', 'bold');
  end

  axis off;
end

%--------------------------------------------------------------------------
function plotBars(populationsBefore, populationsTransitions, options)
  params = options.get();
  
  %params.populationsGap = 0.03;
  %params.transparency = 0.75;
%   params.mergeColors = false;
%   params.useSameColors = false;
%   params.leftRightGap = 0.25;
%   params.showOnlyHalf = false;
%   params.showErrorBars = false;
  
  horBarGap = 0.01/2;

  % Set parameters
  fractionsNames = params.populationsNames;
  beforeAfterNames = params.beforeAfterNames;
  titleName = params.title;
  barPositions = params.barPositions;
  barWidth = params.barWidth;
  delta = params.populationsGap;
  popMinSize = params.barMinSize;

  barGap = params.barGap;
  radTextGap = params.populationNamesGap;
  radTextInnerGap = params.transitionsNamesGap;
  sigmoidPrefactor = params.sigmoidPrefactor;
  barsBlackEdges = params.barsBlackEdges;
  transitionsBlackEdges = params.transitionsBlackEdges;

  if(size(populationsBefore, 1) > 1 && size(populationsBefore, 2) > 1)
    Nrepeats = size(populationsTransitions, 3);
    populationsAfter = squeeze(sum(populationsTransitions, 1))';
    populationsAfterStd = std(populationsAfter, [], 1);
    populationsAfter = round(mean(populationsAfter, 1));
    minPopulationsAfter = populationsAfter-populationsAfterStd/sqrt(Nrepeats);
    maxPopulationsAfter = populationsAfter+populationsAfterStd/sqrt(Nrepeats);

    populationsBeforeStd = std(populationsBefore);
    populationsBefore = round(mean(populationsBefore, 1));
    minPopulationsBefore = populationsBefore-populationsBeforeStd/sqrt(Nrepeats);
    maxPopulationsBefore = populationsBefore+populationsBeforeStd/sqrt(Nrepeats);

    populationsTransitionsStd = std(populationsTransitions, [], 3);
    populationsTransitions = round(mean(populationsTransitions, 3));
    minPopulationsTransitions = populationsTransitions - populationsTransitionsStd/sqrt(Nrepeats);
    maxPopulationsTransitions = populationsTransitions + populationsTransitionsStd/sqrt(Nrepeats);

    multipleInputs = true;
  else
    populationsAfter = sum(populationsTransitions);
    if(size(populationsBefore, 1) > 1)
      populationsBefore = populationsBefore';
    end
    if(size(populationsAfter, 1) > 1)
      populationsAfter = populationsAfter';
    end
    minPopulationsBefore = populationsBefore;
    maxPopulationsBefore = populationsBefore;
    minPopulationsTransitions = populationsTransitions;
    maxPopulationsTransitions = populationsTransitions;
    multipleInputs = false;
  end


  fractionsBefore = populationsBefore/sum(populationsBefore);
  fractionsAfter = populationsAfter/sum(populationsAfter);

  fractionTransfers = zeros(length(populationsBefore), length(populationsBefore), 2);
  fractionTransfersMin = zeros(length(populationsBefore), length(populationsBefore), 2);
  fractionTransfersMax = zeros(length(populationsBefore), length(populationsBefore), 2);
  for i = 1:length(populationsBefore)
    for j = 1:length(populationsBefore)
      fractionTransfers(i,j, :) = [populationsTransitions(i,j)/populationsBefore(i), populationsTransitions(i,j)/populationsAfter(j)];
      fractionTransfersMin(i,j, :) = [minPopulationsTransitions(i,j)/populationsBefore(i), minPopulationsTransitions(i,j)/populationsAfter(j)];
      fractionTransfersMax(i,j, :) = [maxPopulationsTransitions(i,j)/populationsBefore(i), maxPopulationsTransitions(i,j)/populationsAfter(j)];
    end
  end

  N = length(populationsBefore);

  Ncols = N;
  %cmap = eval([params.colormap '(Ncols+5)']);
  if(params.useSameColors)
    cmap = eval([params.colormap '(32)']);
    cmap = cmap(5:end-3, :);
    cmapvals = floor(linspace(1, length(cmap), Ncols));
    cmapvals = [cmapvals, cmapvals];
    Ncols = N*2;
  else
    Ncols = N*2;
    cmap = eval([params.colormap '(32)']);
    cmap = cmap(5:end-3, :);
    cmapvals = floor(linspace(1, length(cmap), Ncols));
    cmapvals = [cmapvals(1:2:end), cmapvals(2:2:end)];
  end


  cla(mainAxes);
  axes(mainAxes);

  hold on;
  axis equal;
  box on;
  %
%  xlim([-0.2 0.2]+barPositions);
%  ylim([-0.05 1.15]);
  set(gca,'XTick',[]);
  set(gca,'YTick',[]);


  % Modified to avoid overlap at 2PI
  fractionEdgesBeforeWithDelta = zeros(2, length(fractionsBefore));
  fractionEdgesAfterWithDelta = zeros(2, length(fractionsAfter));

  alpha = 1-delta*(length(fractionsBefore)-1)-popMinSize*length(fractionsBefore);

  for i = 1:length(fractionEdgesBeforeWithDelta)
    if(i ==  1)
      fractionEdgesBeforeWithDelta(1, i) = 0;
      fractionEdgesAfterWithDelta(1, i) = 0;
    else
      fractionEdgesBeforeWithDelta(1, i) = fractionEdgesBeforeWithDelta(2, i-1)+delta;
      fractionEdgesAfterWithDelta(1, i) = fractionEdgesAfterWithDelta(2, i-1)+delta;
    end
    if(i == length(fractionEdgesBeforeWithDelta))
      fractionEdgesBeforeWithDelta(2, i) = 1;
      fractionEdgesAfterWithDelta(2, i) = 1;
    else
      fractionEdgesBeforeWithDelta(2, i) = ...
        fractionEdgesBeforeWithDelta(1, i) + fractionsBefore(i)*alpha+popMinSize;
      fractionEdgesAfterWithDelta(2, i) = ...
        fractionEdgesAfterWithDelta(1, i) + fractionsAfter(i)*alpha+popMinSize;
    end
  end

  fractionEdgesBefore = mean(fractionEdgesBeforeWithDelta);
  fractionEdgesAfter = mean(fractionEdgesAfterWithDelta);

  % Create the bars
  for i = 1:N
    xPatchBefore = [0 0 -1 -1]*barWidth+barPositions(1);
    yPatchBefore = [fractionEdgesBeforeWithDelta(1,i) fractionEdgesBeforeWithDelta(2,i) fractionEdgesBeforeWithDelta(2,i) fractionEdgesBeforeWithDelta(1,i)];
    xPatchAfter = [0 0 1 1]*barWidth+barPositions(2);
    yPatchAfter = [fractionEdgesAfterWithDelta(1,i) fractionEdgesAfterWithDelta(2,i) fractionEdgesAfterWithDelta(2,i) fractionEdgesAfterWithDelta(1,i)];
    P = patch(xPatchBefore, yPatchBefore, 'r');
    set(P,'facecolor', cmap(cmapvals(i),:),'linewidth',1, ...
      'edgecolor', cmap(cmapvals(i),:));
    if(barsBlackEdges)
      P.EdgeColor = 'k';
    end
    if(~params.showOnlyHalf)
      P = patch(xPatchAfter, yPatchAfter, 'r');
      set(P,'facecolor', cmap(cmapvals(i+N),:),'linewidth',1, ...
        'edgecolor', cmap(cmapvals(i+N),:));
      if(barsBlackEdges)
        P.EdgeColor = 'k';
      end
    end
  end

  patchSize = [];
  patchHandles = [];
  % Quick pass to get patchSizes and then do them in order
  for i = 1:N
    for j = 1:N
      fractionSizesBefore = diff(fractionEdgesBeforeWithDelta);
      fractionSizesAfter = diff(fractionEdgesAfterWithDelta);
      cumsumFractionsBefore = [0 cumsum(fractionTransfers(i, :, 1))];
      cumsumFractionsAfter = [0 cumsum(fractionTransfers(:, j, 2))'];

      f1 = fractionEdgesBeforeWithDelta(1, i)+fractionSizesBefore(i)*cumsumFractionsBefore(j);
      f2 = fractionEdgesBeforeWithDelta(1, i)+fractionSizesBefore(i)*cumsumFractionsBefore(j+1);
      f3 = fractionEdgesAfterWithDelta(1, j)+fractionSizesAfter(j)*cumsumFractionsAfter(i);
      f4 = fractionEdgesAfterWithDelta(1, j)+fractionSizesAfter(j)*cumsumFractionsAfter(i+1);
      patchSize = [patchSize; i, j, f2-f1];
    end
  end

  patchSize = sortrows(patchSize, -3);


  for pit = 1:size(patchSize, 1)
    if(patchSize(pit, 3) == 0)
      continue;
    end
    i = patchSize(pit, 1);
    j = patchSize(pit, 2);
    fractionSizesBefore = diff(fractionEdgesBeforeWithDelta);
    fractionSizesAfter = diff(fractionEdgesAfterWithDelta);
    cumsumFractionsBefore = [0 cumsum(fractionTransfers(i, :, 1))];
    cumsumFractionsAfter = [0 cumsum(fractionTransfers(:, j, 2))'];

    f1 = fractionEdgesBeforeWithDelta(1, i)+fractionSizesBefore(i)*cumsumFractionsBefore(j);
    f2 = fractionEdgesBeforeWithDelta(1, i)+fractionSizesBefore(i)*cumsumFractionsBefore(j+1);
    %%% CHANGED
    if(j == 1)
      f2 = f2-horBarGap;
    elseif(j == N)
      f1 = f1+horBarGap;
    else
      f1 = f1+horBarGap/2;
      f2 = f2-horBarGap/2;
    end
    f3 = fractionEdgesAfterWithDelta(1, j)+fractionSizesAfter(j)*cumsumFractionsAfter(i);
    f4 = fractionEdgesAfterWithDelta(1, j)+fractionSizesAfter(j)*cumsumFractionsAfter(i+1);

    radsBefore = [f1 f2];
    radsAfter = [f3 f4];

    xBefore = [1, 1]*barPositions(1)+barGap;
    %xAfter = ([1, 1]*barPositions(2)-barGap)*0-2*barGap; %%% CHANGED
    xEnd = [0,0]-params.leftRightGap/2;
    %[f3 f4]
    %xAfter = [f3, f3]/2;

    xAfter = fractionTransfers(i, j)/max(fractionTransfers(i,:,1))*(xEnd-xBefore)+xBefore;
    yBefore = [f1 f2];
    yAfter = [f1 f2]; %%% CHANGED

    [xLineDown, yLineDown] = getSigmoidConnection([xBefore(1) xAfter(1)], [yBefore(1) yAfter(1)], sigmoidPrefactor);
    [xLineUp, yLineUp] = getSigmoidConnection([xBefore(2) xAfter(2)], [yBefore(2) yAfter(2)], sigmoidPrefactor);

    patchX = [xLineDown xLineUp(end:-1:1)];
    patchY = [yLineDown yLineUp(end:-1:1)];

    % Now the interpolating line for colors
    [nxI, nyI] = getSigmoidConnection([mean(xBefore) mean(xAfter)], [mean(yBefore) mean(yAfter)], sigmoidPrefactor);
    initialColor = cmap(cmapvals(i), :);
    %finalColor = cmap(j+N, :);
    finalColor = cmap(cmapvals(j+N), :);

    cI = zeros(length(nxI), 3);
    for cc = 1:3
      if(params.mergeColors)
        cI(:, cc) = initialColor(cc)+(0:(length(nxI)-1))/(length(nxI)-1)*(finalColor(cc)-initialColor(cc));
      else
        cI(:, cc) = finalColor(cc);
      end
    end
    % Now get the associated patch interpolated color
    patchC = zeros(length(patchX), 1, 3);
    closestP = [1:size(cI,1), size(cI,1):-1:1];

    patchC(:, 1, :) = cI(closestP, :);

    P = patch(patchX', patchY', patchC);

    if(transitionsBlackEdges)
      P.EdgeColor = 'k';
    else
      set(P, 'edgecolor', 'none');
    end
    set(P, 'FaceAlpha', params.transparency);
    patchHandles = [patchHandles; P];


    % Now the texts
    %xt = barPositions(1)+barGap+radTextInnerGap;
    %xt = xAfter(1)-radTextInnerGap;
    xt = xAfter(1)+radTextInnerGap;
    yt = mean([f1 f2]);  
    switch params.countType
      case 'relative'
        newName = {fractionsNames{j}, sprintf('%.3g%%', 100*fractionTransfers(i, j, 1))};
      case 'absolute'
        newName = {fractionsNames{j}, sprintf('%d', populationsTransitions(i, j))};
    end
    a=text(xt, yt, newName, 'HorizontalAlignment', 'left', ...
      'FontSize', 12, 'FontWeight', 'bold', 'VerticalAlignment', 'middle');

    if(multipleInputs && params.showErrorBars)
      xAfterMin = (fractionTransfersMax(i, j)-fractionTransfersMin(i, j))/max(fractionTransfers(i,:,1))*(xEnd-xBefore);
      h = herrorbar(xAfter(1), yt, xAfterMin(1), xAfterMin(1));
      set(h, 'LineWidth', 1, 'Color', 'k');
    end
  end
  if(~params.showOnlyHalf)
    % Now do exactly the same with the other side
    for pit = 1:size(patchSize, 1)
      if(patchSize(pit, 3) == 0)
        continue;
      end
      i = patchSize(pit, 1);
      j = patchSize(pit, 2);
      fractionSizesBefore = diff(fractionEdgesBeforeWithDelta);
      fractionSizesAfter = diff(fractionEdgesAfterWithDelta);
      cumsumFractionsBefore = [0 cumsum(fractionTransfers(i, :, 1))];
      cumsumFractionsAfter = [0 cumsum(fractionTransfers(:, j, 2))'];

      f1 = fractionEdgesBeforeWithDelta(1, i)+fractionSizesBefore(i)*cumsumFractionsBefore(j);
      f2 = fractionEdgesBeforeWithDelta(1, i)+fractionSizesBefore(i)*cumsumFractionsBefore(j+1);
      f3 = fractionEdgesAfterWithDelta(1, j)+fractionSizesAfter(j)*cumsumFractionsAfter(i);
      f4 = fractionEdgesAfterWithDelta(1, j)+fractionSizesAfter(j)*cumsumFractionsAfter(i+1);
      %%% CHANGED
      if(i == 1)
        f4 = f4-horBarGap;
      elseif(i == N)
        f3 = f3+horBarGap;
      else
        f3 = f3+horBarGap/2;
        f4 = f4-horBarGap/2;
      end


      radsBefore = [f1 f2];
      radsAfter = [f3 f4];

      xAfter = [1, 1]*barPositions(2)-barGap;
      xEnd = [0,0]+params.leftRightGap/2;

      xBefore = fractionTransfers(i, j,2)/max(fractionTransfers(:,j,2))*(xEnd-xAfter)+xAfter;

      yBefore = [f3 f4]; %%% CHANGED
      yAfter = [f3 f4];

      [xLineDown, yLineDown] = getSigmoidConnection([xBefore(1) xAfter(1)], [yBefore(1) yAfter(1)], sigmoidPrefactor);
      [xLineUp, yLineUp] = getSigmoidConnection([xBefore(2) xAfter(2)], [yBefore(2) yAfter(2)], sigmoidPrefactor);

      patchX = [xLineDown xLineUp(end:-1:1)];
      patchY = [yLineDown yLineUp(end:-1:1)];

      % Now the interpolating line for colors
      [nxI, nyI] = getSigmoidConnection([mean(xBefore) mean(xAfter)], [mean(yBefore) mean(yAfter)], sigmoidPrefactor);
      initialColor = cmap(cmapvals(i), :);
      %finalColor = cmap(j+N, :);
      finalColor = cmap(cmapvals(j+N), :);

      cI = zeros(length(nxI), 3);
      for cc = 1:3
        if(params.mergeColors)
          cI(:, cc) = initialColor(cc)+(0:(length(nxI)-1))/(length(nxI)-1)*(finalColor(cc)-initialColor(cc));
        else
          cI(:, cc) = initialColor(cc);
        end
      end
      % Now get the associated patch interpolated color
      patchC = zeros(length(patchX), 1, 3);
      closestP = [1:size(cI,1), size(cI,1):-1:1];

      patchC(:, 1, :) = cI(closestP, :);

      P = patch(patchX', patchY', patchC);

      if(transitionsBlackEdges)
        P.EdgeColor = 'k';
      else
        set(P, 'edgecolor', 'none');
      end
      set(P, 'FaceAlpha', params.transparency);
      patchHandles = [patchHandles; P];

      % Now the texts
      %xt = barPositions(1)+barGap+radTextInnerGap;
      %xt = xAfter(1)-radTextInnerGap;
      xt = xBefore(1)-radTextInnerGap;
      yt = mean([f3 f4]);  
      switch params.countType
        case 'relative'
          newName = {fractionsNames{i}, sprintf('%.3g%%', 100*fractionTransfers(i, j, 2))};
        case 'absolute'
          newName = {fractionsNames{i}, sprintf('%d', populationsTransitions(i, j))};
      end
      a=text(xt, yt, newName, 'HorizontalAlignment', 'right', ...
        'FontSize', 12, 'FontWeight', 'bold', 'VerticalAlignment', 'middle');
      if(multipleInputs && params.showErrorBars)
        xAfterMin = (fractionTransfersMax(i, j, 2)-fractionTransfersMin(i, j, 2))/max(fractionTransfers(i,:,2))*(xEnd-xAfter);
        h = herrorbar(xBefore(1), yt, xAfterMin(1), xAfterMin(1));
        set(h, 'LineWidth', 1, 'Color', 'k');
      end
    end
  end
  % Now the main texts
  % First the titles
  text(barPositions(1)-barWidth, 1.05, beforeAfterNames{1}, 'HorizontalAlignment', 'left', ...
    'FontSize', 16, 'FontWeight', 'bold');
  if(~params.showOnlyHalf)
    text(barPositions(2)+barWidth, 1.05, beforeAfterNames{2}, 'HorizontalAlignment', 'right', ...
      'FontSize', 16, 'FontWeight', 'bold');
  end

  text(0, 1.1, titleName, 'HorizontalAlignment', 'center', ...
    'FontSize', 20, 'FontWeight', 'bold');


  % Now the populations
  textPosBefore = fractionEdgesBefore;
  textPosAfter = fractionEdgesAfter;

  for i = 1:N
      xt = barPositions(1)-barWidth-radTextGap;
      yt = textPosBefore(i);

      switch params.countType
        case 'relative'
          if(multipleInputs && params.showErrorBars)
            newName = {fractionsNames{i}; sprintf('%.3g%%',100*fractionsBefore(i)); sprintf('(%.1f)', 100*fractionsBefore(i)*populationsBeforeStd(i)/populationsBefore(i)/sqrt(Nrepeats))};
          else
            newName = {fractionsNames{i}; sprintf('%.3g%%',100*fractionsBefore(i))};
          end
        case 'absolute'
          if(multipleInputs && params.showErrorBars)
            newName = {fractionsNames{i}, sprintf('%d', populationsBefore(i)), sprintf('(%.0f)', populationsBeforeStd(i)/sqrt(Nrepeats))};
          else
            newName = {fractionsNames{i}; sprintf('%d',populationsBefore(i))};
          end
      end
      a=text(xt, yt, newName, 'HorizontalAlignment', 'right', ...
        'FontSize', 12, 'FontWeight', 'bold', 'VerticalAlignment', 'middle');
      xt = barPositions(2)+barWidth+radTextGap;
      yt = textPosAfter(i);
      if(~params.showOnlyHalf)
        switch params.countType
          case 'relative'
            if(multipleInputs && params.showErrorBars)
              newName = {fractionsNames{i}; sprintf('%.3g%%',100*fractionsAfter(i)); sprintf('(%.1f)', 100*fractionsAfter(i)*populationsAfterStd(i)/populationsAfter(i)/sqrt(Nrepeats))};
            else
              newName = {fractionsNames{i}; sprintf('%.3g%%',100*fractionsAfter(i))};
            end
          case 'absolute'
            if(multipleInputs && params.showErrorBars)
              newName = {fractionsNames{i}, sprintf('%d',populationsAfter(i)), sprintf('(%.0f)', populationsAfterStd(i)/sqrt(Nrepeats))};
            else
              newName = {fractionsNames{i}; sprintf('%d',populationsAfter(i))};
            end
        end
        text(xt, yt, newName, 'HorizontalAlignment', 'left', ...
          'FontSize', 12, 'FontWeight', 'bold', 'VerticalAlignment', 'middle');
      end
  end

  axis normal off;
end

%--------------------------------------------------------------------------
function plotSquares(populationsBefore, populationsTransitions, options)
  
  params = options.get();
  params.showErrors = params.showErrorBars;
%   params.useSameColors = false;
%   params.neuronsPerSquare = 2;
%   params.showErrors = false;
%   params.showOnlyHalf = true;
  %Ngap = params.neuronsPerSquare;
  Ngap = 1;
  
  N = size(populationsBefore, 2);
  baseMaxX = params.maxSquaresPerColumn;
  gap = 1;

  if(size(populationsBefore, 1) > 1 && size(populationsBefore, 2) > 1)
    Nrepeats = size(populationsTransitions, 3);
    populationsAfter = squeeze(sum(populationsTransitions, 1))';
    populationsAfterStd = std(populationsAfter);
    populationsAfter = round(mean(populationsAfter));
    minPopulationsAfter = populationsAfter-populationsAfterStd/sqrt(Nrepeats);
    maxPopulationsAfter = populationsAfter+populationsAfterStd/sqrt(Nrepeats);

    populationsBeforeStd = std(populationsBefore);
    populationsBefore = round(mean(populationsBefore, 1));
    minPopulationsBefore = populationsBefore-populationsBeforeStd/sqrt(Nrepeats);
    maxPopulationsBefore = populationsBefore+populationsBeforeStd/sqrt(Nrepeats);

    populationsTransitionsStd = std(populationsTransitions, [], 3);
    populationsTransitions = round(mean(populationsTransitions, 3));
    minPopulationsTransitions = populationsTransitions - populationsTransitionsStd/sqrt(Nrepeats);
    maxPopulationsTransitions = populationsTransitions + populationsTransitionsStd/sqrt(Nrepeats);

    multipleInputs = true;
  else
    populationsAfter = sum(populationsTransitions);
    if(size(populationsBefore, 1) > 1)
      populationsBefore = populationsBefore';
    end
    if(size(populationsAfter, 1) > 1)
      populationsAfter = populationsAfter';
    end
    multipleInputs = false;
  end


  fractionsBefore = populationsBefore/sum(populationsBefore);
  fractionsAfter = populationsAfter/sum(populationsAfter);
  if(multipleInputs)
    fractionTransfers = zeros(size(populationsBefore, 1), size(populationsBefore, 1), 2);
    fractionTransfersMin = zeros(size(populationsBefore, 1), size(populationsBefore, 1), 2);
    fractionTransfersMax = zeros(size(populationsBefore, 1), size(populationsBefore, 1), 2);

    for i = 1:size(populationsBefore, 2)
      for j = 1:size(populationsBefore, 2)
        fractionTransfers(i,j, :) = [populationsTransitions(i,j)/populationsBefore(i), populationsTransitions(i,j)/populationsAfter(j)];
        fractionTransfersMin(i,j, :) = [minPopulationsTransitions(i,j)/populationsBefore(i), minPopulationsTransitions(i,j)/populationsAfter(j)];
        fractionTransfersMax(i,j, :) = [maxPopulationsTransitions(i,j)/populationsBefore(i), maxPopulationsTransitions(i,j)/populationsAfter(j)];
      end
    end
  end

  Ncols = N;
  %cmap = eval([params.colormap '(Ncols+5)']);
  if(params.useSameColors)
    cmap = eval([params.colormap '(32)']);
    cmap = cmap(5:end-3, :);
    cmapvals = floor(linspace(1, length(cmap), Ncols));
    cmapvals = [cmapvals, cmapvals];
    Ncols = N*2;
  else
    Ncols = N*2;
    cmap = eval([params.colormap '(32)']);
    cmap = cmap(5:end-3, :);
    cmapvals = floor(linspace(1, length(cmap), Ncols));
    cmapvals = [cmapvals(1:2:end), cmapvals(2:2:end)];
  end


  cla(mainAxes)
  axes(mainAxes);
  
  hold on;
  axis equal;
  box on;

  delta = 0.;
  % Create the main populations
  curX = 0;


  firstPopX = zeros(N, 1);
  lastPopX = zeros(N, 1);
  maxPopY = zeros(N, 1);
  maxX = ones(N,1)*baseMaxX;
  for pop = 1:N
    if(pop > 1)
      curX = lastPopX(pop-1)+1;
    end
    curY = 0;
    firstPopX(pop) = curX;
    if(params.showErrors)
      cIterator = maxPopulationsBefore(pop);
    else
      cIterator = populationsBefore(pop);
    end
    for i = 1:Ngap:cIterator
      if((curX-firstPopX(pop)) >= maxX(pop))
        lastPopX(pop) = curX;
        curX = firstPopX(pop);
        curY = curY + 1;
        maxPopY(pop) = curY;
      end
      xPatchBefore = curX*gap + [0 1 1 0]+[1 -1 -1 1]*delta;
      yPatchBefore = curY*gap + [0 0 1 1]+[1 1 -1 -1]*delta;
      P = patch(xPatchBefore, yPatchBefore, cmap(cmapvals(pop),:));
      if(params.showErrors)
        if(i > minPopulationsBefore(pop) && i < populationsBefore(pop))
          P.FaceColor(P.FaceColor*1.3>1) = 1;
          P.FaceColor(P.FaceColor*1.3<1) = P.FaceColor(P.FaceColor*1.3<1)*1.3;
        end
        if(i == populationsBefore(pop))
          %P.FaceColor = cmap(cmapvals(pop),:)*0.;
        end
        if(i > populationsBefore(pop))
          P.FaceColor(P.FaceColor*1.3>1) = 1;
          P.FaceColor(P.FaceColor*1.3<1) = P.FaceColor(P.FaceColor*1.3<1)*1.3;
        end
      end

      if(params.barsBlackEdges)
        P.EdgeColor = 'k';
      else
        P.EdgeColor = cmap(cmapvals(pop),:);
      end
      curX = curX + 1;
      lastPopX(pop) = max(lastPopX(pop), curX);
    end
    curX = curX + 1;
  end

  % Set the names
  for pop = 1:N
    cx = mean([firstPopX(pop) lastPopX(pop)]);
    cy = maxPopY(pop)+1;
    if(params.showErrors)
      newName = {params.populationsNames{pop}, sprintf('%d', populationsBefore(pop)), sprintf('(%d)', round(populationsBeforeStd(pop)/sqrt(Nrepeats)))};
    else
      newName = {params.populationsNames{pop}, sprintf('%d', populationsBefore(pop))};
    end
    a=text(cx*gap, cy*gap, newName, 'HorizontalAlignment', 'center', ...
      'FontSize', 12, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');
  end
  centerXbefore = mean([firstPopX(1) lastPopX(end)]);
  maxYbefore = max(maxPopY);
  absoluteMinX = firstPopX(1);

  % Now the transitions

  firstPopTX = zeros(N, N);
  lastPopTX = zeros(N, N);
  maxPopTY = zeros(N, N);
  for popBefore = 1:N
    curX = firstPopX(popBefore);
    maxXT = ones(N,1)*baseMaxX/N;
    maxXT = min([populationsTransitions(popBefore, :)', maxXT],[],2);
    while(sum(maxXT)<baseMaxX && sum(maxXT) < sum(populationsTransitions(popBefore,:)'))
      [a, b]=max(populationsTransitions(popBefore, :)' - maxXT);
      maxXT(b) = maxXT(b)+1;
    end
    for popAfter = 1:N
      if(popAfter > 1)
        curX = lastPopTX(popBefore, popAfter-1);
      end
      curY = -2;
      maxPopTY(popBefore, popAfter) = curY;
      firstPopTX(popBefore, popAfter) = curX;
      if(params.showErrors)
        cIterator = maxPopulationsTransitions(popBefore, popAfter);
      else
        cIterator = populationsTransitions(popBefore, popAfter);
      end
      for i = 1:Ngap:cIterator
        if((curX-firstPopTX(popBefore, popAfter)) >= maxXT(popAfter))
          lastPopTX(popBefore, popAfter) = curX;
          curX = firstPopTX(popBefore, popAfter);
          curY = curY - 1;
          maxPopTY(popBefore, popAfter) = curY;
        end
        xPatchBefore = curX*gap + [0 1 1 0]+[1 -1 -1 1]*delta;
        yPatchBefore = curY*gap - [0 0 1 1]-[1 1 -1 -1]*delta;
        P = patch(xPatchBefore, yPatchBefore, cmap(cmapvals(popAfter+N),:));
        if(params.showErrors)
          if(i > minPopulationsTransitions(popBefore, popAfter) && i < populationsTransitions(popBefore, popAfter))
            P.FaceColor(P.FaceColor*1.3>1) = 1;
            P.FaceColor(P.FaceColor*1.3<1) = P.FaceColor(P.FaceColor*1.3<1)*1.3;
          end
          if(i == populationsTransitions(popBefore, popAfter))
            %P.FaceColor = cmap(cmapvals(pop),:)*1.;
          end
          if(i > populationsTransitions(popBefore, popAfter))
            P.FaceColor(P.FaceColor*1.3>1) = 1;
            P.FaceColor(P.FaceColor*1.3<1) = P.FaceColor(P.FaceColor*1.3<1)*1.3;
          end
        end

        if(params.barsBlackEdges)
          P.EdgeColor = 'k';
        else
          P.EdgeColor = cmap(cmapvals(popAfter+N),:);
          %P.EdgeColor = 'k';
        end
        curX = curX + 1;
        lastPopTX(popBefore, popAfter) = max(lastPopTX(popBefore, popAfter), curX);
      end
      curX = curX + 1;
    end
  end
  minY = min(maxPopTY(:));
  % Set the names
  for popBefore = 1:N  
    for popAfter = 1:N
      cx = mean([firstPopTX(popBefore, popAfter) lastPopTX(popBefore, popAfter)]);
      cy = maxPopTY(popBefore, popAfter)-1;
      if(params.showErrors)
        newName = {params.populationsNames{popAfter}, sprintf('%d', populationsTransitions(popBefore, popAfter)), sprintf('(%d)', round(populationsTransitionsStd(popBefore, popAfter)/sqrt(Nrepeats)))};
      else
        newName = {params.populationsNames{popAfter}, sprintf('%d', populationsTransitions(popBefore, popAfter))};
      end
      a=text(cx*gap, cy*gap, newName, 'HorizontalAlignment', 'center', ...
        'FontSize', 12, 'FontWeight', 'bold', 'VerticalAlignment', 'top');
    end
  end

  if(~params.showOnlyHalf)
    % Now the inverted plot
    firstPopX = zeros(N, 1)+lastPopX(end)+5;
    lastPopX = zeros(N, 1)+lastPopX(end)+5;
    maxPopY = zeros(N, 1);
    curX = firstPopX(1);
    maxXT = ones(N,1)*baseMaxX;
    maxXT = min([populationsAfter', maxXT],[],2);
    while(sum(maxXT)<baseMaxX && sum(maxXT) < sum(populationsAfter'))
      [a, b]=max(populationsAfter' - maxXT);
      maxXT(b) = maxXT(b)+1;
    end
    for pop = 1:N
      if(pop > 1)
        curX = lastPopX(pop-1)+1;
      end
      curY = -3;
      firstPopX(pop) = curX;
      if(params.showErrors)
        cIterator = maxPopulationsAfter(pop);
      else
        cIterator = populationsAfter(pop);
      end
      for i = 1:cIterator
        if((curX-firstPopX(pop)) >= maxX(pop))
          lastPopX(pop) = curX;
          curX = firstPopX(pop);
          curY = curY - 1;
          maxPopY(pop) = curY;
        end
        xPatchBefore = curX*gap + [0 1 1 0]+[1 -1 -1 1]*delta;
        yPatchBefore = curY*gap + [0 0 1 1]-[1 1 -1 -1]*delta;
        P = patch(xPatchBefore, yPatchBefore, cmap(cmapvals(pop+N),:));
        if(params.showErrors)
          if(i > minPopulationsAfter(pop) && i < populationsAfter(pop))
            P.FaceColor(P.FaceColor*1.3>1) = 1;
            P.FaceColor(P.FaceColor*1.3<1) = P.FaceColor(P.FaceColor*1.3<1)*1.3;
          end
          if(i == populationsAfter(pop))
            %P.FaceColor = cmap(cmapvals(pop),:)*0.;
          end
          if(i > populationsAfter(pop))
            P.FaceColor(P.FaceColor*1.3>1) = 1;
            P.FaceColor(P.FaceColor*1.3<1) = P.FaceColor(P.FaceColor*1.3<1)*1.3;
          end
        end

        if(params.barsBlackEdges)
          P.EdgeColor = 'k';
        else
          P.EdgeColor = cmap(cmapvals(pop+N),:);
          %P.EdgeColor = 'k';
        end
        curX = curX + 1;
        lastPopX(pop) = max(lastPopX(pop), curX);
      end
      curX = curX + 1;
    end

    minY = min([min(maxPopY(:)); maxPopTY(:)]);

    % Set the names
    for pop = 1:N
      cx = mean([firstPopX(pop) lastPopX(pop)]);
      cy = maxPopY(pop)-1;
      if(params.showErrors)
        newName = {params.populationsNames{pop}, sprintf('%d', populationsAfter(pop)), sprintf('(%d)', round(populationsAfterStd(pop)/sqrt(Nrepeats)))};
      else
        newName = {params.populationsNames{pop}, sprintf('%d', populationsAfter(pop))};
      end
      a=text(cx*gap, cy*gap, newName, 'HorizontalAlignment', 'center', ...
        'FontSize', 12, 'FontWeight', 'bold', 'VerticalAlignment', 'top');
    end

    centerXafter = mean([firstPopX(1) lastPopX(end)]);

    % Now the transitions
    firstPopTX = zeros(N, N);
    lastPopTX = zeros(N, N);
    maxPopTY = zeros(N, N);
    for popAfter = 1:N
      curX = firstPopX(popAfter);
      maxXT = ones(N,1)*baseMaxX/N;
      maxXT = min([populationsTransitions(:, popAfter), maxXT],[],2);
      while(sum(maxXT)<baseMaxX && sum(maxXT) < sum(populationsTransitions(:, popAfter)))
        [a, b]=max(populationsTransitions(:, popAfter) - maxXT);
        maxXT(b) = maxXT(b)+1;
      end
      for popBefore = 1:N
        if(popBefore > 1)
          curX = lastPopTX(popBefore-1, popAfter);
        end
        curY = 0;
        firstPopTX(popBefore, popAfter) = curX;
        maxPopTY(popBefore, popAfter) = curY;
        if(params.showErrors)
          cIterator = maxPopulationsTransitions(popBefore, popAfter);
        else
          cIterator = populationsTransitions(popBefore, popAfter);
        end
        for i = 1:cIterator
          if((curX-firstPopTX(popBefore, popAfter)) >= maxXT(popBefore))
            lastPopTX(popBefore, popAfter) = curX;
            curX = firstPopTX(popBefore, popAfter);
            curY = curY + 1;
            maxPopTY(popBefore, popAfter) = curY;
          end
          %[popBefore popAfter i curX curY]
          xPatchBefore = curX*gap + [0 1 1 0]+[1 -1 -1 1]*delta;
          yPatchBefore = curY*gap + [0 0 1 1]+[1 1 -1 -1]*delta;
          P = patch(xPatchBefore, yPatchBefore, cmap(cmapvals(popBefore),:));
          if(params.showErrors)
            if(i > minPopulationsTransitions(popBefore, popAfter) && i < populationsTransitions(popBefore, popAfter))
              P.FaceColor(P.FaceColor*1.3>1) = 1;
              P.FaceColor(P.FaceColor*1.3<1) = P.FaceColor(P.FaceColor*1.3<1)*1.3;
            end
            if(i == populationsTransitions(popBefore, popAfter))
              %P.FaceColor = cmap(cmapvals(pop),:)*1.;
            end
            if(i > populationsTransitions(popBefore, popAfter))
              P.FaceColor(P.FaceColor*1.3>1) = 1;
              P.FaceColor(P.FaceColor*1.3<1) = P.FaceColor(P.FaceColor*1.3<1)*1.3;
            end
          end

          if(params.barsBlackEdges)
            P.EdgeColor = 'k';
          else
            P.EdgeColor = cmap(cmapvals(popBefore),:);
            %P.EdgeColor = 'k';
          end
          curX = curX + 1;
          lastPopTX(popBefore, popAfter) = max(lastPopTX(popBefore, popAfter), curX);
        end
        curX = curX + 1;
      end
    end
    maxYafter = max(maxPopTY);
    % Set the names
    for popBefore = 1:N  
      for popAfter = 1:N
        cx = mean([firstPopTX(popBefore, popAfter) lastPopTX(popBefore, popAfter)]);
        cy = maxPopTY(popBefore, popAfter)+1;
        if(params.showErrors)
          newName = {params.populationsNames{popBefore}, sprintf('%d', populationsTransitions(popBefore, popAfter)), sprintf('(%d)', round(populationsTransitionsStd(popBefore, popAfter)/sqrt(Nrepeats)))};
        else
          newName = {params.populationsNames{popBefore}, sprintf('%d', populationsTransitions(popBefore, popAfter))};
        end
        a=text(cx*gap, cy*gap, newName, 'HorizontalAlignment', 'center', ...
          'FontSize', 12, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');
      end
    end

    absoluteMaxX = lastPopX(end);
    maxY = max([maxYbefore maxYafter]);

    centerX = mean([centerXbefore centerXafter]);
    % Now the titles
    text(centerX, maxY+4*gap, params.beforeAfterNames{1}, 'HorizontalAlignment', 'center', ...
      'FontSize', 16, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');
    text(centerX, minY-4*gap, params.beforeAfterNames{2}, 'HorizontalAlignment', 'center', ...
      'FontSize', 16, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');

    text(mean([centerXbefore*gap centerXafter*gap]), maxY+10*gap, params.title, 'HorizontalAlignment', 'center', ...
      'FontSize', 20, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');

  else
    maxYafter = maxYbefore;
    centerXafter = centerXbefore;
    maxY = max([maxYbefore maxYafter]);

    centerX = mean([centerXbefore centerXafter]);
    % Now the titles
    text(centerX, maxY+4*gap, params.beforeAfterNames{1}, 'HorizontalAlignment', 'center', ...
      'FontSize', 16, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');
    text(centerX, minY-4*gap, params.beforeAfterNames{2}, 'HorizontalAlignment', 'center', ...
      'FontSize', 16, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');

    text(mean([centerXbefore*gap centerXafter*gap]), maxY+10*gap, params.title, 'HorizontalAlignment', 'center', ...
      'FontSize', 20, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');
  end
  % The global names

  set(gca,'Units', 'normalized')
end

%--------------------------------------------------------------------------
function plotSquaresCompressed(populationsBefore, populationsTransitions, options)
  
  params = options.get();
  params.showErrors = params.showErrorBars;
  
  Ngap = 1;
  
  N = size(populationsBefore, 2);
  baseMaxX = params.maxSquaresPerColumn;
  gap = 1;

  if(size(populationsBefore, 1) > 1 && size(populationsBefore, 2) > 1)
    Nrepeats = size(populationsTransitions, 3);
    populationsAfter = squeeze(sum(populationsTransitions, 1))';
    populationsAfterStd = std(populationsAfter);
    populationsAfter = round(mean(populationsAfter));
    minPopulationsAfter = populationsAfter-populationsAfterStd/sqrt(Nrepeats);
    maxPopulationsAfter = populationsAfter+populationsAfterStd/sqrt(Nrepeats);

    populationsBeforeStd = std(populationsBefore);
    populationsBefore = round(mean(populationsBefore, 1));
    minPopulationsBefore = populationsBefore-populationsBeforeStd/sqrt(Nrepeats);
    maxPopulationsBefore = populationsBefore+populationsBeforeStd/sqrt(Nrepeats);

    populationsTransitionsStd = std(populationsTransitions, [], 3);
    populationsTransitions = round(mean(populationsTransitions, 3));
    minPopulationsTransitions = populationsTransitions - populationsTransitionsStd/sqrt(Nrepeats);
    maxPopulationsTransitions = populationsTransitions + populationsTransitionsStd/sqrt(Nrepeats);

    multipleInputs = true;
  else
    populationsAfter = sum(populationsTransitions);
    if(size(populationsBefore, 1) > 1)
      populationsBefore = populationsBefore';
    end
    if(size(populationsAfter, 1) > 1)
      populationsAfter = populationsAfter';
    end
    multipleInputs = false;
  end


  fractionsBefore = populationsBefore/sum(populationsBefore);
  fractionsAfter = populationsAfter/sum(populationsAfter);
  if(multipleInputs)
    fractionTransfers = zeros(size(populationsBefore, 1), size(populationsBefore, 1), 2);
    fractionTransfersMin = zeros(size(populationsBefore, 1), size(populationsBefore, 1), 2);
    fractionTransfersMax = zeros(size(populationsBefore, 1), size(populationsBefore, 1), 2);

    for i = 1:size(populationsBefore, 2)
      for j = 1:size(populationsBefore, 2)
        fractionTransfers(i,j, :) = [populationsTransitions(i,j)/populationsBefore(i), populationsTransitions(i,j)/populationsAfter(j)];
        fractionTransfersMin(i,j, :) = [minPopulationsTransitions(i,j)/populationsBefore(i), minPopulationsTransitions(i,j)/populationsAfter(j)];
        fractionTransfersMax(i,j, :) = [maxPopulationsTransitions(i,j)/populationsBefore(i), maxPopulationsTransitions(i,j)/populationsAfter(j)];
      end
    end
  end

  Ncols = N;
  %cmap = eval([params.colormap '(Ncols+5)']);
  if(params.useSameColors)
    cmap = eval([params.colormap '(32)']);
    cmap = cmap(5:end-3, :);
    cmapvals = floor(linspace(1, length(cmap), Ncols));
    cmapvals = [cmapvals, cmapvals];
    Ncols = N*2;
  else
    Ncols = N*2;
    cmap = eval([params.colormap '(32)']);
    cmap = cmap(5:end-3, :);
    cmapvals = floor(linspace(1, length(cmap), Ncols));
    cmapvals = [cmapvals(1:2:end), cmapvals(2:2:end)];
  end


  cla(mainAxes)
  axes(mainAxes);
  
  hold on;
  axis equal;
  box on;

  delta = 0.;
  % Create the main populations
  curX = 0;

  cumSumPopulations = cumsum(populationsTransitions,2);
  
  firstPopX = zeros(N, 1);
  lastPopX = zeros(N, 1);
  maxPopY = zeros(N, 1);
  maxX = ones(N,1)*baseMaxX;
  for pop = 1:N
    if(pop > 1)
      curX = lastPopX(pop-1)+1;
    end
    curY = 0;
    firstPopX(pop) = curX;
    if(params.showErrors)
      cIterator = maxPopulationsBefore(pop);
    else
      cIterator = populationsBefore(pop);
    end
    for i = 1:Ngap:cIterator
      if((curX-firstPopX(pop)) >= maxX(pop))
        lastPopX(pop) = curX;
        curX = firstPopX(pop);
        curY = curY + 1;
        maxPopY(pop) = curY;
      end
      xPatchBefore = curX*gap + [0 1 1 0]+[1 -1 -1 1]*delta;
      yPatchBefore = curY*gap + [0 0 1 1]+[1 1 -1 -1]*delta;
      curTransition = find(cumSumPopulations(pop, :) > i, 1, 'first');
      if(isempty(curTransition))
        curTransition = N;
      end
      P = patch(xPatchBefore, yPatchBefore, cmap(cmapvals(curTransition+N),:));
      if(params.showErrors)
        if(i > minPopulationsBefore(pop) && i < populationsBefore(pop))
          P.FaceColor(P.FaceColor*1.3>1) = 1;
          P.FaceColor(P.FaceColor*1.3<1) = P.FaceColor(P.FaceColor*1.3<1)*1.3;
        end
        if(i == populationsBefore(pop))
          %P.FaceColor = cmap(cmapvals(pop),:)*0.;
        end
        if(i > populationsBefore(pop))
          P.FaceColor(P.FaceColor*1.3>1) = 1;
          P.FaceColor(P.FaceColor*1.3<1) = P.FaceColor(P.FaceColor*1.3<1)*1.3;
        end
      end

      if(params.barsBlackEdges)
        P.EdgeColor = 'k';
      else
        P.EdgeColor = cmap(cmapvals(curTransition+N),:)*0.25;
      end
      curX = curX + 1;
      lastPopX(pop) = max(lastPopX(pop), curX);
    end
    curX = curX + 1;
  end

  % Set the names
  for pop = 1:N
    cx = mean([firstPopX(pop) lastPopX(pop)]);
    cy = maxPopY(pop)+1;
    if(params.showErrors)
      newName = {params.populationsNames{pop}, sprintf('%d', populationsBefore(pop)), sprintf('(%d)', round(populationsBeforeStd(pop)/sqrt(Nrepeats)))};
    else
      newName = {params.populationsNames{pop}, sprintf('%d', populationsBefore(pop))};
    end
    a=text(cx*gap, cy*gap, newName, 'HorizontalAlignment', 'center', ...
      'FontSize', 12, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');
    
    cx = 0;
    cy = -5;
    for j = 1:3
      for k = 1:3
        xPatchBefore = (cx+j-1)*gap + [0 1 1 0]+[1 -1 -1 1]*delta;
        yPatchBefore = cy-(pop-1)*4*gap-(k-1)*gap + [0 0 1 1]+[1 1 -1 -1]*delta;

        P = patch(xPatchBefore, yPatchBefore, cmap(cmapvals(pop+N),:));
        if(params.barsBlackEdges)
          P.EdgeColor = 'k';
        else
          P.EdgeColor = cmap(cmapvals(pop+N),:)*0.25;
        end
      end
    end
    a=text((cx+j+1)*gap, cy-(pop-1)*4*gap+0.5-1*gap, [params.populationsNames{pop} ' after treatment'], 'HorizontalAlignment', 'left', ...
      'FontSize', 12, 'FontWeight', 'bold', 'VerticalAlignment', 'middle');
  end
  centerXbefore = mean([firstPopX(1) lastPopX(end)]);
  maxYbefore = max(maxPopY);
  absoluteMinX = firstPopX(1);

  
  if(~params.showOnlyHalf)
    cumSumPopulations = cumsum(populationsTransitions,1);
    % Now the inverted plot
    firstPopX = zeros(N, 1)+lastPopX(end)+15;
    lastPopX = zeros(N, 1)+lastPopX(end)+15;
    maxPopY = zeros(N, 1);
    curX = firstPopX(1);
    maxXT = ones(N,1)*baseMaxX;
    maxXT = min([populationsAfter', maxXT],[],2);
    while(sum(maxXT)<baseMaxX && sum(maxXT) < sum(populationsAfter'))
      [a, b]=max(populationsAfter' - maxXT);
      maxXT(b) = maxXT(b)+1;
    end
    for pop = 1:N
      if(pop > 1)
        curX = lastPopX(pop-1)+1;
      end
      curY = 0;
      firstPopX(pop) = curX;
      if(params.showErrors)
        cIterator = maxPopulationsAfter(pop);
      else
        cIterator = populationsAfter(pop);
      end
      for i = 1:cIterator
        if((curX-firstPopX(pop)) >= maxX(pop))
          lastPopX(pop) = curX;
          curX = firstPopX(pop);
          curY = curY + 1;
          maxPopY(pop) = curY;
        end
        xPatchBefore = curX*gap + [0 1 1 0]+[1 -1 -1 1]*delta;
        yPatchBefore = curY*gap + [0 0 1 1]-[1 1 -1 -1]*delta;
        curTransition = find(cumSumPopulations(:, pop) > i, 1, 'first');
        if(isempty(curTransition))
          curTransition = N;
        end
        P = patch(xPatchBefore, yPatchBefore, cmap(cmapvals(curTransition),:));
        if(params.showErrors)
          if(i > minPopulationsAfter(pop) && i < populationsAfter(pop))
            P.FaceColor(P.FaceColor*1.3>1) = 1;
            P.FaceColor(P.FaceColor*1.3<1) = P.FaceColor(P.FaceColor*1.3<1)*1.3;
          end
          if(i == populationsAfter(pop))
            %P.FaceColor = cmap(cmapvals(pop),:)*0.;
          end
          if(i > populationsAfter(pop))
            P.FaceColor(P.FaceColor*1.3>1) = 1;
            P.FaceColor(P.FaceColor*1.3<1) = P.FaceColor(P.FaceColor*1.3<1)*1.3;
          end
        end

        if(params.barsBlackEdges)
          P.EdgeColor = 'k';
        else
          P.EdgeColor = cmap(cmapvals(curTransition),:)*0.25;
          %P.EdgeColor = 'k';
        end
        curX = curX + 1;
        lastPopX(pop) = max(lastPopX(pop), curX);
      end
      curX = curX + 1;
    end
    maxYafter = max(maxPopY);
    minY = min(min(maxPopY(:)));

    % Set the names
    for pop = 1:N
      cx = mean([firstPopX(pop) lastPopX(pop)]);
      cy = maxPopY(pop)+1;
      if(params.showErrors)
        newName = {params.populationsNames{pop}, sprintf('%d', populationsAfter(pop)), sprintf('(%d)', round(populationsAfterStd(pop)/sqrt(Nrepeats)))};
      else
        newName = {params.populationsNames{pop}, sprintf('%d', populationsAfter(pop))};
      end
      a=text(cx*gap, cy*gap, newName, 'HorizontalAlignment', 'center', ...
        'FontSize', 12, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');
      
      cx = firstPopX(1);
      cy = -5;
      for j = 1:3
        for k = 1:3
          xPatchBefore = (cx+j-1)*gap + [0 1 1 0]+[1 -1 -1 1]*delta;
          yPatchBefore = cy-(pop-1)*4*gap-(k-1)*gap + [0 0 1 1]+[1 1 -1 -1]*delta;

          P = patch(xPatchBefore, yPatchBefore, cmap(cmapvals(pop),:));
          if(params.barsBlackEdges)
            P.EdgeColor = 'k';
          else
            P.EdgeColor = cmap(cmapvals(pop),:)*0.25;
          end
        end
      end
      a=text((cx+j+1)*gap, cy-(pop-1)*4*gap+0.5-1*gap, [params.populationsNames{pop} ' before treatment'], 'HorizontalAlignment', 'left', ...
        'FontSize', 12, 'FontWeight', 'bold', 'VerticalAlignment', 'middle');
    end

    centerXafter = mean([firstPopX(1) lastPopX(end)]);

    maxY = max([maxYbefore maxYafter]);
    

    centerX = mean([centerXbefore centerXafter]);
    % Now the titles
    text(centerXbefore, maxY+4*gap, params.beforeAfterNames{1}, 'HorizontalAlignment', 'center', ...
      'FontSize', 16, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');
    text(centerXafter, maxY+4*gap, params.beforeAfterNames{2}, 'HorizontalAlignment', 'center', ...
      'FontSize', 16, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');

    text(mean([centerXbefore*gap centerXafter*gap]), maxY+10*gap, params.title, 'HorizontalAlignment', 'center', ...
      'FontSize', 20, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');

  else

    centerXafter = centerXbefore;
    maxY = max(maxYbefore);

    %centerX = mean([centerXbefore centerXafter]);
    % Now the titles
    
%     text(centerXbefore, maxY+4*gap, params.beforeAfterNames{1}, 'HorizontalAlignment', 'center', ...
%       'FontSize', 16, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');
%     text(centerXafter, maxY+4*gap, params.beforeAfterNames{2}, 'HorizontalAlignment', 'center', ...
%       'FontSize', 16, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');

    text(mean([centerXbefore*gap centerXafter*gap]), maxY+10*gap, params.title, 'HorizontalAlignment', 'center', ...
      'FontSize', 20, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');
  end
  % The global names

  set(gca,'Units', 'normalized')
end

%--------------------------------------------------------------------------
function updateMenus()
    
end

%--------------------------------------------------------------------------
function updateImage()
  axis tight off;
  axis auto;
  xl = xlim;
  yl = ylim;
  itemList = findobj(gca,'-property','Position', 'Type', 'text');
  minX = min([xl(:); arrayfun(@(x)x.Position(1), itemList)]);
  maxX = max([xl(:); arrayfun(@(x)x.Position(1), itemList)]);
  minY = min([yl(:); arrayfun(@(x)x.Position(2), itemList)]);
  maxY = max([yl(:); arrayfun(@(x)x.Position(2), itemList)]);
  
  width = maxX-minX;
  height = maxY-minY;
%   if(minX < 0)
%     xmults = [1.1 1.1];
%   else
%     xmults = [0.9 1.1];
%   end
%   if(minY < 0)
%     ymults = [1.1 1.1];
%   else
%     ymults = [0.9 1.1];
%   end
  xlim([minX maxX]+[-1 1]*width/10);
  ylim([minY maxY]+[-1 1]*height/10);
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
