function [stream, experiment] = openVideoStream(experiment, varargin)
% OPENVIDEOSTREAM open the experiment video stream for reading
%
% USAGE:
%    stream = openVideoStream(experiment)
%
% INPUT arguments:
%    experiment - structure obtained from loadExperiment()
%
% OUTPUT arguments:
%    stream - stream structure (handle for most formats, videowriter object
%    for AVI files)
%
%    experiment - experiment structure
%
% EXAMPLE:
%     [stream, experiment] = openVideoStream(experiment)
%
% REFERENCES:
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
% See also: loadExperiment

% Define additional optional argument pairs
%params.gui = [];
%params = parse_pv_pairs(params, varargin);

if(~isempty(experiment.handle) && strcmp(experiment.handle, 'dummy'))
  stream = [];
  return;
end

% Check if the handle exists. If not, update it


if(isempty(experiment.handle) || experiment.handle(1) == 0 || ~exist(experiment.handle, 'file'))
  if(~isempty(experiment.handle) && experiment.handle(1) ~= 0)
    [~, fpb, fpc] = fileparts(experiment.handle);
    logMsg(sprintf('Could not find %s ', experiment.handle), 'e');
    [fileName, pathName] = uigetfile([fpb fpc],'Find experiment location');
    experiment.handle = [pathName fileName];
  else
    logMsg('Could not find experiment recording', 'e');
    [fileName, pathName] = uigetfile('Find experiment location');
    experiment.handle = [pathName fileName];
  end
  if(~exist(experiment.handle, 'file'))
    logMsg('Invalid experiment handle', 'e');
  else
    experiment.handle = [pathName fileName];
    logMsg(sprintf('experiment handle updated to %s ', experiment.handle));
  end
end

[~, ~, fpc] = fileparts(experiment.handle);
if(strcmpi(fpc, '.avi') ||strcmpi(fpc, '.mj2'))
  stream = VideoReader(experiment.handle);
elseif(strcmpi(fpc, '.his'))
  [experiment, success] = precacheHISframes(experiment);
  if(~success)
    logMsg('Something went wrong precaching HIS frames', 'e');
    return;
  end
  stream = fopen(experiment.handle, 'r');
elseif(strcmpi(fpc, '.dcimg'))
  stream = fopen(experiment.handle, 'r');
elseif(strcmpi(fpc, '.btf') || strcmpi(fpc, '.tiff') || strcmpi(fpc, '.tif'))
  stream = 137;
elseif(strcmpi(fpc, '.mat'))
  if(strcmp(experiment.metadata, 'RIKEN'))
    riken = load(experiment.handle, '-mat');
    experiment.data = riken.VDAQ.alldata{1};
    stream = 137;
  end
elseif(strcmpi(fpc, '.bin'))
  if(~isfield(experiment, 'multiDriveMode') || ~experiment.multiDriveMode)
    stream = fopen(experiment.handle, 'r');
  else
    for it = 1:length(experiment.multiDriveHandle)
      stream(it) = fopen(experiment.multiDriveHandle{it}, 'r');
    end
  end
else
  stream = [];
end
