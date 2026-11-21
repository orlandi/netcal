function projexp = plotSpikeStatisticsTreatment(projexp, varargin)
% PLOTSPIKESTATISTICSTREATMENT plots spike statistics for a treatment
%
% USAGE:
%    experiment = plotSpikeStatisticsTreatment(experiment, varargin)
%    project = plotSpikeStatisticsTreatment(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see plotQCECOptions
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
% name: plot spike statistics for treatments
% parentGroups: statistics: treatments: spikes
% optionsClass: plotSpikeStatisticsTreatmentOptions
% requiredFields: spikes

obj = plotStatisticsTreatment;
obj.init(projexp, plotSpikeStatisticsTreatmentOptions, 'Plotting spikes statistics for treatments', varargin{:}, 'gui', gcbf);