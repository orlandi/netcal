function experiment = convertTracesToSinglePrecision(experiment, varargin)
% CONVERTTRACESTOSINGLEPRECISION Converts all traces to single precision
%
% USAGE:
%   experiment = convertTracesToSinglePrecision(experiment, options)
%
% INPUT arguments:
%   experiment - structure containing an experiment
%
% INPUT optional arguments:
%   see baseOptions
%
% OUTPUT arguments:
%   experiment - structure containing an experiment
%
% EXAMPLE:
%   experiment = convertTracesToSinglePrecision(experiment, KClProtocolOptions)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also baseOptions

% EXPERIMENT PIPELINE
% name: convert traces to single precision
% parentGroups: misc
% optionsClass: baseOptions
% requiredFields: rawTraces

% Pass class options
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(baseOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Converting traces to single precision', true);
%--------------------------------------------------------------------------

% Fix in case for some reason the group is a cell
validFields = {'rawTraces', 'traces', 'baseLine' ,'modelTraces', 'rawTracesDenoised'};


for it = 1:length(validFields)
  if(isfield(experiment, validFields{it}))
    experiment = loadTraces(experiment, validFields{it});
    experiment.(validFields{it}) = single(experiment.(validFields{it}));
  end
end

experiment.saveBigFields = true;

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------


end