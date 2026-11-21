function projexp = exportFluorescenceBurstStatistics(projexp, varargin)
% EXPORTFLUORESCENCEBURSTSTATISTICS exports fluorescence-based bursts statistics
%
% USAGE:
%    experiment = exportFluorescenceBurstStatistics(experiment, varargin)
%    project = exportFluorescenceBurstStatistics(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%    options - Object containing class options: See exportFluorescenceBurstStatisticsOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = exportFluorescenceBurstStatistics(experiment)
%    project = exportFluorescenceBurstStatistics(project)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% PIPELINE
% name: export fluorescence-based burst statistics
% parentGroups: statistics: exports: fluorescence: bursts
% optionsClass: exportFluorescenceBurstStatisticsOptions
% requiredFields: traceBursts

obj = exportStatistics;
obj.init(projexp, exportFluorescenceBurstStatisticsOptions, 'Exporting fluorescence-based burst statistics', varargin{:}, 'gui', gcbf);
