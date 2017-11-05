function [hFigW, experiment] = traceFixer(experiment)
% TRACEFIXER fixes fluctuations on the traces
%
% USAGE:
%    traceFixer(gui, experiment)
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
%    hFigW = traceFixer(gui, experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
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
experiment = loadTraces(experiment, 'raw');
[success, traceFixerOptionsCurrent] = preloadOptions(experiment, traceFixerOptions, gui, false, false);
experiment.traceFixerOptionsCurrent = traceFixerOptionsCurrent;
originalExperiment = experiment;

if(~isempty(gui))
  project = getappdata(gui, 'project');
else
  project = [];
end

lastID = 0;
meanDiffTraces = diff(mean(experiment.rawTraces,2));
manualSelection = false;
invalidPoints = [];
newMeanTrace = [];
correctionSignal = [];
avgSignal = [];
invalidThreshold = [];
correctedMeanTrace = [];

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
                       'Name', ['Trace fixer: ' experiment.name]);
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
axesParent = uicontainer('Parent', hs.mainWindowFramesPanel);
hs.mainWindowFramesAxesTop = subplot(3, 1, 1, 'Parent', axesParent);
set(hs.mainWindowFramesAxesTop, 'ButtonDownFcn', @rightClick);
hs.mainWindowFramesAxesMiddle = subplot(3, 1, 2, 'Parent', axesParent);
hs.mainWindowFramesAxesBottom = subplot(3, 1, 3, 'Parent', axesParent);

% Pages buttons -----------------------------------------------------------
% Below image panel
%uix.Empty('Parent', hs.mainWindowGrid);
hs.mainWindowBottom = uix.VBox( 'Parent', hs.mainWindowGrid);
hs.mainWindowBottomButtons = uix.HButtonBox( 'Parent', hs.mainWindowBottom);
uicontrol('Parent', hs.mainWindowBottomButtons, 'Style', 'togglebutton', 'String', 'Manual fixer', 'FontSize', textFontSize, 'callback', @manualSelectionButton);
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'Automatic fixer', 'FontSize', textFontSize, 'callback', @fixerOptions);
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'Trace preview', 'FontSize', textFontSize, 'callback', @fixPreview);
uicontrol('Parent', hs.mainWindowBottomButtons, 'String', 'Apply current fix', 'FontSize', textFontSize, 'callback', @applyFix);

set(hs.mainWindowBottomButtons, 'ButtonSize', [150 15], 'Padding', 0, 'Spacing', 15);
%uix.Empty('Parent', hs.mainWindowBottom);
set(hs.mainWindowBottom, 'Heights', -1, 'Padding', 5, 'Spacing', 10);

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
  'Heights', [minGridBorder -1 35 100 minGridBorder]);

try
  if(~isfield(experiment, 'invalidPointsFixer'))
    preFix();
  else
    invalidPoints = experiment.invalidPointsFixer;
    preFixCorrection();
  end
catch
end
cleanMenu();
updateMenus();
setappdata(hFigW, 'currentOrder', currentOrder);

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
function resizeCallback(~, ~)
  updateImage();
end

%--------------------------------------------------------------------------
function exportTraces(~, ~)
    exportFigCallback([], [], {'*.png';'*.tiff'}, [experiment.folder 'traceFixer_' selectionTitle]);
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
function rightClick(hObject, eventData, ~)
  
  if(manualSelection)
    clickedPoint = get(hs.mainWindowFramesAxesTop,'currentpoint');

    [~, closestT] = min(abs(experiment.rawT-clickedPoint(1)));
    
    % For now, without range
     closestTrange = experiment.traceFixerOptionsCurrent.expansionInterval;
     if(length(closestTrange) == 2)
      closestTrange = closestTrange(1):closestTrange(2);
      closestT = closestT+closestTrange;
     else
       for it = 1:length(closestTrange)
         closestT = [closestT; closestT+closestTrange(it)];
       end
     end
     
     closestT = unique(closestT(:));

    % If all the selected points are there, remove them. If not, add them
    alreadyExists = [];
    for it = 1:length(closestT)
      alreadyExists = [alreadyExists; find(closestT(it) == invalidPoints)];
    end

    if(length(alreadyExists) == length(closestT))
      invalidPoints(alreadyExists) = [];
      preFixCorrection();
      updateImage(true);
    else
      invalidPoints = unique([invalidPoints; closestT]);
      experiment.invalidPointsFixer = invalidPoints;
      preFixCorrection();
      updateImage(true);
    end

    %updateImage();
  end
