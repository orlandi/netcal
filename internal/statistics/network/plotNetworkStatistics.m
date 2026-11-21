function projexp = plotNetworkStatistics(projexp, varargin)
% PLOTNETWORKSTATISTICS plots network statistics
%
% USAGE:
%    experiment = plotNetworkStatistics(experiment, varargin)
%    project = plotNetworkStatistics(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%    options - Object containing class options: See plotNetworkStatisticsOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = plotNetworkStatistics(experiment)
%    project = plotNetworkStatistics(project)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also plotNetworkStatisticsOptions, plotStatistics, plotStatisticsOptions

% PIPELINE
% name: plot network statistics
% parentGroups: statistics: plots: networks
% optionsClass: plotNetworkStatisticsOptions
% requiredFields: RS

obj = plotStatistics;
% 2026 weird change
obj.init(projexp, plotNetworkStatisticsOptions, 'Plotting network statistics', varargin{:}, 'gui', gcbf);
