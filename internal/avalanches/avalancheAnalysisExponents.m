function experiment = avalancheAnalysisExponents(experiment, varargin)
% AVALANCHEANALYSISEXPONENTS computes the avalanches exponents
%
% USAGE:
%    experiment = avalancheAnalysisExponents(experiment)
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
%    experiment = avalancheAnalysisExponents(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% EXPERIMENT PIPELINE
% name: avalanche exponents
% parentGroups: avalanches: analysis
% optionsClass: avalancheOptions
% requiredFields: avalanches
% producedFields: avalanchesProps

%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(avalancheOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Calculating exponents', true);

[tau, xmin, xmax, sigma, p, pCrit] = avpropvals(experiment.avalanches.size, 'size', 'plot', true);
experiment.avalancheProps.tau = tau;
experiment.avalancheProps.xmin = xmin;
experiment.avalancheProps.xmax = xmax;
experiment.avalancheProps.sigma = sigma;
experiment.avalancheProps.p = p;
experiment.avalancheProps.pCrit = pCrit;

if(params.verbose && params.pbar > 0)
  ncbar.unsetAutomaticBar();
end
%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
