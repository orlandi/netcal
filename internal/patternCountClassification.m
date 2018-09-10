function experiment = patternCountClassification(experiment, varargin)
% PATTERNCOUNTCLASSIFICATION classifies traces based on pattern count
%
% USAGE:
%    experiment = patternCountClassification(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: patternCountClassifierOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = patternCountClassification(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% EXPERIMENT PIPELINE
% name: classify with pattern counts
% parentGroups: fluorescence: group classification: pattern-based
% optionsClass: patternCountClassifierOptions
% requiredFields: validPatterns, ROI, folder, name

[params, var] = processFunctionStartup(patternCountClassifierOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Classifying patterns');
%--------------------------------------------------------------------------

threshold = params.threshold;
if(threshold < 1)
  thresholdType = 'relative';
else
  thresholdType = 'absolute';
end

experiment = loadTraces(experiment, 'validPatterns');

[patterns, basePatternList] = generatePatternList(experiment);
if(isempty(basePatternList) && isfield(experiment, 'traceUnsupervisedEventDetectionOptionsCurrent'))
  basePatternList = strsplit(sprintf('Unsupervised: %d,', 1:experiment.traceUnsupervisedEventDetectionOptionsCurrent.numberGroups),',');
  basePatternList = basePatternList(1:end-1);
end

countList = zeros(length(experiment.validPatterns), length(basePatternList));
for it = 1:length(experiment.validPatterns)
  if(isempty(experiment.validPatterns{it}))
    continue;
  end
  patternList = cellfun(@(x)x.basePattern, experiment.validPatterns{it}, 'UniformOutput', false);

  count = zeros(length(basePatternList), 1);
  for it2 = 1:length(basePatternList)
    count(it2) = sum(strcmp(patternList, basePatternList{it2}));
  end
  countList(it, :) = count;
end

newFeatures = countList;

trainingGroups = length(basePatternList);

switch params.mode
  case 'independent'
    % Get the maximum count
    [maxCount, classificationGroups] = max(newFeatures, [], 2);
    % If it's not above the threshold, move it to the undefined group
    switch thresholdType
      case 'relative'
        classificationGroups(maxCount./sum(newFeatures,2) < threshold | sum(newFeatures,2)  == 0) = trainingGroups+1;
      case 'absolute'
        classificationGroups(maxCount < threshold | sum(newFeatures,2)  == 0) = trainingGroups+1;
    end

    trainingGroups = trainingGroups + 1;
    basePatternList{end+1} = 'undefined';
    experiment.traceGroups.patternCountClassifier = cell(trainingGroups, 1);
    experiment.traceGroupsNames.patternCountClassifier = basePatternList;
    for it = 1:trainingGroups
        experiment.traceGroups.patternCountClassifier{it} = find(classificationGroups == it);
        experiment.traceGroupsOrder.ROI.patternCountClassifier{it} = find(classificationGroups == it);
    end
  case 'overlapping'
    trainingGroups = trainingGroups + 1;
    basePatternList{end+1} = 'undefined';
    experiment.traceGroups.patternCountClassifier = cell(trainingGroups, 1);
    experiment.traceGroupsOrder.ROI.patternCountClassifier = cell(trainingGroups, 1);
    experiment.traceGroupsNames.patternCountClassifier = basePatternList;
    hits = [];
    for it = 1:(trainingGroups-1)
      switch thresholdType
        case 'relative'
          valid = find(newFeatures(:, it)./sum(newFeatures,2) >= threshold);
        case 'absolute'
          valid = find(newFeatures(:, it)  >= threshold);
      end
      experiment.traceGroups.patternCountClassifier{it} = valid;
      experiment.traceGroupsOrder.ROI.patternCountClassifier{it} = valid;
      hits = [hits; valid(:)];
    end
    undefined = setdiff(1:size(newFeatures, 1), hits);
    experiment.traceGroups.patternCountClassifier{end} = undefined;
    experiment.traceGroupsOrder.ROI.patternCountClassifier{end} = undefined;
    % Let's do the pairwise intersection
    nGroups = length(basePatternList);
    if(nGroups > 2)
      for it1 = 1:(nGroups-1)
        for it2 = (it1+1):(nGroups-1)
          %experiment.traceGroupsNames.patternCountClassifier
          gr1 = experiment.traceGroups.patternCountClassifier{it1};
          gr2 = experiment.traceGroups.patternCountClassifier{it2};
          %experiment.traceGroups.patternCountClassifier
          valid = intersect(gr1, gr2);
          experiment.traceGroups.patternCountClassifier{end+1} = valid;
          experiment.traceGroupsOrder.ROI.patternCountClassifier{end+1} = valid;
          basePatternList{end+1} = sprintf('%s and %s', basePatternList{it1}, basePatternList{it2});
        end
      end
      experiment.traceGroupsNames.patternCountClassifier = basePatternList;
    end
end

for it = 1:length(experiment.traceGroupsNames.patternCountClassifier)
  logMsg(sprintf('%d traces belong to population %s', length(experiment.traceGroups.patternCountClassifier{it}), experiment.traceGroupsNames.patternCountClassifier{it}));
end

% Now the similarity stuff
%logMsg(sprintf('Obtaining similarities'));
experiment.traceGroupsOrder.similarity.classifier = cell(trainingGroups, 1);
for i = 1:length(experiment.traceGroupsNames.patternCountClassifier)
  if(~isempty(experiment.traceGroups.patternCountClassifier{i}))
    try
      experiment = loadTraces(experiment, 'smoothed');
      %size(experiment.traces)
      %experiment.traceGroups.patternCountClassifier{i}
      [~, order, ~] = identifySimilaritiesInTraces(...
        experiment, experiment.traces(:, experiment.traceGroups.patternCountClassifier{i}), ...
        'showSimilarityMatrix', false, ...
        'similarityMatrixTag', ...
        ['_traceSimilarity_' experiment.traceGroupsNames.patternCountClassifier{i}], 'verbose', false, 'pbar', params.pbar);
      experiment.traceGroupsOrder.similarity.patternCountClassifier{i} = experiment.traceGroups.patternCountClassifier{i}(order);
    catch ME
      logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
    end
  end
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

