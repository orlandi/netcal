function projexp = plotFluorescenceBurstStatisticsTreatment(projexp, varargin)
% PLOTFLUORESCENCEBURSTSTATISTICSTREATMENT plots fluorescence-based burst statistics for a treatment
%
% USAGE:
%    experiment = plotFluorescenceBurstStatisticsTreatment(experiment, varargin)
%    project = plotFluorescenceBurstStatisticsTreatment(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%    options - Object containing class options: See plotFluorescenceBurstStatisticsTreatmentOptions
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
% name: plot fluorescence-based burst statistics for treatments
% parentGroups: statistics: treatments: fluorescence: bursts
% optionsClass: plotFluorescenceBurstStatisticsTreatmentOptions
% requiredFields: traceBursts

obj = plotStatisticsTreatment;
obj.init(projexp, plotFluorescenceBurstStatisticsTreatmentOptions, 'Plotting fluorescence-based burst statistics for treatments', varargin{:}, 'gui', gcbf);