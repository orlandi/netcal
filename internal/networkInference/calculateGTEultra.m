function [GTE, sGTE, biasGTE, debugData] = calculateGTEultra(D, G, varargin)
% CALCULATEGTEULTRA calculates GTE from the original data. First itcalculates the joint PDF required for the GTE
% computation. Entries are of the form P(i,j,j_now,j_past,i_past). Same
% order as in the paper. Then it computes all sums to get the final GTE scores
%
% USAGE:
%    GTE = calculateGTEultra(D, G, varargin)
%
% INPUT arguments:
%    D - A vector containing the binned  signal (rows for
%    samples, columns for neurons)
%    G - A vector containing the binned average signal based on the
%    conditioning level, i.e., 1 if the average signal is below CL and 2 if
%    above.
%
% INPUT optional arguments ('key' followed by its value): 
%    'markovOrder' - Markov Order of the process (default 2).
%
%    'IFT' - true/false. If true includes IFT (Instant Feedback Term)
%    (default true).
%
%    'Nsamples' - Number of samples to use. If empty, it will use the whole
%    vector (default empty).
%
%    'verbose' true/false. Prints out some useful information (default true).
%
%    'returnFull' - (true/false). If true returns all the GTE computations
%    based on the conditioning levels. If false, only returns a single
%    score, the one in the first level (default false).
%
% OUTPUT arguments:
%    GTE - The GTE score.
%
% EXAMPLE:
%    GTE = calculateGTEultra(D);

%%% Assign default values
params.markovOrder = [2 2];
params.IFT = true;
params.verbose = true;
params.Nsamples = [];
params.returnFull = false;
params.surrogateType = 'none'; % none / full / partial / jitter / partialJitter / MI - full just conserves the ISI distribution. Partial also conserves global burst structure (based on the conditioning signal)
params.numSurrogates = 100;
params.maxJitter = 2;
params.computeBias = false;
params.numBiasShuffles = 10;
params.debug = false;
params.debugIJ = [1 2];
params.pbar = [];
params = parse_pv_pairs(params,varargin);

sGTE = 0;
biasGTE = 0;
% Just in case
if(params.IFT)
    IFT = 1;
else
    IFT = 0;
end

if(numel(params.markovOrder) == 1)
  ki = params.markovOrder;
  kj = params.markovOrder;
else
  ki = params.markovOrder(1);
  kj = params.markovOrder(2);
end

% Redefine the vectors based on the number of samples
if(~isempty(params.Nsamples))
  Nsamples = params.Nsamples;
  D = D(1:Nsamples, :);
  G = G(1:Nsamples);
end
N = size(D, 2);
try
  bins = length(unique(D(~isnan(D))));
catch
  bins = length(unique(D(1:1000000)));
end

% Calculate the amount of dimensions
dims = ki+kj;
%if(IFT) % Always add now
dims = dims + 2;
%end
uniqueG = length(unique(G));
% To avoid inconsistencies
if(uniqueG == 1)
  uniqueG  = 2;
end
dims = [bins*ones(1, dims), uniqueG];

GTE = zeros(N, N, uniqueG);

if(params.computeBias)
  biasGTE = zeros(N, N, params.numBiasShuffles, uniqueG);
  opt = statset(@bootstrp);
  opt.UseParallel = true;
end
% Create the multidimensional array to store the probability distribution
% Structure: (Jnow, Jpast, Inow, Ipast, G) Past goes in reverse order:
% now-1, now-2, ... Although it doesn't really matter, since all
% sums extend over all the past entries.

origP = zeros(dims);
sizeP = double(size(origP));
ndimsP = ndims(origP);

% To access the matrix with a single index
multipliers = [1 cumprod(sizeP)]';
multipliers = multipliers(1:end-1);
Pnumel = [1:prod(dims(1:end))]';
sz = [Pnumel(end) 1];

