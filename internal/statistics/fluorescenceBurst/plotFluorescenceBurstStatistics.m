function projexp = plotFluorescenceBurstStatistics(projexp, varargin)
% PLOTFluorescenceBurstSTATISTICS plots fluorescence-based burst statistics
%
% USAGE:
%    experiment = plotFluorescenceBurstStatistics(experiment, varargin)
%    project = plotFluorescenceBurstStatistics(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%    options - Object containing class options: See plotFluorescenceBurstStatisticsOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = plotFluorescenceBurstStatistics(experiment)
%    project = plotFluorescenceBurstStatistics(project)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also plotFluorescenceBurstStatisticsOptions, plotStatistics, plotStatisticsOptions

% PIPELINE
% name: plot fluorescenceBurst statistics
% parentGroups: statistics: plots: fluorescence: bursts
% optionsClass: plotFluorescenceBurstStatisticsOptions
% requiredFields: traceBursts

obj = plotStatistics;
obj.init(projexp, plotFluorescenceBurstStatisticsOptions, 'Plotting fluorescence-based burst statistics', varargin{:}, 'gui', gcbf);
