function projexp = plotSpikeBurstStatistics(projexp, varargin)
% PLOTSPIKEBURSTSTATISTICS plots spikeBurst statistics
%
% USAGE:
%    experiment = plotSpikeBurstStatistics(experiment, varargin)
%    project = plotSpikeBurstStatistics(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%    options - Object containing class options: See plotSpikeBurstStatisticsOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = plotSpikeBurstStatistics(experiment)
%    project = plotSpikeBurstStatistics(project)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also plotSpikeBurstStatisticsOptions, plotStatistics, plotStatisticsOptions

% PIPELINE
% name: plot spikeBurst statistics
% parentGroups: statistics: plots: spikes: bursts
% optionsClass: plotSpikeBurstStatisticsOptions
% requiredFields: spikeBursts

obj = plotStatistics;
obj.init(projexp, plotSpikeBurstStatisticsOptions, 'Plotting spike-based burst statistics', varargin{:}, 'gui', gcbf);
