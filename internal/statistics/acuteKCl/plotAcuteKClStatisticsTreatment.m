function projexp = plotAcuteKClStatisticsTreatment(projexp, varargin)
% PLOTACUTEKCLSTATISTICSTREATMENT plots acuteKCl statistics for a treatment
%
% USAGE:
%    experiment = plotAcuteKClStatisticsTreatment(experiment, varargin)
%    project = plotAcuteKClStatisticsTreatment(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%    options - Object containing class options: See plotAcuteKClStatisticsTreatmentOptions
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
% name: plot acute KCl statistics for treatments
% parentGroups: statistics: treatments: protocols: acute KCl
% optionsClass: plotAcuteKClStatisticsTreatmentOptions
% requiredFields: KClProtocolData

obj = plotStatisticsTreatment;
obj.init(projexp, plotAcuteKClStatisticsTreatmentOptions, 'Plotting acute KCl statistics for treatments', varargin{:}, 'gui', gcbf);