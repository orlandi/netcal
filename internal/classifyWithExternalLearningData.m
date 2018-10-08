function experiment = classifyWithExternalLearningData(experiment, varargin)
% CLASSIFYWITHEXTERNALLEARNINGDATA classifies populations using an external learner
%
% USAGE:
%    experiment = classifyWithExternalLearningData(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: classifyExternalOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = classifyWithExternalLearningData(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
% See also extractTraces

% EXPERIMENT PIPELINE
% name: classify with external learning
% parentGroups: fluorescence: group classification: feature-based
% optionsClass: classifyExternalOptions
% requiredFields: features
% producedFields: traceGroups.classifier

% Pass class options
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(classifyExternalOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Classifying traces', true);
%--------------------------------------------------------------------------
try
  data = load(params.externalFile, 'fullExportData', '-mat');
  learningData = data.fullExportData;
catch ME
  logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
  return;
end

% Consistency checks
if(~isfield(experiment, 'features'))
  logMsg('No features found. Run them in Population Analysis menu', 'e');
  return;
else
  if(size(experiment.features,1) ~= length(experiment.ROI))
    logMsg('Number of features elements and ROI does not match', 'e');
    return;
  end
end

trainingGroups = length(params.groupNames);

% Training phase - no need to save the classifier
%if(trainingGroups == 2)
%  classifier = fitensemble(learningData(:,1:end-1), learningData(:, end), 'RobustBoost', params.numberTrees, 'Tree');
%else
  classifier = fitensemble(learningData(:,1:end-1), learningData(:, end), params.trainer, params.numberTrees, 'Tree');
%end

% Prediction phase
classificationGroups = predict(classifier, experiment.features);

experiment.traceGroups.classifier = cell(trainingGroups, 1);
experiment.traceGroupsNames.classifier = params.groupNames;
for i = 1:trainingGroups
  experiment.traceGroups.classifier{i} = find(classificationGroups == i);
  experiment.traceGroupsOrder.ROI.classifier{i} = find(classificationGroups == i);
end
for i = 1:trainingGroups
  logMsg(sprintf('%d traces belong to population %s', length(experiment.traceGroups.classifier{i}), experiment.traceGroupsNames.classifier{i}));
end
experiment = loadTraces(experiment, 'normal');
% Now the similarity stuff
logMsg(sprintf('Obtaining similarities'));
experiment.traceGroupsOrder.similarity.classifier = cell(trainingGroups, 1);
for i = 1:trainingGroups
    if(~isempty(experiment.traceGroups.classifier{i}))
        [~, order, ~] = identifySimilaritiesInTraces(...
          experiment, experiment.traces(:, experiment.traceGroups.classifier{i}), ...
          'showSimilarityMatrix', false, ...
          'pbar', 0, ...
          'similarityMatrixTag', ...
          ['_traceSimilarity_' experiment.traceGroupsNames.classifier{i}], 'verbose', false);
        experiment.traceGroupsOrder.similarity.classifier{i} = experiment.traceGroups.classifier{i}(order);
    end
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
