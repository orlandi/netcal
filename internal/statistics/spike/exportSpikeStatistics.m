function projexp = exportSpikeStatistics(projexp, varargin)
% EXPORTSPIKESTATISTICS exports spike statistics
%
% USAGE:
%    experiment = exportSpikeStatistics(experiment, varargin)
%    project = exportSpikeStatistics(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%    options - Object containing class options: See exportSpikeStatisticsOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = exportSpikeStatistics(experiment)
%    project = exportSpikeStatistics(project)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% PIPELINE
% name: export spike statistics
% parentGroups: statistics: exports: spikes
% optionsClass: exportSpikeStatisticsOptions
% requiredFields: spikes

obj = exportStatistics;
obj.init(projexp, exportSpikeStatisticsOptions, 'Exporting spike statistics', varargin{:}, 'gui', gcbf);
