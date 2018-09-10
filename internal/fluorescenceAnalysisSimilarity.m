function experiment = fluorescenceAnalysisSimilarity(experiment, varargin)
% FLUORESCENCEANALYSISSIMILARITY performs similarity analysis on traces
%
% USAGE:
%    experiment = fluorescenceAnalysisSimilarity(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%
%    see: similarityOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = fluorescenceAnalysisSimilarity(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% EXPERIMENT PIPELINE
% name: trace similarity analysis
% parentGroups: fluorescence: basic
% optionsClass: similarityOptions
% requiredFields: traces
% producedFields: similarityOrder, traceGroupsOrder.similarity.everything

%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(similarityOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Performing similarity analysis', true);
%--------------------------------------------------------------------------

 
if(~isfield(experiment, 'traces'))
  logMsg('No smoothed traces found. Extract and smooth traces first', 'e');
  return;
end
experiment = loadTraces(experiment, 'normal');
    
[~, experiment.similarityOrder, ~] = identifySimilaritiesInTraces(...
                                      experiment, ...
                                      experiment.traces, ...
                                      'saveSimilarityMatrix', params.saveSimilarityMatrix,...
                                      'similarityMatrixTag', params.similarityMatrixTag,...
                                      'showSimilarityMatrix', params.showSimilarityMatrix,...
                                      'cmap', params.colormap,...
                                      'verbose', false,...
                                      'pbar', params.pbar);
experiment.traceGroupsOrder.similarity.everything{1} = experiment.similarityOrder;

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
