function projexp = plotSpikeBurstStatisticsTreatment(projexp, varargin)
% PLOTSPIKEBURSTSTATISTICSTREATMENT plots spikeBurst statistics for a treatment
%
% USAGE:
%    experiment = plotSpikeBurstStatisticsTreatment(experiment, varargin)
%    project = plotSpikeBurstStatisticsTreatment(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%    options - Object containing class options: See plotSpikeBurstStatisticsTreatmentOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = plotQCEC(experiment)
%    project = plotQCEC(project)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% PIPELINE
% name: plot spikeBurst statistics for treatments
% parentGroups: statistics: treatments: spikes: bursts
% optionsClass: plotSpikeBurstStatisticsTreatmentOptions
% requiredFields: spikeBursts

obj = plotStatisticsTreatment;
obj.init(projexp, plotSpikeBurstStatisticsTreatmentOptions, 'Plotting spike-based burst statistics for treatments', varargin{:}, 'gui', gcbf);