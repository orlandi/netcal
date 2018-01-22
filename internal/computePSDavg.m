function experiment = computePSDavg(experiment, varargin)
% COMPUTEPSDAVG Computes several average images based on power spectra density at various frequency ranges
%
% USAGE:
%    experiment = computePSDavg(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: computePSDavgOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = computePSDavg(experiment, varargin)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% Based on Simultaneous Denoising, Deconvolution, and Demixing of Calcium Imaging Data http://dx.doi.org/10.1016/j.neuron.2015.11.037
%
% See also preprocessExperiment

% EXPERIMENT PIPELINE
% name: compute PSD Averages
% parentGroups: fluorescence: basic
% optionsClass: computePSDavgOptions
% requiredFields: handle
% producedFields: avgPSD

%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(computePSDavgOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Computing PSD averages');
%--------------------------------------------------------------------------

% Validation checks
if(isempty(params.frameRange)|| length(params.frameRange) ~= 2)
  params.frameRange = [1 experiment.numFrames];
end
if(params.frameRange(1) < 1)
  params.frameRange(1) = 1;
end
if(params.frameRange(2) > experiment.numFrames)
  params.frameRange(2) = experiment.numFrames;
end

blockSize = params.blockSize;

Nblocks = experiment.height/blockSize(1)*experiment.width/blockSize(2);
currentBlock = 0;

firstFrame = params.frameRange(1);
lastFrame = params.frameRange(2);
frameList = firstFrame:params.samplingFreqDivider:lastFrame;
Nframes = length(frameList);

Fs = experiment.fps/params.samplingFreqDivider;

freqLimits = params.freqLimits;
if(isempty(freqLimits))
  freqLimits = [0, experiment.fps/params.samplingFreqDivider/2];
end

avgPSD = cell(length(freqLimits)-1, 1);
for it = 1:length(avgPSD)
  avgPSD{it} = zeros(experiment.width, experiment.height);
end

% List of freqs for FFT
freqList = 0:Fs/Nframes:Fs/2;
[fID, experiment] = openVideoStream(experiment);
for blockIt2 = 1:experiment.width/blockSize(2)
  for blockIt1 = 1:experiment.height/blockSize(1)
    currentBlock = currentBlock + 1;
    
    BID1 = blockIt1;
    BID2 = blockIt2;

    idx1 = blockSize(1)*(BID1-1)+1;
    idx2 = blockSize(2)*(BID2-1)+1;

    data = zeros(experiment.height, experiment.width);
    data(idx1:idx1+blockSize(1)-1, idx2:idx2+blockSize(2)-1) = 1;
    valid = find(data);
    % Create a list of contiguous pixels to recover
    jumps = [0; find(diff(valid) > 1); length(valid)];
    pixelList = [jumps(1:end-1)+1, jumps(2:end)];
    fullData = zeros(length(valid), Nframes);

    
    
    for it1 = 1:length(frameList)
      % For each block of contiguous pixels - turns out it is faster to pull
      % the whole frames
      if(params.readSmallBlocks)
        for it2 = 1:size(pixelList, 1)
          curPixels = pixelList(it2, 1):pixelList(it2, 2);
          fullData(curPixels, it1) = getFrame(experiment, frameList(it1), fID, valid(curPixels));
        end
      else
        fullData(:, it1) = getFrame(experiment, frameList(it1), fID, valid);
      end
      if(params.pbar > 0)
        ncbar.update((currentBlock-1)/Nblocks+it1/Nframes/Nblocks);
      end
    end

    % Now we perform the PSDs
    xdft = fft(fullData');
    xdft = xdft(1:floor(Nframes/2)+1, :);
    xdft = (1/(Fs*Nframes)) * abs(xdft).^2; % Now it;s psd, but keep using the same variable name
    xdft(2:end-1, :) = 2*xdft(2:end-1, :) + eps;
    for it1 = 1:length(avgPSD)
      validFreqs = freqList >= freqLimits(it1);
      validFreqs(freqList > freqLimits(it1+1)) = 0;
      switch params.avgMode
        case 'median'
          avgPSD{it1}(valid) = median(xdft(validFreqs, :)/2);
        case 'mean'
          avgPSD{it1}(valid) = mean(xdft(validFreqs, :)/2);
        case 'logmexp'
          avgPSD{it1}(valid) = sqrt(exp(mean(log(xdft(validFreqs, :)/2))));
      end
    end
    
    if(params.pbar > 0)
      ncbar.update(currentBlock/Nblocks);
    end
  end
end
% Final transpose
avgPSD = cellfun(@(x)x', avgPSD, 'UniformOutput', false);
experiment.avgPSD = avgPSD;


experiment.avgPSDfreqLimits = freqLimits;
closeVideoStream(fID);

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