% Define some internal variables
totalEntries = (N^2-N)/2;
currentEntry = 0;
firstSample = max(ki,kj)+1;
if(params.verbose)
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  MSG = 'Calculating GTE';
  disp([datestr(now, 'HH:MM:SS'), ' ', MSG]);
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  ncbar(MSG);
end

if(params.debug)
  debugData = struct;
  debugData.IJ = params.debugIJ;
  debugData.D = zeros(length(D), 2);
  debugData.Dshuffles = zeros(length(D), params.numSurrogates);
else
  debugData = [];
end

validSamples = firstSample:size(D,1);
T = length(validSamples);
%%% Let's compute the subcoordinate of each trace
multI = cell(N, 1);
multJ = cell(N, 1);


for i = 1:N
  Di = D(:, i);
  multDij = zeros(T, max(ki,kj)+1);
  multDij(:, 1) = Di(firstSample:end);
  for l = 1:max(ki,kj)
    multDij(:, l+1) = Di((firstSample-l):(end-l));
  end
  multI{i} = [0*multDij(:,1:(kj+1)), multDij(:,1:(ki+1))-1, zeros(T, 1)]*multipliers;
  multJ{i} = [multDij(:,1:(kj+1))-1, 0*multDij(:,1:(ki+1)), zeros(T, 1)]*multipliers;
end
multG = [0*multDij(:,1:(kj+1)), 0*multDij(:,1:(ki+1)), G(validSamples)-1]*multipliers;

% If we use MI-based surrogates, we need to store the whole PDF
if(strcmpi(params.surrogateType, 'MI'))
  fullPDF = cell(N);
else
  fullPDF = [];
end

for i = 1:N
  partCoordsIJ = multI{i}+multG+1;
  partCoordsJI = multJ{i}+multG+1;

  for j = (i+1):N
    %P = zeros(dims);
    indxIJ = partCoordsIJ+multJ{j};
    indxJI = partCoordsJI+multI{j};
    
    for revIt = 1:2 % Iterator for symmetric connections
      if(revIt == 1)
        [curGTE, curP] = fromIdxToGTE(indxIJ, origP, Pnumel, ndimsP, bins, ki, kj, IFT);
        GTE(i, j, :) = curGTE;
        if(params.debug)
          if(i == debugData.IJ(1) & j == debugData.IJ(2))
            debugData.P = curP;
            debugData.GTE = GTE;
          end
        end
        if(strcmpi(params.surrogateType, 'MI'))
          fullPDF{i, j} = curP;
        end
        if(params.computeBias)
          %bootstat = bootstrp(10,@(x)fromIdxToGTE(x,origP, Pnumel, ndimsP, bins, k), ones(size(indxIJ)), 'weights', indxIJ);
          bootstat = bootstrp(params.numBiasShuffles, @(x)fromIdxToGTE(x,origP, Pnumel, ndimsP, bins, ki, kj, IFT), indxIJ, 'Options', opt);
          %biasGTE(i, j, :) = curGTE-mean(bootstat, 1)';
          biasGTE(i, j, :, :) = bootstat;
          %biasGTE(i, j, :) = curGTE;
        end
      else
        [curGTE, curP] = fromIdxToGTE(indxJI, origP, Pnumel, ndimsP, bins, ki, kj, IFT);
        GTE(j, i, :) = curGTE;
        if(params.computeBias)
          %bootstat = bootstrp(10,@(x)fromIdxToGTE(x,origP, Pnumel, ndimsP, bins, k), ones(size(indxIJ)), 'weights', indxIJ);
          bootstat = bootstrp(params.numBiasShuffles, @(x)fromIdxToGTE(x,origP, Pnumel, ndimsP, bins, ki, kj, IFT), indxJI, 'Options', opt);
          %biasGTE(j, i, :) = curGTE-mean(bootstat, 1)';
          biasGTE(j, i, :, :) = bootstat;
        end
        if(strcmpi(params.surrogateType, 'MI'))
          fullPDF{j, i} = curP;
        end
      end
    end
    
    currentEntry = currentEntry+1;
    %if(params.verbose && mod(currentEntry, floor(totalEntries/100)) == 0)
    if(params.verbose)
      ncbar.update(currentEntry/totalEntries);
    elseif(params.pbar > 0)
      ncbar.update(currentEntry/totalEntries);
    end
  end
