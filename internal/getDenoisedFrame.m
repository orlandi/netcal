function img = getDenoisedFrame(experiment, frame, denoisedBlocksPerFrame)
% GETDENOISEDFRAME get a given frame from a denoised movie
%
% USAGE:
%    img = getDenoisedFrame(experiment, frame, denoisedBlocksPerFrame)
%
% INPUT arguments:
%    experiment - structure obtained from loadExperiment()
%
%    frame - selected frame (starts at 1)
%
%    denoisedBlocksPerFrame - first and last frames of each block
%
% OUTPUT arguments:
%    img - frame data
%
% EXAMPLE:
%     img = getDenoisedFrame(experiment, frame, denoisedBlocksPerFrame)
%
% REFERENCES:
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
% See also: loadExperiment

  selectedFrame = frame;
  
  img = nan(experiment.height, experiment.width);
  validBlocks = find(denoisedBlocksPerFrame(:,1) <= selectedFrame & denoisedBlocksPerFrame(:,2) >= selectedFrame);
  
  for it = 1:length(validBlocks)
    currentBlock = validBlocks(it);
    blockFrame = selectedFrame-experiment.denoisedData(currentBlock).frames(1)+1;
    Xapprox = experiment.denoisedData(currentBlock).score(blockFrame, :) * experiment.denoisedData(currentBlock).coeff';
    Xapprox = bsxfun(@plus,experiment.denoisedData(currentBlock).means, Xapprox); % add the mean back in

    Xapprox = reshape(Xapprox, [experiment.denoisedData(currentBlock).blockSize(1), experiment.denoisedData(currentBlock).blockSize(2)]);
    % Heh, it's actually the opposite probably
    Xapprox = Xapprox;
    img(experiment.denoisedData(currentBlock).pixelList) = Xapprox;
  end
  if(experiment.denoisedData(currentBlock).needsTranspose)
    img = img';
  end
end