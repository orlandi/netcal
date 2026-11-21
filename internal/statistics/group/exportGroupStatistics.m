function projexp = exportGroupStatistics(projexp, varargin)
% EXPORTGROUPSTATISTICS exports spike statistics
%
% USAGE:
%    experiment = exportGroupStatistics(experiment, varargin)
%    project = exportGroupStatistics(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%    options - Object containing class options: See exportGroupStatisticsOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = exportGroupStatistics(experiment)
%    project = exportGroupStatistics(project)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% PIPELINE
% name: export group statistics
% parentGroups: statistics: exports: groups
% optionsClass: exportGroupStatisticsOptions
% requiredFields: ROI

obj = exportStatistics;
obj.init(projexp, exportGroupStatisticsOptions, 'Exporting group statistics', varargin{:}, 'gui', gcbf);
