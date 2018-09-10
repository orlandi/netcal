function experiment = automaticROIdetection(experiment, varargin)
% AUTOMATICROIDETECTION automatically detects ROI
%
% USAGE:
%    experiment = automaticROIdetection(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%
%    see: ROIautomaticOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = automaticROIdetection(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% EXPERIMENT PIPELINE
% name: automatic ROI detection
% parentGroups: fluorescence: basic
% optionsClass: ROIautomaticOptions
% requiredFields: avgImg
% producedFields: ROI

experiment.ROI = autoDetectROI(experiment.avgImg, varargin{:});
