function projexp = plotGroupStatistics(projexp, varargin)
% PLOTGROUPSTATISTICS plots group statistics
%
% USAGE:
%    experiment = plotGroupStatistics(experiment, varargin)
%    project = plotGroupStatistics(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%    options - Object containing class options: See plotGroupStatisticsOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = plotGroupStatistics(experiment)
%    project = plotGroupStatistics(project)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also plotGroupStatisticsOptions, plotStatistics, plotStatisticsOptions

% PIPELINE
% name: plot group statistics
% parentGroups: statistics: plots: groups
% optionsClass: plotGroupStatisticsOptions
% requiredFields: ROI

obj = plotStatistics;
obj.init(projexp, plotGroupStatisticsOptions, 'Plotting group statistics', varargin{:}, 'gui', gcbf);
