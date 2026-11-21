function projexp = plotSpikeStatistics(projexp, varargin)
% PLOTSPIKESTATISTICS plots spike statistics
%
% USAGE:
%    experiment = plotSpikeStatistics(experiment, varargin)
%    project = plotSpikeStatistics(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see plotSpikeStatisticsOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = plotSpikeStatistics(experiment)
%    project = plotSpikeStatistics(project)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also plotSpikeStatisticsOptions, plotStatistics, plotStatisticsOptions

% PIPELINE
% name: plot spike statistics
% parentGroups: statistics: plots: spikes
% optionsClass: plotSpikeStatisticsOptions
% requiredFields: spikes

obj = plotStatistics;
obj.init(projexp, plotSpikeStatisticsOptions, 'Plotting spikes statistics', varargin{:}, 'gui', gcbf);
