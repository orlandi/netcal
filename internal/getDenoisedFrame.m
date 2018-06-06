function img = getDenoisedFrame(experiment, frame, denoisedBlocksPerFrame, subsetData, showMeans)
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

if(nargin < 4 || isempty(subsetData))
  denoisedData = experiment.denoisedData;
else
  denoisedData = subsetData;
end
if(nargin < 5)
  showMeans = true;
end
  
img = zeros(experiment.height, experiment.width);
validBlocks = find(denoisedBlocksPerFrame(:,1) <= frame & denoisedBlocksPerFrame(:,2) >= frame);
%valid = find(activeComponents);
for it = 1:length(validBlocks)
  currentBlock = validBlocks(it);
  % Temporary hack to fix block size on previous denoised data
  denoisedData(currentBlock).blockSize = denoisedData(currentBlock).blockCoordinatesLast-denoisedData(currentBlock).blockCoordinates+1; 
  %validCoeff = experiment.denoisedData(currentBlock).coeff;
  %validCoeff(:, ~activeComponents) = 0;
  if(isfield(denoisedData(currentBlock), 'frameList'))
    blockFrame = denoisedData(currentBlock).frameList(frame-denoisedData(currentBlock).frames(1)+1);
  else
    blockFrame = frame-denoisedData(currentBlock).frames(1)+1;
  end
  
  %Xapprox = experiment.denoisedData(currentBlock).score(blockFrame, :) * experiment.denoisedData(currentBlock).coeff';
  %Xapprox = experiment.denoisedData(currentBlock).score(blockFrame, :)*validCoeff';
  %if(length(valid) == size(experiment.denoisedData(currentBlock).score, 2))
  
  Xapprox = denoisedData(currentBlock).score(blockFrame, :)*denoisedData(currentBlock).coeff';
  
  %else
  %  Xapprox = experiment.denoisedData(currentBlock).score(blockFrame, valid)*experiment.denoisedData(currentBlock).coeff(:, valid)';
  %end
  if(showMeans)
    Xapprox = bsxfun(@plus,denoisedData(currentBlock).means, Xapprox); % add the mean back in
  end
  
  %denoisedData(currentBlock)
  Xapprox = reshape(Xapprox, [denoisedData(currentBlock).blockSize(1), denoisedData(currentBlock).blockSize(2)]);
  % Heh, it's actually the opposite probably
  %Xapprox = Xapprox';
  
  img(denoisedData(currentBlock).pixelList) = img(denoisedData(currentBlock).pixelList)+Xapprox(:);
  
end

if(isfield(denoisedData(1),'mask'))
  img = img.*denoisedData(1).mask;
end

if(denoisedData(1).needsTranspose)
  img = img';
end
