function projexp = plotSchmittSpikeStatisticsTreatment(projexp, varargin)
% PLOTSCHMITTSPIKESTATISTICSTREATMENT plots schmittSpike statistics for a treatment
%
% USAGE:
%    experiment = plotSchmittSpikeStatisticsTreatment(experiment, varargin)
%    project = plotSchmittSpikeStatisticsTreatment(project, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%    options - Object containing class options: See plotSchmittSpikeStatisticsTreatmentOptions
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
% name: plot schmitt-spike statistics for treatments
% parentGroups: statistics: treatments: spikes
% optionsClass: plotSchmittSpikeStatisticsTreatmentOptions
% requiredFields: schmittSpikesData

obj = plotStatisticsTreatment;
obj.init(projexp, plotSchmittSpikeStatisticsTreatmentOptions, 'Plotting Schmitt-spike statistics for treatments', varargin{:}, 'gui', gcbf);