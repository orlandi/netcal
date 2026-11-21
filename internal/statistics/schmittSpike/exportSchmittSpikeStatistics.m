function projexp = exportSchmittSpikeStatistics(projexp, varargin)
% EXPORTSCHMITTSPIKESTATISTICS exports spike statistics
%
% USAGE:
%    experiment = exportSchmittSpikeStatistics(experiment, varargin)
%    project = exportSchmittSpikeStatistics(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%    options - Object containing class options: See exportSchmittSpikeStatisticsOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = exportSchmittSpikeStatistics(experiment)
%    project = exportSchmittSpikeStatistics(project)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% PIPELINE
% name: export schmittSpike statistics
% parentGroups: statistics: exports: spikes
% optionsClass: exportSchmittSpikeStatisticsOptions
% requiredFields: schmittSpikesData

obj = exportStatistics;
obj.init(projexp, exportSchmittSpikeStatisticsOptions, 'Exporting Schmitt-spike statistics', varargin{:}, 'gui', gcbf);
