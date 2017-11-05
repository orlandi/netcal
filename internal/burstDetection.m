function experiment = burstDetection(experiment, varargin)
% BURSTDETECTION detects bursts for a given group
%
% USAGE:
%    experiment = burstDetection(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: burstDetectionOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = burstDetection(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% EXPERIMENT PIPELINE
% name: burst detection
% parentGroups: fluorescence: bursts
% optionsClass: burstDetectionOptions
% requiredFields: rawT, rawTraces, ROI, folder, name

[params, var] = processFunctionStartup(burstDetectionOptions, varargin{:});
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
  avgT = mean(traces(:, members), 2);
  % The actual detection
  switch params.detectionMethod
    case 'schmitt'
      burstList = detectBurstsSchmitt(t, avgT, params.schmittThresholdType, params.schmittThresholds(1), params.schmittThresholds(2));
    case 'pattern'
      burstList = obtainPatternBasedBursts(experiment, avgT, t, params.overridePatternThreshold);
  end
  
  experiment.traceBursts.(groupName){groupIdx} = burstList;
  %if(params.verbose)
    logMsg(sprintf('%d bursts detected on group %s', length(burstList.start), groupList{git}));
    logMsg(sprintf('%.2f s mean duration', mean(burstList.duration)));
    logMsg(sprintf('%.2f mean maximum amplitude', mean(burstList.amplitude)));
    logMsg(sprintf('%.2f s mean IBI', mean(burstList.IBI)));
  %end
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

  %------------------------------------------------------------------------
  function burstStructure = detectBurstsSchmitt(t, avgTrace, thresholdType, upperThreshold, lowerThreshold)
    
    switch thresholdType
      case 'relative'
        avgMean = mean(avgTrace);
        avgStd = std(avgTrace);
        y = schmitt_trigger(avgTrace, avgMean+lowerThreshold*avgStd, avgMean+upperThreshold*avgStd);
      case 'absolute'
        y = schmitt_trigger(avgTrace, lowerThreshold, upperThreshold);
    end
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
    burstStructure.thresholds = [lowerThreshold upperThreshold];
  end

  %------------------------------------------------------------------------
  function burstStructure = obtainPatternBasedBursts(experiment, signal, t, overrideThreshold)
    if(isempty(overrideThreshold))
      overrideThreshold = 0;
    end
    [patterns, ~] = generatePatternList(experiment, 'bursts');
    if(isempty(patterns))
      logMsg('No patterns of type bursts found', 'w');
      burstStructure = struct;
      burstStructure.duration = [];
      burstStructure.amplitude = [];
      burstStructure.start = [];
      burstStructure.IBI = [];
      burstStructure.frames = [];
      burstStructure.thresholds = [nan nan];
      return;
    end
    % Time to detect the patterns - for each neuron, a pattern list
    validPatterns = cell(1);

    % New, faster version
    % Precompute for the patterns
    EY = cell(size(patterns));
    EYY = cell(size(patterns));
    b = cell(size(patterns));
    for it1 = 1:length(patterns)
      pattern = patterns{it1}.F(:)';
      EY{it1} = mean(pattern);
      EYY{it1} = mean(pattern.^2);
      b{it1} = ones(size(pattern))'/length(pattern);
    end
    % This is a hack from the other function
    it1 = 1;
    validPatterns{it1} = {};
    for it2 = 1:length(patterns)
      if(overrideThreshold > 0 && overrideThreshold <= 1)
        threshold = overrideThreshold;
      else
        threshold = patterns{it2}.threshold;
      end
      pattern = patterns{it2}.F(:)';
      % Since patterns might have different lenght, this has to go here
      % We are doing all
      [cc, ~] = xcorr(signal, pattern);
      EXY = cc(length(t):end)/length(pattern);
      revY = signal(end:-1:1);
      EX = filter(b{it2}, 1, revY);
      EX = EX(end:-1:1);
      EXX = filter(b{it2}, 1, revY.^2);
      EXX = EXX(end:-1:1);
      cc = (EXY-EX.*EY{it2})./(sqrt(EXX-EX.^2)*sqrt(EYY{it2}-EY{it2}.^2));
      done = false;
      %origCC = cc;
      while(~done)
        currT = find(cc > threshold, 1, 'first');
        if(isempty(currT))
          done = true;
          continue;
        end
        lastT = min(length(t), currT+length(pattern)-1);
        validPatterns{it1}{end+1} = struct;
        validPatterns{it1}{end}.frames = currT:lastT;
        validPatterns{it1}{end}.coeff = cc(currT);
        validPatterns{it1}{end}.pattern = it2;
        validPatterns{it1}{end}.basePattern = patterns{it2}.basePattern;
        cc(1:lastT) = 0;
      end
    end

    % Now remove overlapping patterns
    %logMsg('Removing overlapping patterns by correlation');
    for it1 = 1:length(validPatterns)
      done = false;
      firstPattern = 1;
      while(~done)
        done = true;
        foundPatterns = validPatterns{it1};
        for it2 = firstPattern:length(foundPatterns)
          pattern1 = validPatterns{it1}{it2};
          for it3 = (it2+1):length(foundPatterns)
            pattern2 = validPatterns{it1}{it3};
            if(any(intersect(pattern1.frames, pattern2.frames)))
              if(pattern1.coeff > pattern2.coeff)
                validPatterns{it1}(it3) = [];
              else
                validPatterns{it1}(it2) = [];
              end
              firstPattern = it2;
              done = false;
              break;
            end
          end
          if(~done)
            break;
          end
        end
      end
    end
      
    bursts = {};
    for it1 = 1:length(validPatterns)
      for it2 = 1:length(validPatterns{it1})
        bursts{end+1} = validPatterns{it1}{it2};
      end
    end
    
    % Keep going
    burstStart = zeros(length(bursts), 1);
    burstFrames = cell(length(bursts), 1);

    % Sort bursts
    for i = 1:length(bursts)
        burstFrames{i} = bursts{i}.frames;
        burstT = t(burstFrames{i});
        burstStart(i) = burstT(1);
    end
    [~, idx] = sort(burstStart);
    bursts = bursts(idx);

    burstAmplitude = zeros(length(bursts), 1);  
    burstDuration = zeros(length(bursts), 1);  
    burstStart = zeros(length(bursts), 1);
    burstFrames = cell(length(bursts), 1);
    for i = 1:length(bursts)
      burstFrames{i} = bursts{i}.frames;
      burstT = t(burstFrames{i});
      burstF = signal(burstFrames{i});
      burstAmplitude(i) = max(burstF);
      burstStart(i) = burstT(1);
      burstDuration(i) = burstT(end)-burstT(1);

      if(params.overridePatternLength)
        % The new duration - until it decays 1/e of the maximum
        [~, maxP] = max(burstF);
        maxP = burstFrames{i}(maxP);
        bs = maxP + 1 - find(signal(maxP:-1:1) <= (0.6321)*burstAmplitude(i), 1, 'first');
        %bs = maxP + 1 - find(signal(maxP:-1:1) <= (0.9)*burstAmplitude(i), 1, 'first');
        be = maxP - 1 + find(signal(maxP:end) <= (0.3716)*burstAmplitude(i), 1, 'first');
        %be = maxP - 1 + find(signal(maxP:end) <= (0.6321)*burstAmplitude(i), 1, 'first');

        if(isempty(bs))
          bs = 1;
        end
        if(isempty(be))
          be = length(signal);
        end
        %sprintf('%.2f ', t([maxP, bs, be])')
        burstFrames{i} = bs:be;
        burstT = t(burstFrames{i});
        %burstF = signal(burstFrames{i});
        burstStart(i) = burstT(1);
        burstDuration(i) = burstT(end)-burstT(1);
      end
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

        burstT = t(burstFrames{i});
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
  end
end
