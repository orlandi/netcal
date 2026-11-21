function projexp = plotNetworkStatisticsTreatment(projexp, varargin)
% PLOTNETWORKSTATISTICSTREATMENT plots network statistics for a treatment
%
% USAGE:
%    experiment = plotNetworkStatisticsTreatment(experiment, varargin)
%    project = plotNetworkStatisticsTreatment(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%    options - Object containing class options: See plotNetworkStatisticsTreatmentOptions
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
% name: plot network statistics for treatments
% parentGroups: statistics: treatments: networks
% optionsClass: plotNetworkStatisticsTreatmentOptions
% requiredFields: RS

obj = plotStatisticsTreatment;
obj.init(projexp, plotNetworkStatisticsTreatmentOptions, 'Plotting network statistics for treatments', varargin{:}, 'gui', gcbf);