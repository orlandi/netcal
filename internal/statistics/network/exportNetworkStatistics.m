function projexp = exportNetworkStatistics(projexp, varargin)
% EXPORTNETWORKSTATISTICS exports spike statistics
%
% USAGE:
%    experiment = exportNetworkStatistics(experiment, varargin)
%    project = exportNetworkStatistics(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%    options - Object containing class options: See exportNetworkStatisticsOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = exportNetworkStatistics(experiment)
%    project = exportNetworkStatistics(project)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% PIPELINE
% name: export network statistics
% parentGroups: statistics: exports: networks
% optionsClass: exportNetworkStatisticsOptions
% requiredFields: RS

obj = exportStatistics;
obj.init(projexp, exportNetworkStatisticsOptions, 'Exporting TODO statistics', varargin{:}, 'gui', gcbf);