end

%--------------------------------------------------------------------------
function manualSelectionButton(hObject, ~)
  if(hObject.Value == 1)
    manualSelection = true;
    updateImage(true);
  else
    manualSelection = false;
    updateImage(true);
  end
end

%--------------------------------------------------------------------------
function fixerOptions(~, ~)
  [success, traceFixerOptionsCurrent, experiment] = preloadOptions(experiment, traceFixerOptions, gui, true, false);
  if(success)
    experiment.traceFixerOptionsCurrent = traceFixerOptionsCurrent;
    % The fix itself
    preFix();
    updateImage(true);
  end
end

%--------------------------------------------------------------------------
function applyFix(~, ~)
  msg = 'Are you sure? This will overwrite the rawTraces. This operation cannot be undone (unless you extract the traces again)';
  choice = questdlg(msg, 'Apply fix', ...
                       'Yes', 'No', 'Cancel', 'Cancel');
  switch choice
    case 'Yes'
      exp = experiment;
      diffTraces = diff(exp.rawTraces);
      invalidJump = diffTraces(invalidPoints, :);

      ncbar('Fixing traces');
      %%% NEW VERSION
      if(length(experiment.traceFixerOptionsCurrent.expansionInterval) == 2)
        N = length(experiment.traceFixerOptionsCurrent.expansionInterval(1):experiment.traceFixerOptionsCurrent.expansionInterval(2));
      else
        N = length(experiment.traceFixerOptionsCurrent.expansionInterval);
      end
      baseLineLevel = max(round(N*0.5), 10);
      t = invalidPoints';
      x = diff(t)==1;
      f = find([false,x]~=[x,false]);
      g = find(f(2:2:end)-f(1:2:end-1) + 1 >= N);
      first_t = t(f(2*g-1));
      last_t = t(f(2*g));

      for it2 = 1:size(exp.rawTraces, 2)
        correctedT = exp.rawTraces(:, it2);
        for it = 1:length(first_t)
          prevBase = mean(correctedT((first_t(it)-baseLineLevel):(first_t(it))));
          nextBase = mean(correctedT(last_t(it):(last_t(it)+baseLineLevel)));

          [~, closestFirsT] = min(abs(correctedT(first_t(it):(first_t(it)+baseLineLevel)) - prevBase));
          closestFirsT = closestFirsT + first_t(it) - 1;

          [~, closestLastT] = min(abs(correctedT((last_t(it)-baseLineLevel):last_t(it)) - nextBase));
          closestLastT = closestLastT + last_t(it) - baseLineLevel - 1;

    %      jumpBase = correctedT(closestLastT)-correctedT(closestFirsT);

          correctedT(closestFirsT:closestLastT) = prevBase;
          correctedT((closestLastT+1):end) = correctedT((closestLastT+1):end) - (nextBase-prevBase);
        end
        exp.rawTraces(:, it2) = correctedT;
        ncbar.update(it2/size(exp.rawTraces, 2));
      end
      ncbar.close();

      % Now the corrected traces
      if(isfield(exp, 'traces'))
        exp = smoothTraces(exp, exp.smoothTracesOptionsCurrent, 'traceFixCorrection', invalidPoints, 'traceFixCorrectionOptions', experiment.traceFixerOptionsCurrent);
      end

      experiment = exp;
      experiment.saveBigFields = true; % So the traces are saved
      
      preFix();
      updateImage();
      
    case 'No'
      return;
    case 'Cancel'
      return;
    otherwise
      return;
  end
end


%--------------------------------------------------------------------------
function fixPreview(~, ~)
  
  exp = experiment;
  exp.virtual = true;

  ncbar('Fixing traces');
  %%% NEW VERSION
  if(length(experiment.traceFixerOptionsCurrent.expansionInterval) == 2)
    N = length(experiment.traceFixerOptionsCurrent.expansionInterval(1):experiment.traceFixerOptionsCurrent.expansionInterval(2));
  else
    N = length(experiment.traceFixerOptionsCurrent.expansionInterval);
  end
  baseLineLevel = max(round(N*0.5), 10);
  t = invalidPoints';
  x = diff(t)==1;
  f = find([false,x]~=[x,false]);
  g = find(f(2:2:end)-f(1:2:end-1) + 1 >= N);
  first_t = t(f(2*g-1));
  last_t = t(f(2*g));
  
  for it2 = 1:size(exp.rawTraces, 2)
    correctedT = exp.rawTraces(:, it2);
    for it = 1:length(first_t)
      prevBase = mean(correctedT((first_t(it)-baseLineLevel):(first_t(it))));
      nextBase = mean(correctedT(last_t(it):(last_t(it)+baseLineLevel)));
      
      [~, closestFirsT] = min(abs(correctedT(first_t(it):(first_t(it)+baseLineLevel)) - prevBase));
      closestFirsT = closestFirsT + first_t(it) - 1;
      
      [~, closestLastT] = min(abs(correctedT((last_t(it)-baseLineLevel):last_t(it)) - nextBase));
      closestLastT = closestLastT + last_t(it) - baseLineLevel - 1;
      
