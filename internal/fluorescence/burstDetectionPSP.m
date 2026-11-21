function experiment = burstDetectionPSP(experiment, varargin)
% BURSTDETECTIONPSP Based on powerspectrum of the avg trace
%
% USAGE:
%    experiment = burstDetectionPSP(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: burstDetectionXoptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = burstDetectionX(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% EXPERIMENT PIPELINE
% name: burst detection PSP
% parentGroups: fluorescence: bursts
% optionsClass: burstDetectionPSPoptions
% requiredFields: spikes, ROI, folder, name

[params, var] = processFunctionStartup(burstDetectionPSPoptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Detecting bursts', true);
%--------------------------------------------------------------------------

% Fix in case for some reason the group is a cell
if(iscell(params.group))
  mainGroup = params.group{1};
else
  mainGroup = params.group;
end
% Check if its a project or an experiment
switch params.saveOptions.saveBaseFolder
  case 'experiment'
    baseFolder = experiment.folder;
  case 'project'
    baseFolder = [experiment.folder '..' filesep];
  otherwise
    baseFolder = experiment.folder;
end
 
% Consistency checks
if(params.saveOptions.onlySaveFigure)
  params.saveOptions.saveFigure = true;
end
if(params.saveOptions.saveFigure)
  params.plotResults = true;
end
if(ischar(params.styleOptions.figureSize))
  params.styleOptions.figureSize = eval(params.styleOptions.figureSize);
end

% Create necessary folders
if(~exist(baseFolder, 'dir'))
  mkdir(baseFolder);
end
figFolder = [baseFolder 'figures' filesep];
if(~exist(figFolder, 'dir'))
  mkdir(figFolder);
end
exportFolder = [baseFolder 'exports' filesep];
if(~exist(exportFolder, 'dir'))
  mkdir(exportFolder);
end

% Get ALL subgroups in case of parents
if(strcmpi(mainGroup, 'all'))
  groupList = getExperimentGroupsNames(experiment);
else
  groupList = getExperimentGroupsNames(experiment, mainGroup);
end

% We will get the members later
switch params.tracesType
  case 'smoothed'
    experiment = loadTraces(experiment, 'normal');
    t = experiment.t;
    traces = experiment.traces;
  case 'raw'
    experiment = loadTraces(experiment, 'raw');
    t = experiment.rawT;
    traces = experiment.rawTraces;
  case 'denoised'
    experiment = loadTraces(experiment, 'rawTracesDenoised');
    t = experiment.rawTDenoised;
    traces = experiment.rawTraces;
end
origT = t;
% Empty check
if(isempty(groupList))
  logMsg(sprintf('Group %s not found on experiment %s', mainGroup, experiment.name), 'w');
  return;
end

% Time to iterate through all the groups
for git = 1:length(groupList)
  if(params.pbar > 0)
    ncbar.setBarTitle(sprintf('Detecting bursts from group: %s', groupList{git}));
  end
  if(strcmpi(groupList{git}, 'none'))
    members = 1:length(experiment.ROI);
    groupName = 'everything';
    groupIdx = 1;
  else
    [members, groupName, groupIdx] = getExperimentGroupMembers(experiment, groupList{git});
  end
  
  % Check for empty group
  if(isempty(members) && params.verbose)
    logMsg(sprintf('Found empty group: %s', groupList{git}), 'w');
    continue;
  end
  
  % Get the avg trace
  avgT = mean(traces(:, members), 2);
  Fs = t(2)-t(1);
  [PSP, f, t] = pspectrum(avgT, Fs, 'spectrogram','TimeResolution', params.windowSize);
  t = t+t(1)/2;
  y1 = sum(PSP >= params.powerT,1) > 0;
  burstList = detectBurstsSchmitt(t, y1);
  % Redefine F and T on the original axes
  for it = 1:length(burstList.start)
    [~, firstFrame] = min(abs(origT-burstList.start(it)));
    [~, lastFrame] = min(abs(origT-(burstList.start(it)+burstList.duration(it))));
    burstList.frames{it} = firstFrame:lastFrame;
    burstList.amplitude(it) = max(avgT(firstFrame:lastFrame));
  end
  burstStructure = burstList;
  
  % baseline check
  if(params.baselineCheck)
    invalidBursts = find(cellfun(@(x)all(avgT(x)<mean(avgT)), burstStructure.frames));
    burstStructure.duration(invalidBursts) = [];
    burstStructure.amplitude(invalidBursts) = [];
    burstStructure.start(invalidBursts) = [];
    burstStructure.frames(invalidBursts) = [];
    burstStructure.invalidBursts = length(invalidBursts);
    if(length(burstStructure.start) > 1)
      burstStructure.IBI = burstStructure.start(2:end)- (burstStructure.start(1:end-1) + burstStructure.duration(1:end-1));
    else
      burstStructure.IBI = [];
    end
    if(~isempty(invalidBursts))
      logMsg(sprintf('%d bursts removed by baselineCheck', length(invalidBursts)));
    end
  end  
  
  % Redefine IBI as the separation
  if(length(burstStructure.start) > 1)
    burstStructure.IBI = burstStructure.start(2:end) - (burstStructure.start(1:end-1) + burstStructure.duration(1:end-1));
  else
    burstStructure.IBI = [];
  end
  
  if(params.plotResults)
    figName = sprintf('PSP bursts %s', experiment.name);
    if(params.saveOptions.onlySaveFigure)
      figVisible = 'off';
    else
      figVisible = 'on';
    end
    figureHandle = figure('Name', figName, 'NumberTitle', 'off', 'Visible', figVisible, 'Tag', 'netcalPlot');
    figureHandle.Position = setFigurePosition(gcf, 'width', params.styleOptions.figureSize(1), 'height', params.styleOptions.figureSize(2), 'centered', true);
      
    a2 = subplot(3, 1, 2);
    hold on;
    imagesc(PSP,'XData',t,'YData',f);
    %colorbar;
    %imagesc(PSP >= powerT,'XData',t,'YData',f);

    xlabel('time (s)')
    ylabel('Freq (Hz)');
    box on;
    title(sprintf('PSP - N: %d', length(burstStructure.amplitude)), 'interpreter', 'none');
    xl = xlim;
    axis tight;
    a3 = subplot(3, 1, 3);
    hold on;
    try
      experiment = loadTraces(experiment, 'smoothed');
      avgF = mean(experiment.traces(:, members), 2);
      plot(experiment.t, avgF,'Color',[1 1 1]*0.75);
      ax = gca;
      ax.ColorOrderIndex = 1;
      for i=1:length(burstStructure.start)
        valid = find(experiment.t >= burstStructure.start(i) & experiment.t <= (burstStructure.start(i)+burstStructure.duration(i)));
        plot(experiment.t(valid), avgF(valid));
      end
      xlim([min(experiment.t) max(experiment.t)]);
      ylim([min(avgF) max(avgF)*1.1]);
    catch
    end
    title('Average trace');
    xlabel('time (s)');
    ylabel('DF/F');
    box on;
    axis tight;

    a1 = subplot(3, 1, 1);
    hold on;
    imagesc(PSP>params.powerT,'XData',t,'YData',f);
    hold on;
    xlim([min(t) max(t)]);
    xl = xlim;
    title(['PSP burst detection: ' experiment.name], 'interpreter', 'none');
    xlabel('time (s)');
    ylabel('Freq (Hz)');
    box on;
    linkaxes([a1 a2 a3], 'x');
    xlim([min(t) max(t)]);
    
    ui = uimenu(figureHandle, 'Label', 'Export');
    uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf';'*.eps'; '*.tiff'; '*.png'}, strrep([figFolder, figName], ' - ', '_'), params.saveOptions.saveFigureResolution});
      
    if(params.saveOptions.saveFigure)
      if(~isempty(params.saveOptions.saveFigureTag))
        figName = [figName params.saveOptions.saveFigureTag];
      end
      export_fig([figFolder, figName, '.', params.saveOptions.saveFigureType], ...
                  sprintf('-r%d', params.saveOptions.saveFigureResolution), ...
                  sprintf('-q%d', params.saveOptions.saveFigureQuality), figureHandle);
    end
    if(params.saveOptions.onlySaveFigure)
     close(figureHandle);
    end
    if(~isempty(params.styleOptions.figureTitle))
      mtit(params.styleOptions.figureTitle);
    end
  end
  % Store results
  
  burstList = burstStructure;
  
  experiment.spikeBursts.(groupName){groupIdx} = burstList;

  logMsg(sprintf('%d bursts detected on group %s in %s', length(burstList.start), groupList{git}, experiment.name));
  logMsg(sprintf('%.2f s mean duration', mean(burstList.duration)));
  logMsg(sprintf('%.2f mean maximum amplitude', mean(burstList.amplitude)));
  logMsg(sprintf('%.2f s mean IBI', mean(burstList.IBI)));
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
 %------------------------------------------------------------------------
  function burstStructure = detectBurstsSchmitt(t, avgTrace)
    upperThreshold = 0.5;
    lowerThreshold = 0.5;
    
    y = schmitt_trigger(avgTrace, lowerThreshold, upperThreshold);
    
    avgTraceAbove = nan(size(avgTrace));
    avgTraceAbove(find(y)) = avgTrace(find(y));

    split = SplitVec(y, 'equal', 'first');
    splitVals = SplitVec(y, 'equal');
    validSplit = find(y(split) == 1);

    %out = SplitVec(aboveThreshold, 'consecutive');
    %hold on;
    %plot(selectedT, avgTraceAbove);

    burstDuration = zeros(length(validSplit), 1);
    burstAmplitude = zeros(length(validSplit), 1);
    burstStart = zeros(length(validSplit), 1);
    burstFrames = cell(length(validSplit), 1);
    for i = 1:length(validSplit)
      burstFrames{i} = split(validSplit(i)):(split(validSplit(i))+length(splitVals{validSplit(i)})-1);
      burstT = t(burstFrames{i});
      burstF = avgTraceAbove(burstFrames{i});
      burstDuration(i) = burstT(end)-burstT(1);
      burstStart(i) = burstT(1);
      burstAmplitude(i) = max(burstF);
      %plot(burstT, burstF, 'LineWidth', 2);
    end
    IBI = diff(burstStart);
    burstStructure = struct;
    burstStructure.duration = burstDuration;
    burstStructure.amplitude = burstAmplitude;
    burstStructure.start = burstStart;
    burstStructure.IBI = IBI;
    burstStructure.frames = burstFrames;

    burstStructure.thresholds = [0.5 0.5];
  end

end