function projexp = plotAcuteKClStatistics(projexp, varargin)
% PLOTACUTEKCLSTATISTICS plots acuteKCl statistics
%
% USAGE:
%    experiment = plotAcuteKClStatistics(experiment, varargin)
%    project = plotAcuteKClStatistics(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%    options - Object containing class options: See plotAcuteKClStatisticsOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = plotAcuteKClStatistics(experiment)
%    project = plotAcuteKClStatistics(project)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also plotAcuteKClStatisticsOptions, plotStatistics, plotStatisticsOptions

% PIPELINE
% name: plot acute KCl statistics
% parentGroups: statistics: plots: protocols: acute KCl
% optionsClass: plotAcuteKClStatisticsOptions
% requiredFields: KClProtocolData

obj = plotStatistics;
obj.init(projexp, plotAcuteKClStatisticsOptions, 'Plotting acute KCl statistics', varargin{:}, 'gui', gcbf);