%      jumpBase = correctedT(closestLastT)-correctedT(closestFirsT);

      correctedT(closestFirsT:closestLastT) = prevBase;
      correctedT((closestLastT+1):end) = correctedT((closestLastT+1):end) - (nextBase-prevBase);
    end
    exp.rawTraces(:, it2) = correctedT;
    ncbar.update(it2/size(exp.rawTraces, 2));
  end
  ncbar.close();
  
  % Now the corrected traces
  if(isfield(exp, 'traces'))
    exp = smoothTraces(exp, exp.smoothTracesOptionsCurrent, 'traceFixCorrection', invalidPoints, 'traceFixCorrectionOptions', experiment.traceFixerOptionsCurrent);
  end
  viewTraces(exp);

end

%%
%% Total Variation Denoising
%detectionMethod
% y = experiment.avgTrace;
% lambda = .2;
% %where K is a vectorial gradient and norm(u,1) is a vectorial L1 norme.
% 
% K = @(x)grad(x);
% KS = @(x)-div(x);
% %It can be put as the minimization of F(K*x) + G(x)
% 
% Amplitude = @(u)sqrt(sum(u.^2,3));
% F = @(u)lambda*sum(sum(Amplitude(u)));
% G = @(x)1/2*norm(y-x,'fro')^2;
% %The proximity operator of F is the vectorial soft thresholding.
% 
% Normalize = @(u)u./repmat( max(Amplitude(u),1e-10), [1 1 2] );
% ProxF = @(u,tau)repmat( perform_soft_thresholding(Amplitude(u),lambda*tau), [1 1 2]).*Normalize(u);
% ProxFS = compute_dual_prox(ProxF);
% %The proximity operator of G.
% 
% ProxG = @(x,tau)(x+tau*y)/(1+tau);
% %Function to record progression of the functional.
% 
% options.report = @(x)G(x) + F(K(x));
% %Run the ADMM algorihtm.
% 
% options.niter = 300;
% [xAdmm,EAdmm] = perform_admm(y, K,  KS, ProxFS, ProxG, options);
% %[********************]
% %Display image.
% 
% %clf;
% %imageplot(xAdmm);
% 
% figure;
% plot(y);
% hold on;
% plot(xAdmm);
% legend('orig','xad');

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
    oldXL = hs.mainWindowFramesAxesTop.XLim;
    oldYL = hs.mainWindowFramesAxesTop.YLim;
  end
  axes(hs.mainWindowFramesAxesTop);
  if(~keepAxis)
    cla(hs.mainWindowFramesAxesTop);
  else
    cla(hs.mainWindowFramesAxesTop);
  end
  set(hs.mainWindowFramesAxesTop, 'ButtonDownFcn', @rightClick);
  
  if(manualSelection)
    plot(experiment.rawT, newMeanTrace,'.-', 'HitTest', 'off');
  else
    plot(experiment.rawT, newMeanTrace,'-', 'HitTest', 'off');
  end
  hold on;
  plot(experiment.rawT(invalidPoints), newMeanTrace(invalidPoints) ,'ro', 'HitTest', 'off');
  xlabel('time (s)');
  ylabel('avg F');
  box on;
  legend('original', 'correction points');
  if(keepAxis)
    xlim(oldXL);
    ylim(oldYL);
  else
    xlim([experiment.rawT(1), experiment.rawT(end)]);
  end
  
  axes(hs.mainWindowFramesAxesMiddle);
  if(~keepAxis)
    cla(hs.mainWindowFramesAxesMiddle);
  else
    cla(hs.mainWindowFramesAxesMiddle);
  end
  
  plot(experiment.rawT(1:end-1), avgSignal);
  hold on;
  plot(experiment.rawT(1:end-1), correctionSignal, 'r.-');
