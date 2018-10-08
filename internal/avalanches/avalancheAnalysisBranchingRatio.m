function experiment = avalancheAnalysisBranchingRatio(experiment, varargin)
% AVALANCHEANALYSISBRANCHINGRATIO computes the branching ratios
%
% USAGE:
%    experiment = avalancheAnalysisBranchingRatio(experiment)
%
% INPUT arguments:
%    experiment - structure obtained from loadExperiment()
%
% INPUT optional arguments ('key' followed by its value):
%
%    see: avalancheOptions
%
% OUTPUT arguments:
%    experiment - structure obtained from loadExperiment()
%
% EXAMPLE:
%    experiment = avalancheAnalysisDistributions(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% EXPERIMENT PIPELINE
% name: avalanche branching ratio
% parentGroups: avalanches: analysis
% optionsClass: avalancheOptions
% requiredFields: spikes
% producedFields: branchingRatio

%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(avalancheOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.subset = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Calculating branching ratios', true);


% First put the experiment in asdf2 mode
if(ischar(params.binSize))
  params.binSize = eval(params.binSize);
end
experiment.asdf2 = experimentToAsdf2(experiment, 'binsize', params.binSize, 'subset', params.subset);
experiment.asdf2
% Now compute branching ratios
[br,slopevals,brsimple] = brestimate(experiment.asdf2);

experiment.branchingRatio.br = br;
experiment.branchingRatio.slopevals = slopevals;
experiment.branchingRatio.brsimple = brsimple;

if(params.verbose && params.pbar > 0)
  ncbar.unsetAutomaticBar();
end
%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
