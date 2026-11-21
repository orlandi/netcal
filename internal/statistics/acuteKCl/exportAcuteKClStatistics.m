function projexp = exportAcuteKClStatistics(projexp, varargin)
% EXPORTACUTEKCLSTATISTICS exports spike statistics
%
% USAGE:
%    experiment = exportAcuteKClStatistics(experiment, varargin)
%    project = exportAcuteKClStatistics(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%    options - Object containing class options: See exportAcuteKClStatisticsOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = exportAcuteKClStatistics(experiment)
%    project = exportAcuteKClStatistics(project)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% PIPELINE
% name: export acute KCl statistics
% parentGroups: statistics: exports: protocols: acute KCl
% optionsClass: exportAcuteKClStatisticsOptions
% requiredFields: KClProtocolData

obj = exportStatistics;
obj.init(projexp, exportAcuteKClStatisticsOptions, 'Exporting acute KCl statistics', varargin{:}, 'gui', gcbf);
