function [experiment, success] = precacheHISframes(experiment, varargin)
% PRECACHEHISFRAMES run through the HIS file frame by frame, read the
% metadata and store the file location of each frame. Needs to be done
% since metadata size might change from frame to frame
%
% USAGE:
%    experiment = precacheHISframes(experiment)
%
% INPUT arguments:
%    experiment - structure obtained from loadExperiment()
%
% INPUT optional arguments ('key' followed by its value): 
%    'verbose' - true/false. If true, outputs verbose information
%
%    'force' - true/false. If true, always does precaching. If false, only
%    does it if it doesn't exist
%
%    'gui' - handle. Set if using the GUI
%
% OUTPUT arguments:
%    experiment - Structure containing the experiment parameters
%
% EXAMPLE:
%     experiment = precacheHISframes(experiment);
%
% Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also: loadExperiment

params.verbose = true;
params.force = false;
params.pbar = [];
params.frameJump = 512;
params.mode = 'fast'; % 'fast' or 'normal'
params = parse_pv_pairs(params, varargin);
success = true;
% Check if the handle exists. If not, update it
%experiment.handle = strrep(experiment.handle, 'F:\', 'E:\');
if(experiment.handle(1) == 0 || ~exist(experiment.handle, 'file'))
  if(experiment.handle(1) ~= 0)
    try %#ok<TRYNC>
      if(strcmp(experiment.handle, 'dummy'))
        return;
      end
    end
    [~, fpb, fpc] = fileparts(experiment.handle);
    logMsg(sprintf('Could not find %s ', experiment.handle), 'e');
    [fileName, pathName] = uigetfile([fpb fpc],'Find recording location');
  else
    [fileName, pathName] = uigetfile('Find recording location');
  end
  experiment.handle = [pathName fileName];
  if(experiment.handle(1) == 0 || ~exist(experiment.handle, 'file'))
    logMsg('Invalid experiment handle', 'e');
    success = false;
    return;
  else
    logMsg(sprintf('experiment handle updated to %s ', experiment.handle));
  end
end

[~, ~, fpc] = fileparts(experiment.handle);
% IF extension is not HIS, no need to do anythig
if(~strcmpi(fpc, '.HIS'))
  return;
end

if(isfield(experiment, 'frameOffsetList') && ~params.force)
  return;
end

fileName = experiment.handle;
fid = fopen(fileName, 'r');

% Get byte offset of each frame since metadata might have variable size
experiment.frameOffsetList = zeros(experiment.numFrames, 1);
experiment.metadataBytesList = zeros(experiment.numFrames, 1);
fseek(fid, 0, 'bof');

if(params.verbose && isempty(params.pbar) && strcmpi(params.mode,'normal'))
  ncbar('Precaching frames from HIS file');
  params.pbar = 1;
end

switch params.mode
  case 'normal'
    for i = 1:experiment.numFrames
        fseek(fid, 2, 'cof');
        experiment.metadataBytesList(i) = fread(fid, 1, 'short');
        fseek(fid, 60+experiment.metadataBytesList(i), 'cof');
        experiment.frameOffsetList(i) = ftell(fid);
        fseek(fid, experiment.width*experiment.height*experiment.bpp/8, 'cof');

        if(params.verbose && ~isempty(params.pbar))
            ncbar.update(i/experiment.numFrames);
        end
    end
  case 'fast'
    frameSize = experiment.width*experiment.height*experiment.bpp/8;
    done = false;
    baseFrameJump = params.frameJump;
    frameJump = baseFrameJump;
    cFrame = 1;
    % Get metadata size of the first frame
    fseek(fid, 2, 'bof');
    md = fread(fid, 1, 'short');
    experiment.metadataBytesList(1) = md;
    experiment.frameOffsetList(1) = 64+md;
    totalFrameSize = 64+frameSize+md;
    while(~done)
      nFrame = cFrame + frameJump;
      if(nFrame >= experiment.numFrames)
        nFrame = experiment.numFrames;
        frameJump = nFrame-cFrame;
      end
      oldmd = md;
      %experiment.frameOffsetList(cFrame)+totalFrameSize*(frameJump-1)+frameSize+2
      fseek(fid, experiment.frameOffsetList(cFrame)+totalFrameSize*(frameJump-1)+frameSize+2, 'bof');
      md = fread(fid, 1, 'short');
      % Check if the file is invalid
      if(frameJump == 1 && md <= 0)
        logMsg(sprintf('HIS file might be incomplete. Found %d instead of %d valid frames', cFrame, experiment.numFrames), 'e');
        experiment.numFrames = cFrame-2;
        experiment.totalTime = experiment.numFrames/experiment.fps;
        experiment.metadataBytesList(1:experiment.numFrames);
        experiment.frameOffsetList(1:experiment.numFrames);
        break;
      end
      if(~isnan(oldmd) && md ~= oldmd)
        %fprintf('Inconsistency on frame %d\n', nFrame);
        frameJump = max(1,floor(frameJump/2));
        if(frameJump == 1)
          md = nan;
        else
          md = oldmd;
          continue;
        end
        if(nFrame == experiment.numFrames)
          done = true;
        end
      else
        experiment.metadataBytesList((cFrame+1):nFrame) = md;
        experiment.frameOffsetList((cFrame+1):nFrame) = experiment.frameOffsetList(cFrame)+totalFrameSize*((1:frameJump)-1)+frameSize+64+md;
        frameJump = baseFrameJump;
        cFrame = nFrame;
        totalFrameSize = 64+frameSize+md;
        if(nFrame == experiment.numFrames)
          done = true;
        end
      end
    end
end
if(params.verbose && ~isempty(params.pbar) && strcmpi(params.mode,'normal'))
  ncbar.update(1);
  if(params.pbar == 1)
    ncbar.close();
  end
end
metadataInconsistency = find(diff(experiment.metadataBytesList)~=0);
if(~isempty(metadataInconsistency))
  frameList = strtrim(sprintf('%d, ', metadataInconsistency(:)+1));
  frameList = frameList(1:end-1);
  logMsg(sprintf('Variable HIS metadata found on frames: %s\n', frameList));
end

% Now let's add a check for corrupted HIS files (missing frames)
lastInvalidFrame = [];
for it = experiment.numFrames:-1:1
  fseek(fid, experiment.frameOffsetList(it), 'bof');
  fread(fid, 1, 'short'); % Read one short to test for feof
  if(~feof(fid))
    break;
  else
    lastInvalidFrame = it;
  end
end
if(~isempty(lastInvalidFrame))
  logMsg(sprintf('HIS file is incomplete. Found %d instead of %d valid frames', it-1, experiment.numFrames), 'e');
  experiment.numFrames = it;
  experiment.totalTime = experiment.numFrames/experiment.fps;
  experiment.metadataBytesList(1:experiment.numFrames);
  experiment.frameOffsetList(1:experiment.numFrames);
end

fclose(fid);

end