%   if(keepAxis)
%     xlim(oldXL);
%     ylim(oldYL);
%   else
%     xlim([experiment.rawT(1), experiment.rawT(end)]);
%   end
  xl = xlim;
  plot(xl, [1,1]*invalidThreshold, '-k');
  xlabel('time (s)');
  ylabel('sign coincidence');
  box on;
  legend('sign coincidence', 'correction points', 'threshold');

  axes(hs.mainWindowFramesAxesBottom);
  if(~keepAxis)
    cla(hs.mainWindowFramesAxesBottom);
  else
    cla(hs.mainWindowFramesAxesBottom);
  end

  plot(experiment.rawT, newMeanTrace,'-');
  hold on;
  plot(experiment.rawT, correctedMeanTrace,'-');
  xlabel('time (s)');
  ylabel('avg F');
%   if(keepAxis)
%     xlim(oldXL);
%     ylim(oldYL);
%   else
%     xlim([experiment.rawT(1), experiment.rawT(end)]);
%   end
  box on;
  legend('original', 'corrected');
  
  linkaxes([hs.mainWindowFramesAxesTop hs.mainWindowFramesAxesMiddle hs.mainWindowFramesAxesBottom], 'x');

end

%--------------------------------------------------------------------------
function preFix()
  switch experiment.traceFixerOptionsCurrent.detectionMethod
    case 'sign'
      % In case the experiment is old and signCoincidence does not exist
      if(~isfield(experiment, 'signCoincidence'))
        logMsg('signCoincidence field not found, computing it from the existing traces, but you might want to extract the traces again', 'w');
        diffTraces = diff(experiment.rawTraces);
        diffTracesB = diffTraces;
        diffTracesB(diffTraces > 0) = 1;
        diffTracesB(diffTraces < 0) = -1;
        experiment.signCoincidence = abs(sum(diffTracesB,2)/size(diffTracesB,2));
      end
      stdLimit = experiment.traceFixerOptionsCurrent.threshold;
      invalidRange = experiment.traceFixerOptionsCurrent.expansionInterval;
      if(numel(invalidRange) == 2)
        invalidRange = invalidRange(1):invalidRange(2);
      end

      avgSignal = experiment.signCoincidence;
      switch experiment.traceFixerOptionsCurrent.thresholdType
        case 'relative'
          invalidThreshold = mean(avgSignal)+stdLimit*std(avgSignal);
        case 'absolute'
          invalidThreshold = stdLimit;
      end
    case 'TVD'
      ncbar('Running Total Variation Denoising');
      ncbar.setAutomaticBar();
      y = mean(experiment.rawTraces, 2);
      %lambda = .2;
      lambda = 2;
      %where K is a vectorial gradient and norm(u,1) is a vectorial L1 norme.

      K = @(x)grad(x);
      KS = @(x)-div(x);
      %It can be put as the minimization of F(K*x) + G(x)

      Amplitude = @(u)sqrt(sum(u.^2,3));
      F = @(u)lambda*sum(sum(Amplitude(u)));
      G = @(x)1/2*norm(y-x,'fro')^2;
      %The proximity operator of F is the vectorial soft thresholding.

      Normalize = @(u)u./repmat( max(Amplitude(u),1e-10), [1 1 2] );
      ProxF = @(u,tau)repmat( perform_soft_thresholding(Amplitude(u),lambda*tau), [1 1 2]).*Normalize(u);
      ProxFS = compute_dual_prox(ProxF);
      %The proximity operator of G.

      ProxG = @(x,tau)(x+tau*y)/(1+tau);
      %Function to record progression of the functional.

      options.report = @(x)G(x) + F(K(x));
      %Run the ADMM algorihtm.

      options.niter = 300;
      
      [xAdmm,EAdmm] = perform_admm(y, K,  KS, ProxFS, ProxG, options);

      avgSignal = abs(diff(xAdmm));

      stdLimit = experiment.traceFixerOptionsCurrent.threshold;

      invalidRange = experiment.traceFixerOptionsCurrent.expansionInterval;
      if(numel(invalidRange) == 2)
        invalidRange = invalidRange(1):invalidRange(2);
      end
      switch experiment.traceFixerOptionsCurrent.thresholdType
        case 'relative'
          invalidThreshold = mean(avgSignal)+stdLimit*std(avgSignal);
        case 'absolute'
          invalidThreshold = stdLimit;
      end
      ncbar.close();
  end

  invalid = find(avgSignal > invalidThreshold);

  newInvalid = [];
  
  for it = 1:length(invalidRange)
    newInvalid = [newInvalid; invalid+invalidRange(it)];
  end
  invalid = unique(newInvalid);
  invalidPoints = invalid;
  invalidPoints(invalidPoints < 1) = [];
  invalidPoints(invalidPoints > length(avgSignal)) = [];
  experiment.invalidPointsFixer = invalidPoints;
  preFixCorrection();
  updateImage();