end
% Now the return part
if(~params.returnFull)
  GTE = GTE(:,:,1);
end

%%% Now we will do the pass for the surrogates. There's a little bit of overhead, but it's better this way
switch params.surrogateType
  case {'partial', 'partialJitter'} % Conditioning-based randomization
    Nsurrogates = params.numSurrogates;
    sGTE = zeros(N, N, Nsurrogates, uniqueG);
    jumpsStart = [1; find(diff(G) ~= 0)+1];
    jumpsFinish = [jumpsStart(2:end)-1; length(G)];
    jumpG = G(jumpsStart);
  case {'jitter', 'full'} % Full randomization
    Nsurrogates = params.numSurrogates;
    sGTE = zeros(N, N, Nsurrogates, uniqueG);
  case 'MI'
    Nsurrogates = params.numSurrogates;
    sGTE = zeros(N, N, Nsurrogates, uniqueG);
  otherwise
    fprintf('\n');
    if(params.verbose)
      ncbar.close();
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      MSG = 'Done!';
      disp([datestr(now, 'HH:MM:SS'), ' ', MSG]);
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    end
    return;
end

if(params.verbose)
  ncbar.setCurrentBarName('Generating surrogate data');
end
currentEntry = 0;
fullDs = [];
for i = 1:N
  % For each I->J connection, generate first all surrogates of I
  multIs = cell(Nsurrogates, 1);
  origDs = D(:, i);
  spikeSamples = find(origDs > 1); % Since it's 1-2 indexing
  spikeSamplesISI = [spikeSamples(1) diff(spikeSamples)'];
  Nsamples = length(spikeSamplesISI);

  for s = 1:Nsurrogates
    k = params.markovOrder; % FFS
    % Here we should generate the surrogates and get a new Ds
    switch params.surrogateType
      case 'partial'
        Ds = ones(size(origDs));
        if(isempty(spikeSamplesISI))
          Ds = origDs;
        else
          % Iterate through all frame sets with the same G value
          for it = 1:length(jumpsStart)
            firstFrame = jumpsStart(it);
            lastFrame = jumpsFinish(it);
            validSpikes = spikeSamples(spikeSamples >= firstFrame & spikeSamples <= lastFrame);
            if(~isempty(validSpikes))
              validSpikesISI = [validSpikes(1)-(firstFrame-1) diff(validSpikes)']; % Need to substract first frame so all are real ISIs
              NvalidSpikes = length(validSpikesISI);
              newISIlist = cumsum(validSpikesISI(randi(NvalidSpikes, 1, NvalidSpikes)));
              newISIlist = firstFrame-1+newISIlist(newISIlist < (lastFrame-firstFrame+1)); % Smallest ISI of 1 should hit the firstFrame value, that's what the -1 is there for
              Ds(newISIlist) = 2; % Hopefully this works
            end
          end
        end
      case 'partialJitter'
        Ds = ones(size(origDs));
        if(isempty(spikeSamples))
          Ds = origDs;
        else
          spikeSamplesNew = spikeSamples+randi([-1 1]*params.maxJitter, size(spikeSamples));
          spikeSamplesNew(spikeSamplesNew < 1) = 1;
          spikeSamplesNew(spikeSamplesNew > length(origDs)) = length(origDs);
          % Do not allow spikes to change Conditioning level. Those that do, move back
          try
            invalid = find(G(spikeSamplesNew) ~= G(spikeSamples));
            spikeSamplesNew(invalid) = spikeSamples(invalid);
          catch ME
            logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
          end
          
          Ds = ones(size(origDs));
          Ds(spikeSamplesNew) = 2;
        end
      case 'jitter'
        Ds = ones(size(origDs));
        if(isempty(spikeSamples))
          Ds = origDs;
        else
          spikeSamples = spikeSamples+randi([-1 1]*params.maxJitter, size(spikeSamples));
          spikeSamples(spikeSamples < 1) = [];
          spikeSamples(spikeSamples > length(origDs)) = [];
          Ds = ones(size(origDs));
          Ds(spikeSamples) = 2;
%           if(any(Ds ~= origDs))
%             i
%           end
        end
      case 'full'
        Ds = ones(size(origDs));
        if(isempty(spikeSamplesISI))
          Ds = origDs;
        else
          % For now, let's maintain the ISI distribution AND the number of spikes
          newISIlist = cumsum(spikeSamplesISI(randi(Nsamples, 1, Nsamples)));
          newISIlist = newISIlist(newISIlist < length(Ds));
          Ds(newISIlist) = 2;  
        end
      otherwise
        Ds = ones(size(origDs));
        break;
    end
    if(params.debug)
      if(i == debugData.IJ(1))
        debugData.Dshuffles(:, s) = Ds;
      end
    end
    multDs = zeros(T, max(ki,kj)+1);
    multDs(:, 1) = Ds(firstSample:end);
    for l = 1:max(ki,kj)
      multDs(:, l+1) = Ds((firstSample-l):(end-l));
    end
    multIs{s} = [0*multDs(:,1:(kj+1)), multDs(:,1:(ki+1))-1, zeros(T, 1)]*multipliers;
  end

  % Need to do all checks, no symmetries
  sGTEi = zeros(size(sGTE, 2), size(sGTE, 3), size(sGTE, 4));
  surr = params.surrogateType;
  for j = 1:N
    if(i == j)
      currentEntry = currentEntry+1/N;
      continue;
    end
    % For MI need to generate new time series every time
    if(strcmpi(surr, 'MI'))
      partialTransferJ = multJ{j} + multG;
      [i j]
      %for s = 1:Nsurrogates
        %[i j s]
      curPDF = fullPDF{i, j};
      Ds = D(:,j);
      Ds = repmat(Ds, [1 Nsurrogates]);
      for l = firstSample:size(D, 1)
        
        transfer1b = partialTransferJ(l-firstSample+1) + [zeros(Nsurrogates, 1), Ds(l-(1:ki),:)'-1]*multipliers((ki+2):(end-1))+1;
        transfer2b = partialTransferJ(l-firstSample+1) + [ones(Nsurrogates, 1), Ds(l-(1:ki),:)'-1]*multipliers((ki+2):(end-1))+1;
        
        TransferMatrix = [curPDF(transfer1b) curPDF(transfer2b)];
        invalid = (sum(TransferMatrix, 2) == 0);
        valid = find(sum(TransferMatrix, 2) ~= 0);
        Ds(l, invalid) = D(l);
        if(isempty(valid))
          continue;
        end
        cMat = cumsum(TransferMatrix,2)./repmat(sum(TransferMatrix,2), [1, 2]); % The over sum is equivalent to the conditioning on the summed variable
        hit = bsxfun(@gt,cMat(valid, :),rand(size(valid)));
        [~, validIdx] = max(hit, [], 2);
        
        Ds(l, valid) = validIdx;
      end
      if(params.debug)
        %if(i == debugData.IJ(1))
        %  debugData.Dshuffles = Ds;
        %end
      end
      %multIs = cell(Nsurrogates, 1);
      sGTEij = zeros(size(sGTE, 3), size(sGTE, 4));
      for s = 1:Nsurrogates
        multDs = zeros(T, max(ki,kj)+1);
        multDs(:, 1) = Ds(firstSample:end, s);
        for l = 1:max(ki,kj)
          multDs(:, l+1) = Ds((firstSample-l):(end-l), s);
        end
        tmpMultIs = [0*multDs(:,1:(kj+1)), multDs(:,1:(ki+1))-1, zeros(T, 1)]*multipliers;
        indxIJ = tmpMultIs+multG+1+multJ{j};
        sGTEij(s, :) = fromIdxToGTE(indxIJ, origP, Pnumel, ndimsP, bins, ki, kj, IFT);
        %sGTE(i, j, s, :) = curGTE;
        %sGTEi(j, s, :) = curGTE;
      end
      sGTEi(j, :, :) = sGTEij;
    else
      % The check for each surrogate
      sGTEij = zeros(size(sGTE, 3), size(sGTE, 4));
      for s = 1:Nsurrogates
        %P = zeros(dims);
        indxIJ = multIs{s}+multG+1+multJ{j};
        sGTEij(s, :) = fromIdxToGTE(indxIJ, origP, Pnumel, ndimsP, bins, ki, kj, IFT);
        %sGTE(i, j, s, :) = curGTE;
        %sGTEi(j, s, :) = curGTE;
      end
      sGTEi(j, :, :) = sGTEij;
    end
    if(params.debug)
%       if(i == debugData.IJ(1) & j == debugData.IJ(2))
%         debugData.D(:, 1) = D(:, i);
%         debugData.D(:, 2) = D(:, j);
%       end
    end
    currentEntry = currentEntry+1/N;
  end
  sGTE(i, :, :, :) = sGTEi;
  if(params.verbose)
    ncbar.update(currentEntry/N);
  end
end
% Now the return part
if(~params.returnFull)
  sGTE = sGTE(:,:,:,1);
end

fprintf('\n');
if(params.verbose)
  ncbar.close();
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  MSG = 'Done!';
  disp([datestr(now, 'HH:MM:SS'), ' ', MSG]);
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end

end
function [GTE, P] = fromIdxToGTE(indxIJ, origP, Pnumel, ndimsP, bins, ki, kj, IFT)

  P = histcounts(indxIJ, 1:(Pnumel(end)+1))';
  P = reshape(P, size(origP));

  % Now the sums
  P = P/sum(P(:));

  Jnow = sum(P,1);
  tmpRepmat = ones(1,ndimsP);
  tmpRepmat(1) = bins;
  Jnow = repmat(Jnow, tmpRepmat);

  Ipast = P;
  for dim = 1:(ki+IFT)
    Ipast = sum(Ipast,ndimsP-dim+1-IFT);
  end 
  tmpRepmat = ones(1,ndimsP);
  tmpRepmat((end-(ki+IFT-1)):end-1) = bins;
  %tmpRepmat((end-k+1-1):end-1) = bins;
  Ipast = repmat(Ipast, tmpRepmat);

  JnowIpast = sum(Ipast,1);
  tmpRepmat = ones(1,ndimsP);
  tmpRepmat(1) = bins;
  JnowIpast = repmat(JnowIpast, tmpRepmat);

  %%% Now that we have all the partial sums we can calculate all the products
  curGTE = P.*log2(P.*JnowIpast./Jnow./Ipast);
  % IF there was no IFT, we need to sum over the Inow dimension
  if(~IFT)
    curGTE = sum(curGTE, 3);
    curGTE = squeeze(curGTE);
  end
  
  % To fix divisions by 0 due to 0 samples
  curGTE(isnan(curGTE)) = 0;
  % Now sum over all the remaining dimensions but G
  for dim = (ndims(curGTE)-1):-1:1
    curGTE = sum(curGTE, dim);
  end
  curGTE = squeeze(curGTE);
  % Now normalize based on the conditioning. PG will be the sum over all but G
  PG = P;

  for it = 1:(ndims(curGTE)-1)
    PG = sum(PG,it);
  end

  PG = squeeze(PG);

  for it = 1:size(curGTE,3)
    curGTE(it) = curGTE(it)/PG(it);
  end

  GTE = curGTE;
end

