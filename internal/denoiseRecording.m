function experiment = denoiseRecording(experiment, varargin)
% DENOISERECORDING Uses PCA to remove noise from a recording
%
% USAGE:
%    experiment = denoiseRecording(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: denoiseRecordingOptions
%
%    training - true/false 
%
%    trainingBlock - Idx
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = denoiseRecording(experiment, varargin)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also preprocessExperiment

% EXPERIMENT PIPELINE
% name: movie denoiser
% parentGroups: fluorescence: basic
% optionsClass: denoiseRecordingOptions
% requiredFields: handle
% producedFields: denoisedData

%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(denoiseRecordingOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.training = false;
params.trainingBlock = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Running denoiser');
%--------------------------------------------------------------------------

denoisedData = [];
tabulatedValues = 0.05:0.05:1; % These come from https://arxiv.org/abs/1305.5870
tabulatedCts = [1.5066 1.5816  1.6466  1.7048 1.7580 1.8074 1.8537 1.8974 1.9389 1.9786 2.0167 2.0533 2.0887 2.1229 2.1561 2.1883 2.2197 2.2503 2.2802 2.3094];
blockSize = params.blockSize;
readSmallBlocks = params.readSmallBlocks;
frameBlockSize = params.frameBlockSize;

frameBlockList = 1:frameBlockSize:experiment.numFrames;
if(frameBlockList(end) < experiment.numFrames-frameBlockSize/2)
  frameBlockList = [frameBlockList, experiment.numFrames+1];
else
  frameBlockList(end) = experiment.numFrames+1;
end
% Only run the first block in training
if(params.training)
  frameBlockList = frameBlockList(1:2);
end

Nblocks = experiment.height/blockSize(1)*experiment.width/blockSize(2)*(length(frameBlockList)-1);
currentBlock = 0;
for t = 1:length(frameBlockList)-1
  firstFrame = frameBlockList(t);
  lastFrame = frameBlockList(t+1)-1;
  for blockIt2 = 1:experiment.width/blockSize(2)
    for blockIt1 = 1:experiment.height/blockSize(1)
      currentBlock = currentBlock + 1;
      if(params.training)
        if(currentBlock ~= params.trainingBlock)
          continue;
        end
      end
      BID1 = blockIt1;
      BID2 = blockIt2;

      idx1 = blockSize(1)*(BID1-1)+1;
      idx2 = blockSize(2)*(BID2-1)+1;

      data = zeros(experiment.height, experiment.width);
      data(idx1:idx1+blockSize(1)-1, idx2:idx2+blockSize(2)-1) = 1;
      valid = find(data);
      % Create a list of contigous frames to recover
      jumps = [0; find(diff(valid) > 1); length(valid)];
      pixelList = [jumps(1:end-1)+1, jumps(2:end)];
      Nframes = length(firstFrame:lastFrame);
      fullData = zeros(length(valid), Nframes);

      [fID, experiment] = openVideoStream(experiment);
      if(params.training)
        ncbar.setBarTitle('Getting frames');
      end
      for it1 = 1:Nframes
        % For each block of contiguous pixels - turns out it is faster to pull
        % the whole frames
        if(readSmallBlocks)
          for it2 = 1:size(pixelList, 1)
            curPixels = pixelList(it2, 1):pixelList(it2, 2);
            fullData(curPixels, it1) = getFrame(experiment, firstFrame+it1-1, fID, valid(curPixels));
          end
        else
          fullData(:, it1) = getFrame(experiment, firstFrame+it1-1, fID, valid);
        end
        if(params.training)
          ncbar.update(it1/Nframes);
        end
      end
      closeVideoStream(fID);

      % Now the PCA
      fullData = permute(fullData, [2 1]); % We want frames as observations, pixels as variables
      if(params.training)
        ncbar.setBarTitle('Computing PCA');
        ncbar.setAutomaticBar();
      end
      %[coeff, score, latent, tsquared, explained, mu] = pca(fullData); % Here we go
      [U, S, V] = svdecon(fullData); % Using fast SVD instead
      mu = mean(fullData, 1);
      score = U*S;
      latent = diag(S)/sum(diag(S));
      coeff = V;
      
      if(params.training)
        ncbar.unsetAutomaticBar();
      end

      ct = interp1(tabulatedValues, tabulatedCts, size(fullData,1)/size(fullData,2), 'pchip');
      largestComponent = find(latent <= mean(latent)*ct, 1, 'first');
      % Apply the multiplier
      largestComponent = round(largestComponent*params.maximumPCsMultiplier);
      % Consistency checks
      if(largestComponent > length(latent))
        largestComponent = length(latent);
      elseif(largestComponent < 1)
        largestComponent = 1;
      end

      denoisedBlock = struct;
      % If training, return all components
      if(~params.training)
        denoisedBlock.Ncomponents = largestComponent;
      else
        denoisedBlock.Ncomponents = length(latent);
      end
      denoisedBlock.largestComponent = largestComponent;
      denoisedBlock.block = [BID1, BID2];
      denoisedBlock.blockSize = blockSize;
      denoisedBlock.blockCoordinates = [blockSize(1)*(BID1-1)+1, blockSize(2)*(BID2-1)+1];
      data = zeros(experiment.height, experiment.width);
      data(idx1:idx1+blockSize(1)-1, idx2:idx2+blockSize(2)-1) = 1;
      denoisedBlock.pixelList = find(data);
      denoisedBlock.latent = latent;
      denoisedBlock.score = score(:, 1:denoisedBlock.Ncomponents);
      denoisedBlock.coeff = coeff(:, 1:denoisedBlock.Ncomponents);
      denoisedBlock.means = mu;
      denoisedBlock.frames = [firstFrame, lastFrame];
      % Looks like its always needed
      if(strcmp(experiment.extension, '.his'))
        denoisedBlock.needsTranspose = true;
      else
        denoisedBlock.needsTranspose = false;
      end

      denoisedData = [denoisedData, denoisedBlock];
      if(~params.training && params.pbar > 0)
        ncbar.update(currentBlock/Nblocks);
      end
    end
  end
end

if(~params.training)
  experiment.denoisedData = denoisedData;
  experiment.saveBigFields = true; % So the traces are saved
else
  experiment.denoisedDataTraining = denoisedData;
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