end

function preFixCorrection()
  if(isempty(avgSignal))
    avgSignal = experiment.signCoincidence;
  end
  stdLimit = experiment.traceFixerOptionsCurrent.threshold;
  switch experiment.traceFixerOptionsCurrent.thresholdType
    case 'relative'
      invalidThreshold = mean(avgSignal)+stdLimit*std(avgSignal);
    case 'absolute'
      invalidThreshold = stdLimit;
  end
  %%% OLD VERSION
%   invalidJump = meanDiffTraces(invalidPoints);
% 
%   % Now the corrected trace
%   newMeanTrace = mean(experiment.rawTraces, 2);
%   correctedMeanTrace = mean(experiment.rawTraces, 2);
%   for it = 1:length(invalidPoints)
%     correctedMeanTrace(invalidPoints(it)+1:end) = correctedMeanTrace(invalidPoints(it)+1:end)-invalidJump(it);
%   end
% 
%   correctionSignal = nan(size(avgSignal));
%   correctionSignal(invalidPoints) = avgSignal(invalidPoints);

  %%% NEW VERSION
  if(length(experiment.traceFixerOptionsCurrent.expansionInterval) == 2)
    N = length(experiment.traceFixerOptionsCurrent.expansionInterval(1):experiment.traceFixerOptionsCurrent.expansionInterval(2));
  else
    N = length(experiment.traceFixerOptionsCurrent.expansionInterval);
  end
  baseLineLevel = max(round(N*0.5), 10);
  t = invalidPoints';
  x = diff(t)==1;
  f = find([false,x]~=[x,false]);
  g = find(f(2:2:end)-f(1:2:end-1) + 1 >= N);
  first_t = t(f(2*g-1));
  last_t = t(f(2*g));
  
  newMeanTrace = mean(experiment.rawTraces, 2);
  correctedMeanTrace = mean(experiment.rawTraces, 2);
  for it = 1:length(first_t)
    %prevBase = mean(correctedMeanTrace(first_t(it):(first_t(it)+baseLineLevel)));
    %nextBase = mean(correctedMeanTrace((last_t(it)-baseLineLevel):last_t(it)));
    prevBase = mean(correctedMeanTrace((first_t(it)-baseLineLevel):(first_t(it))));
    nextBase = mean(correctedMeanTrace(last_t(it):(last_t(it)+baseLineLevel)));
      
    [~, closestFirsT] = min(abs(correctedMeanTrace(first_t(it):(first_t(it)+baseLineLevel)) - prevBase));
    closestFirsT = closestFirsT + first_t(it) - 1;

    [~, closestLastT] = min(abs(correctedMeanTrace((last_t(it)-baseLineLevel):last_t(it)) - nextBase));
    closestLastT = closestLastT + last_t(it) - baseLineLevel - 1;

    %jumpBase = correctedT(closestLastT)-correctedT(closestFirsT);

    correctedMeanTrace(closestFirsT:closestLastT) = prevBase;
    correctedMeanTrace((closestLastT+1):end) = correctedMeanTrace((closestLastT+1):end) - (nextBase-prevBase);
      
  end
  correctionSignal = nan(size(avgSignal));
%   invalidJump = meanDiffTraces(invalidPoints);
% 
%   % Now the corrected trace
%   newMeanTrace = mean(experiment.rawTraces, 2);
%   correctedMeanTrace = mean(experiment.rawTraces, 2);
%   for it = 1:length(invalidPoints)
%     correctedMeanTrace(invalidPoints(it)+1:end) = correctedMeanTrace(invalidPoints(it)+1:end)-invalidJump(it);
%   end
% 
%   correctionSignal = nan(size(avgSignal));
%   correctionSignal(invalidPoints) = avgSignal(invalidPoints);
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
