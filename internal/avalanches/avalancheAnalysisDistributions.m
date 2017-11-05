function experiment = avalancheAnalysisDistributions(experiment, varargin)
% AVALANCHEANALYSISDISTRIBUTIONS computes the different avalanche distributions (sizes, durations and shapes)
%
% USAGE:
%    experiment = avalancheAnalysisDistributions(experiment)
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
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% EXPERIMENT PIPELINE
% name: avalanche distributions
% parentGroups: avalanches: analysis
% optionsClass: avalancheOptions
% requiredFields: spikes
% producedFields: avalanches

%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(avalancheOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.subset = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Calculating avalanche sizes', true);
%--------------------------------------------------------------------------

% First put the experiment in asdf2 mode
%if(~isfield(experiment, 'asdf2') || isempty(experiment.asdf2))
if(ischar(params.binSize))
  params.binSize = eval(params.binSize);
end
experiment.asdf2 = experimentToAsdf2(experiment, 'binsize', params.binSize, 'subset', params.subset);
%end
% Compute statistics
if(params.computeBranchingRatio)
  experiment.avalanches = avprops(experiment.asdf2, 'ratio');
else
  experiment.avalanches = avprops(experiment.asdf2);
end

% Now the plots
if(params.plotDistributions)
  experiment = avalancheAnalysisPlotDistributions(experiment, varargin{1}, 'verbose', false, 'pbar', pbar);
end
if(params.verbose && params.pbar > 0)
  ncbar.unsetAutomaticBar();
end
%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
