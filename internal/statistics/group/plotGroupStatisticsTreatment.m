function projexp = plotGroupStatisticsTreatment(projexp, varargin)
% PLOTGROUPSTATISTICSTREATMENT plots group statistics for a treatment
%
% USAGE:
%    experiment = plotGroupStatisticsTreatment(experiment, varargin)
%    project = plotGroupStatisticsTreatment(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%    options - Object containing class options: See plotGroupStatisticsTreatmentOptions
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
% name: plot group statistics for treatments
% parentGroups: statistics: treatments: groups
% optionsClass: plotGroupStatisticsTreatmentOptions
% requiredFields: ROI

obj = plotStatisticsTreatment;
obj.init(projexp, plotGroupStatisticsTreatmentOptions, 'Plotting TODO statistics for treatments', varargin{:}, 'gui', gcbf);