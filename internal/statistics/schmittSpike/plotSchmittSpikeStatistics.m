function projexp = plotSchmittSpikeStatistics(projexp, varargin)
% PLOTSCHMITTSPIKESTATISTICS plots schmittSpike statistics
%
% USAGE:
%    experiment = plotSchmittSpikeStatistics(experiment, varargin)
%    project = plotSchmittSpikeStatistics(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%    options - Object containing class options: See plotSchmittSpikeStatisticsOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = plotSchmittSpikeStatistics(experiment)
%    project = plotSchmittSpikeStatistics(project)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also plotSchmittSpikeStatisticsOptions, plotStatistics, plotStatisticsOptions

% PIPELINE
% name: plot schmittSpike statistics
% parentGroups: statistics: plots: spikes
% optionsClass: plotSchmittSpikeStatisticsOptions
% requiredFields: schmittSpikesData

obj = plotStatistics;
obj.init(projexp, plotSchmittSpikeStatisticsOptions, 'Plotting Schmitt-spike statistics', varargin{:}, 'gui', gcbf);
