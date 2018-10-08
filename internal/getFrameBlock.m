function frameBlock = getFrameBlock(experiment, frame, fid, blockSize, varargin)
% GETFRAMEBLOCK get a given set of frames from an experiment
%
% USAGE:
%    img = getFrameBlock(experiment, frame, fid, blockSize, varargin)
%
% INPUT arguments:
%    experiment - structure obtained from loadExperiment()
%
%    frame - selected frame
%
%    fid - ID of the stream (from openVideoStream)
%
% INPUT optional arguments:
%    pixelList - 1d-vector with the list of pixels to use instead of the whole frame
% OUTPUT arguments:
%    img - frame block data
%
% EXAMPLE:
%     img = getFrame(experiment, frame, fID)
%
% REFERENCES:
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
% See also: loadExperiment, getFrame

if(~isempty(varargin) && ~isempty(varargin{1}))
  partial = true;
  pixelList = varargin{1};
  pixelLength = pixelList(end)-pixelList(1)+1;
else
  partial = false;
end
if(frame > experiment.numFrames)
  frameBlock = [];
end
if(experiment.numFrames-frame < blockSize)
  realBlockSize = experiment.numFrames-frame+1;
else
  realBlockSize = blockSize;
end
if(partial)
  frameBlock = zeros(length(pixelList), realBlockSize);
else
  frameBlock = zeros(experiment.height, experiment.width, realBlockSize);
end
for it = 1:realBlockSize
  if(partial)
    frameBlock(:, it) = getFrame(experiment, frame+it-1, fid, varargin{:});
  else
    frameBlock(:, :, it) = getFrame(experiment, frame+it-1, fid, varargin{:});
  end
end