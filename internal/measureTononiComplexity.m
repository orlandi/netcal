function experiment = measureTononiComplexity(experiment, varargin)
% MEASURETONONICOMPLEXITY measures complexity like Tononi, 1994
%
% USAGE:
%    experiment = measureTononiComplexity(experiment)
%
% INPUT arguments:
%    experiment - structure obtained from loadExperiment()
%
% INPUT optional arguments ('key' followed by its value):
%    see: tononiComplexityOptions
%
% OUTPUT arguments:
%    experiment - structure obtained from loadExperiment()
%
% EXAMPLE:
%    experiment = measureTononiComplexity(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also spikeFeaturesOptions

% EXPERIMENT PIPELINE
% name: measure complexity (Tononi)
% parentGroups: spikes
% optionsClass: tononiComplexityOptions
% requiredFields: spikes
% producedFields: tononiComplexity

%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(tononiComplexityOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];

% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Measuring Tononi Complexity', false);
%--------------------------------------------------------------------------

% Fix in case for some reason the group is a cell
if(iscell(params.group))
  mainGroup = params.group{1};
else
  mainGroup = params.group;
end

members = getAllMembers(experiment, mainGroup);


asdf2 = experimentToAsdf2(experiment, 'binSize', params.binSize, 'subset', members);
raster = asdf2toraster(asdf2);
[cn, intInfPart] = complexityv2(raster, params.maxSubsets, params.pbar);

experiment.tononiComplexity.complexity = cn;
experiment.tononiComplexity.integratedInformation = intInfPart;
logMsg2(sprintf('Measured complexity: %.3f',cn));

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
