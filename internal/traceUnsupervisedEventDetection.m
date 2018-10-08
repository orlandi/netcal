function experiment = traceUnsupervisedEventDetection(experiment, varargin)
% TRACEUNSUPERVISEDEVENTDETECTION detects patterns in traces for a given group
%
% USAGE:
%    experiment = traceUnsupervisedEventDetection(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: traceUnsupervisedEventDetectionOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = traceUnsupervisedEventDetection(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% EXPERIMENT PIPELINE
% name: detect events unsupervised
% parentGroups: fluorescence: group classification: pattern-based
% optionsClass: traceUnsupervisedEventDetectionOptions
% requiredFields: t, traces, ROI, folder, name

[params, var] = processFunctionStartup(traceUnsupervisedEventDetectionOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Detecting patterns');
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
    ncbar.setBarTitle(sprintf('Detecting patterns from group: %s', groupList{git}));
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

  % HERE
  minEventFrames = floor(params.minimumEventLength*experiment.fps);
    
  % First we find the events
  validPatterns = detectPatterns(t, traces(:, members), minEventFrames, params.thresholdType, params.threshold, params.numberGroups);
  % Now we automatically classify them
  % Create the eventList
  eventFeatures = [];
  for it = 1:size(traces, 2)
    curPatterns = validPatterns{it};
    curFeatures = zeros(length(curPatterns), 1);
    % Event length
    curFeatures(:, 1) = cellfun(@(x)length(x.F), curPatterns);
    % Avg F
    curFeatures(:, end+1) = cellfun(@(x)mean(x.F), curPatterns);
    % Median
    curFeatures(:, end+1) = cellfun(@(x)median(x.F), curPatterns);
    % Std F
    curFeatures(:, end+1) = cellfun(@(x)std(x.F), curPatterns);
    % Max F
    curFeatures(:, end+1) = cellfun(@(x)max(x.F), curPatterns);
    % Min F
    curFeatures(:, end+1) = cellfun(@(x)min(x.F), curPatterns);
    % Minmax
    %curFeatures(:, end+1) = cellfun(@(x)max(x.F)-min(x.F), curPatterns);
    % Skewness
    curFeatures(:, end+1) = cellfun(@(x)skewness(x.F), curPatterns);
    % Area
    %curFeatures(:, end+1) = cellfun(@(x)sum(x.F), curPatterns);
    % Fit features
%     for itt = 1:size(curFeatures, 1)
%       [p,s] = fit((1:length(curPatterns{itt}.F))', curPatterns{itt}.F(:), 'poly1');
%       if(itt == 1)
%         curFeatures(itt, end+1) = p.p1;
%         curFeatures(itt, end+1) = s.rsquare;
%       else
%         curFeatures(itt, end-1) = p.p1;
%         curFeatures(itt, end) = s.rsquare;
%       end
%     end
    
    % Idx pair
    curFeatures(:, end+1) = it;
    curFeatures(:, end+1) = 1:length(curPatterns);
    eventFeatures = [eventFeatures; curFeatures];
  end
  % Now we have all the features for doing some Kmeans
  %clusterIdx = kmeans(eventFeatures(:, 1:end-2), params.numberGroups, 'Distance', 'cityblock', 'MaxIter', 150);
  %clusterIdx = kmeans(eventFeatures(:, 1:end-2), params.numberGroups, 'MaxIter', 150);
  
   [centers,U] = fcm(eventFeatures(:, 1:end-2), params.numberGroups);
%   
   [maxU, clusterIdx] = max(U);
   valid = find(maxU >= 0.95);
%   % Generate 1 more cluster than defined
   classificationGroups = ones(1, size(U,2))*(params.numberGroups+1);
%   % Set the members above threshold to the correct cluster idx
   classificationGroups(valid) = clusterIdx(valid);
   clusterIdx = classificationGroups;
%   Y = tsne(eventFeatures(:, 1:end-2), 'Algorithm', 'barneshut', 'Perplexity', 50, 'Exaggeration', 20);
%   d = pdist(Y);
%   z = linkage(d);
%   cl = cluster(z, 'cutoff', 5, 'Criterion', 'distance');
%   clusterIdx = cl;
%   experiment.traceUnsupervisedEventDetectionOptionsCurrent.numberGroups = max(cl);
%   figure;
%   gscatter(Y(:,1),Y(:,2), cl);
  %legend off;
  

  
  % Now propagate the clusterIdx back to the patterns!
  for it = 1:size(eventFeatures, 1)
    idx1 = eventFeatures(it, end-1);
    idx2 = eventFeatures(it, end);
    validPatterns{idx1}{idx2}.pattern = clusterIdx(it);
    validPatterns{idx1}{idx2}.basePattern = sprintf('Unsupervised: %d', clusterIdx(it));
  end

  if(~isfield(experiment, 'validPatterns'))
    experiment.validPatterns = cell(size(traces, 2), 1);
    experiment.validPatterns(members) = validPatterns;
  else
    try
      experiment.validPatterns(members) = validPatterns;
    catch ME
      experiment.validPatterns = cell(size(traces, 2), 1);
      experiment.validPatterns(members) = validPatterns;
      logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
    end
  end
  
  logMsg(sprintf('Found %d total patterns',  sum(cellfun(@length, validPatterns))));
  patternList = [];
  for it = 1:length(validPatterns)
    patternList = [patternList, cellfun(@(x)x.basePattern, validPatterns{it}, 'UniformOutput', false)];
  end
  uniquePatterns = unique(patternList);
  % I kinda complicated myself here
  hits = cellfun(@sum, cellfun(@(x)strcmp(x, patternList), uniquePatterns, 'UniformOutput', false));
  for it = 1:length(uniquePatterns)
    logMsg(sprintf('Found %d patterns of type %s', hits(it), uniquePatterns{it}));
  end
end

experiment.saveBigFields = true; % So the patterns are saved

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

  %------------------------------------------------------------------------
  function validPatterns = detectPatterns(t, traces, minEventFrames, thresholdType, threshold, numberGroups)
    % Time to detect the patterns - for each neuron, a pattern list
    validPatterns = cell(size(traces, 2), 1);

    nTraces = size(traces, 2);
    numTraces = size(traces, 2);

    for it2 = 1:numTraces
      validPatterns{it2} = singleTracePatternDetection(traces(:, it2), t, minEventFrames, thresholdType, threshold);
      if(params.pbar > 0)
        ncbar.update(it2/nTraces);
      end
    end
  end


  function validPattern = singleTracePatternDetection(signal, t, minEventFrames, thresholdType, threshold)
    validPattern = {};
    % Hack for now
    %threshold = threshold(1);
    lowerThreshold = threshold(2);
    upperThreshold = threshold(1);
    switch thresholdType
      case 'relative'
        %avgMean = mean(signal);
        avgMean = median(signal);
        avgStd = std(signal);
        %mfil = medfilt1(signal, 2500);
        %avgStd = std(mfil);
        y = schmitt_trigger(signal, avgMean+lowerThreshold*avgStd, avgMean+upperThreshold*avgStd);
        %y = schmitt_trigger(signal, mfil+lowerThreshold*avgStd, mfil+upperThreshold*avgStd);
      case 'absolute'
        y = schmitt_trigger(signal, lowerThreshold, upperThreshold);
    end
    valid = find(y');
    %valid = find(signal > median(signal) + threshold*std(signal));
    
    x = diff(valid') == 1;
    f = find([false,x] ~= [x,false]);
    clLength = f(2:2:end)-f(1:2:end-1);
    g = find(clLength >= minEventFrames);
    first_t = valid(f(2*g-1)); % First t followed by >=N consecutive numbers
    last_t = first_t+clLength(g)';
    
    for it3 = 1:length(first_t)
      validPattern{end+1} = struct;
      % Now let's expand the events!
%       first_t_orig = first_t(it3);
%       first_t(it3) = max(1, round(first_t(it3)-(last_t(it3)-first_t(it3))/2));
%       last_t(it3) = min(length(signal), round(last_t(it3)+(last_t(it3)-first_t_orig)/2));
      validPattern{end}.frames = first_t(it3):last_t(it3);
      validPattern{end}.coeff = 1;
      validPattern{end}.pattern = 1;
      validPattern{end}.basePattern = 'Unsupervised';
      validPattern{end}.F = signal(first_t(it3):last_t(it3));
    end
  end
end
