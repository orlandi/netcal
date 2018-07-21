function img = getFrame(experiment, frame, fid, varargin)
% GETFRAME get a given frame from an experiment
%
% USAGE:
%    img = getFrame(experiment, frame, fid)
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
%    img - frame data
%
% EXAMPLE:
%     img = getFrame(experiment, frame, fID)
%
% REFERENCES:
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
% See also: loadExperiment

if(~isempty(varargin) && ~isempty(varargin{1}))
  pixelList = varargin{1};
  pixelLength = pixelList(end)-pixelList(1)+1;
  partial = true;
else
  partial = false;
end

if(nargin == 2)
  fid = openVideoStream(experiment);
end
if(isnumeric(fid) && fid == -1)
  img = zeros(experiment.height, experiment.width, strrep(experiment.pixelType,'*',''));
  return;
end

if(~isfield(experiment, 'extension'))
  [~, ~, fpc] = fileparts(experiment.handle);
  experiment.extension = fpc;
end


switch experiment.extension
  case '.his'
    if(partial)
      fseek(fid, experiment.frameOffsetList(frame)+(pixelList(1)-1)*experiment.bpp/8, 'bof');
      img = fread(fid, pixelLength, experiment.pixelType);
      % Only return the needed pixels
      if(length(pixelLength) ~= length(pixelList))
        img = img(pixelList-pixelList(1)+1);
      end
    else
      fseek(fid, experiment.frameOffsetList(frame), 'bof');
      img = fread(fid,experiment.width*experiment.height, experiment.pixelType);
      img = reshape(img, [experiment.width, experiment.height])'; % TRANSPOSE
    end
  case '.bin'
    if(~isfield(experiment, 'multiDriveMode') || ~experiment.multiDriveMode)
      if(partial)
        fseek(fid, experiment.frameSize*(frame-1)+(pixelList(1)-1)*experiment.bpp/8, 'bof');
        img = fread(fid, pixelLength, experiment.pixelType);
        if(length(pixelLength) ~= length(pixelList))
          img = img(pixelList-pixelList(1)+1);
        end
        if(nargin == 2)
          closeVideoStream(fid);
        end
        return;
      end
      fseek(fid, experiment.frameSize*(frame-1), 'bof');
      img = fread(fid, experiment.frameSize/(experiment.bpp/8), experiment.pixelType);
    else
      currentID = experiment.driveFrameIndex(frame);
      fseek(fid(currentID), experiment.frameSize*experiment.driveFramePosition(frame), 'bof');
      img = fread(fid(currentID), experiment.frameSize/(experiment.bpp/8), experiment.pixelType);
    end
    img = reshape(img, [experiment.height, experiment.width]);
  case {'.tif', '.tiff'}
    if(isfield(experiment, 'multitiff') && experiment.multitiff)
      img = imread(experiment.handle, frame);
    else
      [fpa, fpb, fpc] = fileparts(experiment.handle);
      img = imread([fpa filesep fpb(1:regexp(fpb, '_\d*$')) num2str(frame) fpc]);
    end
    if(partial)
      img = img(pixelList);
    end
  case '.btf'
    img = imread(experiment.handle, frame);
    if(partial)
      img = img(pixelList);
    end
  case '.dcimg'
    fseek(fid, 232 + experiment.frameSize*(frame-1), 'bof');
    img = fread(fid, experiment.frameSize/(experiment.bpp/8), experiment.pixelType);
    %img = img(1:experiment.width*experiment.height); % In case it is not the full image
    %img = fread(fid,frameSize/2, 'int16');
    %img = reshape(img, [experiment.width, experiment.height])';
    img = reshape(img, [experiment.frameSize/experiment.height/(experiment.bpp/8), experiment.height])'; % TRANSPOSE
    img = img(:, 1:experiment.width);
    if(partial)
      img = img(pixelList);
    end
  case {'.avi', '.mj2'}
    img = read(fid, frame);
    if(size(img, 3) == 3)
      img = rgb2gray(img);
    end
    if(partial)
      img = img(pixelList);
    end
  case '.mat'
    img =  experiment.data(:, :, frame);
    if(partial)
      img = img(pixelList);
    end
  case 'dummy'
    img = zeros(experiment.height, experiment.width);
  otherwise
    img = [];
end

% Now the background correction
if(isfield(experiment, 'backgroundImageCorrection') && experiment.backgroundImageCorrection)
%   if(experiment.backgroundImageMultiplier == 1)
%     img = img + experiment.backgroundImage;
%   else
%     img = img - experiment.backgroundImage;
%   end

  switch experiment.backgroundImageCorrectionMode
    case 'substract'
      img = img - experiment.backgroundImage;
    case 'add'
      img = img + experiment.backgroundImage;
    case 'multiply'
      img = img.*experiment.backgroundImage;
    case 'divide'
      img = double(img)./double(experiment.backgroundImage);
      img = uint16(img);
  end
end
if(nargin == 2)
  closeVideoStream(fid);
end
