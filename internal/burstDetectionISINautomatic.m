function experiment = burstDetectionISINautomatic(experiment, varargin)
% BURSTDETECTIONISINAUTOMATIC Adaptation of: https://doi.org/10.3389/fncom.2013.00193
%
% USAGE:
%    experiment = burstDetectionISINautomatic(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: burstDetectionISINoptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = burstDetectionISIN(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% EXPERIMENT PIPELINE
% name: ISI_N burst detection semi-automatic
% parentGroups: spikes: bursts
% optionsClass: burstDetectionISINautomaticOptions
% requiredFields: spikes, ROI, folder, name

[params, var] = processFunctionStartup(burstDetectionISINautomaticOptions, varargin{:});
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

% Get ALL subgroups in case of parents
if(strcmpi(mainGroup, 'all'))
  groupList = getExperimentGroupsNames(experiment);
else
  groupList = getExperimentGroupsNames(experiment, mainGroup);
end

% Some definitions
minBurstSeparation = params.minBurstSeparation;
lowMultiplier = params.lowMultiplier;
highMultiplier = params.highMultiplier;
Steps = 10.^[-3:.05:3];
pkList = linspace(0, 5, 100);
burstThreshold = params.burstThreshold;
minParticipators = params.minParticipators;

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
  
  maxCells = sum(cellfun(@(x)~isempty(x) & ~any(isnan(x)), experiment.spikes(members)));
  Ne = max(ceil(burstThreshold*maxCells), minParticipators);
  
  experiment.spikes = cellfun(@(x)x(:)', experiment.spikes, 'UniformOutput', false);
  
  ar=[cellfun(@(x)x, experiment.spikes(members), 'UniformOutput', false)];
  
  SpikeTimes = [];
  SpikeIdx = [];
  for it = 1:length(ar)
    if(~isnan(ar{it}))
      SpikeTimes = [SpikeTimes, ar{it}];
      SpikeIdx = [SpikeIdx, ones(size(ar{it}))*it];
    end
  end
  mat = [SpikeTimes', SpikeIdx'];
  ar = sortrows(mat, 1);
  SpikeTimes = ar(:,1)';
  SpikeTimes = SpikeTimes +(rand(size(SpikeTimes))-0.5)/experiment.fps;
  
  SpikeIdx = members(ar(:,2))';
  firings.T = SpikeTimes;
  firings.N = SpikeIdx;
  sortedSpikeTimes = sort(SpikeTimes);
  [a, b] = hist(firings.N, 1:max(firings.N));
  [~, sortedChannels] = sort(a, 'ascend');
  sortedChannels = arrayfun(@(x)find(x==sortedChannels), 1:max(firings.N));
  if(params.reorderChannels)
    minC = min(sortedChannels(firings.N));
  else
    minC = 0;
  end
  
  FRnum = Ne;
  
  ISI_N = sortedSpikeTimes( FRnum:end ) - sortedSpikeTimes( 1:end-(FRnum-1) );
  
  n = histc( ISI_N, Steps);
  %n = smooth( n, 'lowess' );
  valid = find(n > 0);
  newSteps = Steps(valid);
  n = n(valid);

  nPlot = smooth(n)/sum(n);

  Spike.T = SpikeTimes;
  Spike.C = SpikeIdx;
  % So first channel is 0
  Spike.C = Spike.C - 1;
      
  %%% The findpeaks model
  if(strcmpi(params.method, 'schmitt') || strcmpi(params.method, 'explore'))
    [~, locs, ~, p] = findpeaks(log(nPlot));
    if(length(locs) < 2)
      burstStructure = struct;
      burstStructure.duration = [];
      burstStructure.amplitude = [];
      burstStructure.start = [];
      burstStructure.IBI = [];
      burstStructure.frames = {};
      burstStructure.participators = {};
      burstStructure.thresholds = NaN;
      burstStructure.N = 0;
      detectedFullSchmitt = [];
      optISINmaxShort = NaN;
      optISINmaxLong = NaN;
      optISINthLow = NaN;
      optISINthHigh = NaN;
    else
      [~, pidx] = sort(p, 'descend');
      pksIdx = locs(pidx(1:2));

      optISINmaxLong = max(newSteps(pksIdx));
      optISINmaxShort = min(newSteps(pksIdx));
     %[optISINupper optISINlower]
      [~, locs, ~, p] = findpeaks(-log(nPlot));
      valid = find(newSteps(locs) > optISINmaxShort & newSteps(locs) < optISINmaxLong);
      locs = locs(valid);
      p = p(valid);
      [~, pidx] = sort(p,'descend');
      pksIdx = locs(pidx(1));

      optISINmiddle = newSteps(pksIdx);
      if(length(pidx) > 1)
        optISINmiddle2 = newSteps(locs(pidx(2)));
      else
        optISINmiddle2 = optISINmiddle;
      end

      optISINminLong = max([optISINmiddle optISINmiddle2]);
      optISINminShort = min([optISINmiddle optISINmiddle2]);
      %optISINminShort = mean([optISINmiddle optISINmiddle2]);
      if(isempty(optISINminShort))
        optISINminShort = min([optISINmiddle optISINmiddle2]);
      end

      optISINthLow = optISINminShort*lowMultiplier;
      optISINthHigh = optISINminShort*highMultiplier;
      [optISINthLow optISINthHigh]
      % Now the schmitt part
      % Negate everything because we want to be below the thresholds!
      %y = schmitt_trigger(-ISI_N, -optISINlower, -optISINupper);
      y = schmitt_trigger(-ISI_N, -optISINthLow, -optISINthHigh);

      avgTraceAbove = nan(size(ISI_N));
      avgTraceAbove(find(y)) = ISI_N(find(y));

      split = SplitVec(y, 'equal', 'first');
      splitVals = SplitVec(y, 'equal');
      validSplit = find(y(split) == 1);

      burstDuration = zeros(length(validSplit), 1);
      burstAmplitude = zeros(length(validSplit), 1);
      burstStart = zeros(length(validSplit), 1);
      burstFrames = cell(length(validSplit), 1);
      burstChannels = cell(length(validSplit), 1);
      for i = 1:length(validSplit)
        burstFrames{i} = split(validSplit(i)):(split(validSplit(i))+length(splitVals{validSplit(i)})-1);
        burstT = Spike.T(burstFrames{i});
        burstDuration(i) = max(burstT)-min(burstT);
        burstStart(i) = min(burstT);
        validSpikes = find(SpikeTimes >= burstStart(i) & SpikeTimes <= burstStart(i)+burstDuration(i));
        burstAmplitude(i) = length(validSpikes);
        burstChannels{i} = unique(SpikeIdx(validSpikes));
      end
      burstStructure = struct;
      burstStructure.duration = burstDuration;
      burstStructure.amplitude = burstAmplitude;
      burstStructure.start = burstStart;

      burstStructure.frames = burstFrames;
      burstStructure.participators = burstChannels;
      burstStructure.thresholds = [optISINmaxShort, optISINmaxLong];
      burstStructure.N = FRnum;

      if(length(burstStructure.start) > 1)
        burstStructure.IBI = burstStructure.start(2:end) - (burstStructure.start(1:end-1) + burstStructure.duration(1:end-1));
      else
        burstStructure.IBI = [];
      end

      detectedFullSchmitt = [];
      for i=1:length(burstStructure.start)
        detectedFullSchmitt = [detectedFullSchmitt burstStructure.start(i) burstStructure.start(i)+burstStructure.duration(i) NaN];
      end

      % Merge bursts between too short IBIs
      done = false;
      while(~done)
        done = true;
        for it = 1:length(burstStructure.IBI)
          % Remove burst it+1 and add it to burst it
          if(burstStructure.IBI(it) <= minBurstSeparation)
            done = false;
            burstStructure.duration(it) = burstStructure.start(it+1)+burstStructure.duration(it+1)-burstStructure.start(it);
            burstStructure.amplitude(it) = burstStructure.amplitude(it) + burstStructure.amplitude(it+1);
            burstStructure.frames{it} = burstStructure.frames{it}(1):burstStructure.frames{it+1}(end);
            burstStructure.participators{it} = unique([burstStructure.participators{it}, burstStructure.participators{it+1}]);
            % Now remove the next one
            burstStructure.duration(it+1) = [];
            burstStructure.amplitude(it+1) = [];
            burstStructure.start(it+1) = [];
            burstStructure.frames(it+1) = [];
            burstStructure.participators(it+1) = [];
            % Recompute IBIs
            if(length(burstStructure.start) > 1)
              burstStructure.IBI = burstStructure.start(2:end)- (burstStructure.start(1:end-1) + burstStructure.duration(1:end-1));
            else
              burstStructure.IBI = [];
            end
            break;
          end
        end
      end

      invalidBursts = find(cellfun(@length,burstStructure.participators) < minParticipators | burstStructure.amplitude < Ne);
      burstStructure.duration(invalidBursts) = [];
      burstStructure.amplitude(invalidBursts) = [];
      burstStructure.start(invalidBursts) = [];
      burstStructure.frames(invalidBursts) = [];
      burstStructure.participators(invalidBursts) = [];
      burstStructure.invalidBursts = length(invalidBursts);
      if(length(burstStructure.start) > 1)
        burstStructure.IBI = burstStructure.start(2:end)- (burstStructure.start(1:end-1) + burstStructure.duration(1:end-1));
      else
        burstStructure.IBI = [];
      end
    end
  end
  
  if(strcmpi(params.method, 'peaks') || strcmpi(params.method, 'explore'))
    origX = sortedSpikeTimes(1:length(ISI_N));
    origY = -log(ISI_N);
    newX = 0:1/experiment.fps:max(origX);
    newY = interp1(origX, origY, newX);


    pkListRes = zeros(size(pkList));
    for it = 1:length(pkList)
      [pks, locs] = findpeaks(newY, newX, 'minPeakProminence', pkList(it),  'MinPeakDistance', minBurstSeparation);
      pkListRes(it) = length(pks);
    end

    nPeaks = mode(pkListRes(pkListRes>0));
    
    valid = find(pkListRes == nPeaks, 1, 'first');
    minProminence = pkList(valid)*params.peakMultiplier;
    [pks, locs, w, p] = findpeaks2(newY, newX, 'MinPeakProminence', minProminence, 'MinPeakDistance', minBurstSeparation, 'Annotate', 'extents');
    % Increase the duration
    w(:, 1) = w(:, 1) - diff(w, 1, 2)/4;
    w(:, 2) = w(:, 2) + diff(w, 1, 2)/4;

    burstDuration = zeros(length(pks), 1);
    burstAmplitude = zeros(length(pks), 1);
    burstStart = zeros(length(pks), 1);
    burstFrames = cell(length(pks), 1);
    burstChannels = cell(length(pks), 1);
    for i = 1:length(pks)
      burstFrames{i} = round(w(i, 1)*experiment.fps):round(w(i, 2)*experiment.fps);
      if(isempty(burstFrames{i}))
        continue;
      end
      burstFrames{i}(burstFrames{i} > length(newX)) = [];
      burstFrames{i}(burstFrames{i} < 1) = [];
      burstT = newX(burstFrames{i});
      %burstF = avgTraceAbove(burstFrames{i});
      burstDuration(i) = max(burstT)-min(burstT);
      burstStart(i) = min(burstT);
      validSpikes = find(SpikeTimes >= burstStart(i) & SpikeTimes <= burstStart(i)+burstDuration(i));
      burstAmplitude(i) = length(validSpikes);
      burstChannels{i} = unique(SpikeIdx(validSpikes));
      % Redefine based on spike times
      burstFrames{i} = round(min(SpikeTimes(validSpikes))*experiment.fps):round(max(SpikeTimes(validSpikes))*experiment.fps);
      burstT = newX(burstFrames{i});
      %burstF = avgTraceAbove(burstFrames{i});
      if(~isempty(burstT))
        burstDuration(i) = max(burstT)-min(burstT);
      else
        burstDuration(i) = 0;
      end
      burstStart(i) = min(burstT);
      burstAmplitude(i) = length(validSpikes);
      %plot(burstT, burstF, 'LineWidth', 2);
    end
    burstStructurePeaks = struct;
    burstStructurePeaks.duration = burstDuration;
    burstStructurePeaks.amplitude = burstAmplitude;
    burstStructurePeaks.start = burstStart;
    burstStructurePeaks.IBI = [];
    burstStructurePeaks.frames = burstFrames;
    burstStructurePeaks.participators = burstChannels;
    burstStructurePeaks.thresholds = [NaN, NaN];
    burstStructurePeaks.N = FRnum;
    %burstStructure.IBI = diff(burstStructure.start);
    if(length(burstStructurePeaks.start) > 1)
      burstStructurePeaks.IBI = burstStructurePeaks.start(2:end)- (burstStructurePeaks.start(1:end-1) + burstStructurePeaks.duration(1:end-1));
    else
      burstStructurePeaks.IBI = [];
    end
    
    detectedFullPeaks = [];
    for i=1:length(burstStructurePeaks.start)
      valid = find(firings.T >= burstStructurePeaks.start(i) & firings.T <= (burstStructurePeaks.start(i)+burstStructurePeaks.duration(i)));
      detectedFullPeaks = [detectedFullPeaks burstStructurePeaks.start(i) burstStructurePeaks.start(i)+burstStructurePeaks.duration(i) NaN];
    end

    % Merge bursts between too short IBIs
    done = false;
    while(~done)
      done = true;
      for it = 1:length(burstStructurePeaks.IBI)
        % Remove burst it+1 and add it to burst it
        if(burstStructurePeaks.IBI(it) <= minBurstSeparation)
          done = false;
          burstStructurePeaks.duration(it) = burstStructurePeaks.start(it+1)+burstStructurePeaks.duration(it+1)-burstStructurePeaks.start(it);
          burstStructurePeaks.amplitude(it) = burstStructurePeaks.amplitude(it) + burstStructurePeaks.amplitude(it+1);
          burstStructurePeaks.frames{it} = burstStructurePeaks.frames{it}(1):burstStructurePeaks.frames{it+1}(end);
          burstStructurePeaks.participators{it} = unique([burstStructurePeaks.participators{it}, burstStructurePeaks.participators{it+1}]);
          % Now remove the next one
          burstStructurePeaks.duration(it+1) = [];
          burstStructurePeaks.amplitude(it+1) = [];
          burstStructurePeaks.start(it+1) = [];
          burstStructurePeaks.frames(it+1) = [];
          burstStructurePeaks.participators(it+1) = [];
          % Recompute IBIs
          if(length(burstStructurePeaks.start) > 1)
            burstStructurePeaks.IBI = burstStructurePeaks.start(2:end)- (burstStructurePeaks.start(1:end-1) + burstStructurePeaks.duration(1:end-1));
          else
            burstStructurePeaks.IBI = [];
          end
          break;
        end
      end
    end
    burstStructurePeaksPre = burstStructurePeaks;
    %invalidBursts = find(burstStructurePeaks.duration <= min(burstStructurePeaks.thresholds) | burstStructurePeaks.amplitude <= FRnum);
    %invalidBursts = [];
    invalidBursts = find(cellfun(@length,burstStructurePeaks.participators) < minParticipators  | burstStructurePeaks.amplitude < Ne);
    burstStructurePeaks.duration(invalidBursts) = [];
    burstStructurePeaks.amplitude(invalidBursts) = [];
    burstStructurePeaks.start(invalidBursts) = [];
    burstStructurePeaks.frames(invalidBursts) = [];
    burstStructurePeaks.participators(invalidBursts) = [];
    burstStructurePeaks.invalidBursts = length(invalidBursts);
    if(length(burstStructurePeaks.start) > 1)
      burstStructurePeaks.IBI = burstStructurePeaks.start(2:end)- (burstStructurePeaks.start(1:end-1) + burstStructurePeaks.duration(1:end-1));
    else
      burstStructurePeaks.IBI = [];
    end
  end
  if(params.plotResults)
    if(~params.reorderChannels)
      sortedChannels = 1:max(firings.N);
    end
    if(strcmpi(params.method, 'schmitt') || strcmpi(params.method, 'explore'))
      hFig = figure('Tag', 'netcalPlot');
      
      a1 = subplot(3, 1, 2);
      hold on;
      plot(firings.T, sortedChannels(firings.N)-minC, 'k.');
      detected = [];
      for i=1:length(burstStructure.start)
        %Detected = [ Detected Burst.T_start(i) Burst.T_end(i) NaN ];
        valid = find(firings.T >= burstStructure.start(i) & firings.T <= (burstStructure.start(i)+burstStructure.duration(i)));

        plot(firings.T(valid), sortedChannels(firings.N(valid))-minC, '.');
        detected = [detected burstStructure.start(i) burstStructure.start(i)+burstStructure.duration(i) NaN];
      end
      linesMap = lines(2);
      plot(detectedFullSchmitt, ones(size(detectedFullSchmitt))*max(sortedChannels(firings.N))-minC+5, 'v-', 'MarkerSize', 6, 'LineWidth', 2, 'Color', linesMap(2,:), 'MarkerFaceColor', linesMap(2,:))
      plot(detected, ones(size(detected))*max(sortedChannels(firings.N))-minC+5, 'v-', 'MarkerSize', 6, 'LineWidth', 2, 'Color', linesMap(1,:), 'MarkerFaceColor', linesMap(1,:))

      xlabel('time (s)')
      ylabel('sorted ROI');

      box on;
      title(sprintf('Raster plot - N: %d', length(burstStructure.amplitude)));
      xl = xlim;
      
      a2 = subplot(3, 1, 3);
      hold on;
      try
        experiment = loadTraces(experiment, 'smoothed');
        plot(experiment.t, mean(experiment.traces(:, members), 2),'Color',[1 1 1]*0.75);
        ax = gca;
        ax.ColorOrderIndex = 1;
        for i=1:length(burstStructure.start)
          valid = find(experiment.t >= burstStructure.start(i) & experiment.t <= (burstStructure.start(i)+burstStructure.duration(i)));
          plot(experiment.t(valid), mean(experiment.traces(valid, members), 2));
        end
        xlim([min(experiment.t) max(experiment.t)]);
      catch
      end
      title('Average trace');
      xlabel('time (s)');
      ylabel('DF/F');
      box on;
      
      a3 = subplot(3, 1, 1);
      plot(sortedSpikeTimes(1:length(ISI_N)), -ISI_N);
      hold on;
      xlim([min(experiment.t) max(experiment.t)]);
      xl = xlim;
      plot(xl, -[1,1]*optISINthLow);
      plot(xl, -[1,1]*optISINthHigh);
      %legend('ISI_N','low','high');
      title(['ISI_N Schmitt trigger detection: ' experiment.name]);
      xlabel('time (s)');
      ylabel('-ISI_N (s)');
      box on;
      linkaxes([a1 a2 a3], 'x');
      xlim([min(experiment.t) max(experiment.t)]);
    end
    
    if(strcmpi(params.method, 'peaks') || strcmpi(params.method, 'explore'))
      hFig = figure('Tag', 'netcalPlot');
      a1 = subplot(3, 1, 1);
      hold on;
      box on;
      findpeaks(newY, newX, 'MinPeakProminence',minProminence, 'MinPeakDistance', minBurstSeparation, 'Annotate', 'extents');
      title(['ISI_N peaks trigger detection: ' experiment.name]);
      box on;
      legend off;
      
      a2 = subplot(3, 1, 2);
      hold on;
      plot(firings.T, sortedChannels(firings.N)-minC, 'k.');
      detected = [];
      for i=1:length(burstStructurePeaks.start)
        valid = find(firings.T >= burstStructurePeaks.start(i) & firings.T <= (burstStructurePeaks.start(i)+burstStructurePeaks.duration(i)));
        plot(firings.T(valid), sortedChannels(firings.N(valid))-minC, '.');
        detected = [detected burstStructurePeaks.start(i) burstStructurePeaks.start(i)+burstStructurePeaks.duration(i) NaN];
      end
      linesMap = lines(2);
      plot(detectedFullPeaks, ones(size(detectedFullPeaks))*max(sortedChannels(firings.N))-minC+5, 'v-', 'MarkerSize', 6, 'LineWidth', 2, 'Color', linesMap(2,:), 'MarkerFaceColor', linesMap(2,:))
      plot(detected, ones(size(detected))*max(sortedChannels(firings.N))-minC+5, 'v-', 'MarkerSize', 6, 'LineWidth', 2, 'Color', linesMap(1,:), 'MarkerFaceColor', linesMap(1,:))

      xlabel('time (s)')
      ylabel('sorted ROI');

      box on;
      title(sprintf('Raster plot - N: %d', length(burstStructurePeaks.amplitude)));
      xl = xlim;
      
      a3 = subplot(3, 1, 3);
      hold on;
      try
        experiment = loadTraces(experiment, 'smoothed');
        plot(experiment.t, mean(experiment.traces(:, members), 2),'Color',[1 1 1]*0.75);
        for i=1:length(burstStructurePeaks.start)
          valid = find(experiment.t >= burstStructurePeaks.start(i) & experiment.t <= (burstStructurePeaks.start(i)+burstStructurePeaks.duration(i)));
          plot(experiment.t(valid), mean(experiment.traces(valid, members), 2));
        end
        xlim([min(experiment.t) max(experiment.t)]);
      catch
      end
      title('Average trace');
      xlabel('time (s)');
      ylabel('DF/F');
      box on;
      linkaxes([a1 a2 a3], 'x');
      xlim([min(experiment.t) max(experiment.t)]);
    end
  end
  % Store results
  if(strcmpi(params.method, 'schmitt') || strcmpi(params.method, 'explore'))
    burstList = burstStructure;
  else
    burstList = burstStructurePeaks;
  end
  experiment.spikeBursts.(groupName){groupIdx} = burstList;

  logMsg(sprintf('%d bursts detected on group %s', length(burstList.start), groupList{git}));
  logMsg(sprintf('%.2f s mean duration', mean(burstList.duration)));
  logMsg(sprintf('%.2f mean maximum amplitude', mean(burstList.amplitude)));
  logMsg(sprintf('%.2f s mean IBI', mean(burstList.IBI)));
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

end
%findpeaks(newY, newX, 'MinPeakProminence', pkList(valid), 'MinPeakDistance', minBurstSeparation, 'Annotate', 'extents');