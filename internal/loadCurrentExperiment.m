function experiment = loadCurrentExperiment(project, varargin)
% LOADCURRENTEXPERIMENT loads the project's current experiment
%
% USAGE:
%    experiment = loadCurrentExperiment(project)
%
% INPUT arguments:
%    project - The project structure
%
% INPUT optional arguments ('key' followed by its value):
%
%    'verbose' - true/false. If true, outputs verbose information. Default: false
%
% OUTPUT arguments:
%    experiment - structure containing the experiment
%
% EXAMPLE:
%     experiment = loadCurrentExperiment(project)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also loadExperiment
params.verbose = false;
params.pbar = [];
params = parse_pv_pairs(params, varargin);

experimentName = project.experiments{project.currentExperiment};
experimentFile = [project.folderFiles experimentName '.exp'];
experiment = loadExperiment(experimentFile, 'verbose', params.verbose, 'project', project, 'pbar', params.pbar);
