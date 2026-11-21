function projexp = exportSpikeBurstStatistics(projexp, varargin)
% EXPORTSPIKEBURSTSTATISTICS exports spike statistics
%
% USAGE:
%    experiment = exportSpikeBurstStatistics(experiment, varargin)
%    project = exportSpikeBurstStatistics(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%    options - Object containing class options: See exportSpikeBurstStatisticsOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = exportSpikeBurstStatistics(experiment)
%    project = exportSpikeBurstStatistics(project)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% PIPELINE
% name: export spike-based burst statistics
% parentGroups: statistics: exports: spikes: bursts
% optionsClass: exportSpikeBurstStatisticsOptions
% requiredFields: spikeBursts

obj = exportStatistics;
obj.init(projexp, exportSpikeBurstStatisticsOptions, 'Exporting spike-based burst statistics', varargin{:}, 'gui', gcbf);
