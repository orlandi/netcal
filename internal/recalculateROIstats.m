function experiment = recalculateROIstats(experiment, varargin)
% RECALCULATEROISTATS recalculates ROI statistics
%
% USAGE:
%    experiment = recalculateROIstats(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: []
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = exportROIcenters(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% EXPERIMENT PIPELINE
% name: recalculate ROI statistics
% parentGroups: ROI
% requiredFields: ROI, folder, name

[params, var] = processFunctionStartup([], varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Recalculating ROI statistics', true);
%-----------------------------------------------x---------------------------

for it = 1:length(experiment.ROI)
  [y, x] = ind2sub([experiment.height experiment.width], experiment.ROI{it}.pixels);
  experiment.ROI{it}.center = [mean(x), mean(y)];
  experiment.ROI{it}.maxDistance = max(sqrt((mean(x)-x).^2+(mean(y)-y).^2));
end
%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

end
