function [signalCorrected,baseLine] = ...
  applyCorrection(signal, t, params)
% This code divides the data in sections, and takes the minimum.
% Then the polinomial fit is calculated over this minimum.
dataNormalization = params.dataNormalization;
polyFitType = params.baseLineCorrection.polyFitType;
splineDivisionLength = params.baseLineCorrection.splineDivisionLength;
splineDivisionFraction = params.baseLineCorrection.splineDivisionFraction;
%finalMeanCorrectionFraction = params.baseLineCorrection.finalMeanCorrectionFraction;
fftFrequencies = params.baseLineCorrection.fftFrequencies;

t = t(:);
nFrames = length(t);
dt = t(2)-t(1);

F0 = signal(1);
switch polyFitType
  case 'linear fit'
    dataFit = polyfit(t,signal,1);
    baseLine = polyval(dataFit,t);
    if(~isempty(params.traceFixCorrection))
      % Do the traceFix Correction
      invalidPoints = params.traceFixCorrection;
      diffBaseline = diff(baseLine);
      invalidJump = diffBaseline(invalidPoints);
      for it = 1:length(invalidPoints)
        baseLine(invalidPoints(it)+1:end) = baseLine(invalidPoints(it)+1:end) - invalidJump(it);
      end
    end
    signalCorrected = signal - baseLine + F0;
  case {'spline fitting', 'spline fitting percentile correction'}
    if(strcmpi(polyFitType, 'spline fitting percentile correction'))
      % If true, we need to interpolate
      if(length(t) ~= length(params.avgT))
        baseSignal = interp1(params.avgT, params.avgF, t, 'nearest', 'extrap');
      else
        baseSignal = params.avgF;
      end
       signal = signal - baseSignal;
    end
    framesPerDivision = floor(splineDivisionLength/dt);
    if(framesPerDivision < 1)
      logMsg('Not enough frames per division for spline fitting', 'e');
      return;
    end
    
    splineBlockFrameEdges = 1:framesPerDivision:nFrames;
    % Force the last edge within 5 frames of the recording end
    if(splineBlockFrameEdges(end) <= nFrames -5)
      splineBlockFrameEdges(end+1) = nFrames;
    end
    nSplineBlocks = length(splineBlockFrameEdges)-1;
    splineBlockTedges = t(splineBlockFrameEdges);
    splineBlockMeanT = splineBlockTedges(1:end-1)+diff(splineBlockTedges)/2;
    splineBlockMeanTframes = round(splineBlockFrameEdges(1:end-1)+diff(splineBlockFrameEdges)/2);
    splineBlockSignal = zeros(nSplineBlocks, 1);
    validElementsPerSplineBlock = floor(splineDivisionFraction*framesPerDivision);
    if(splineDivisionFraction > 1)
      logMsg('splineDivisionFraction should be <= 1', 'e');
      return;
    end
    if(validElementsPerSplineBlock == 0)
      logMsg('Not enough elements per division for spline fitting. Try increasing the splineDivisionFraction', 'e');
      return;
    end
    
    % Get the mean signal of each block
    for i = 1:nSplineBlocks
      sortedSplineBlockSignal = sort(signal(splineBlockFrameEdges(i):splineBlockFrameEdges(i+1)));
      splineBlockSignal(i) = mean(sortedSplineBlockSignal(1:min(length(sortedSplineBlockSignal),validElementsPerSplineBlock)));
    end
    
    % Do the fitting and get the baseline
    done = false;
    iters = 0;
    maxIters = 1000;
    while(~done)
      if(params.baseLineCorrection.splineSmoothingParam > 0)
        [curve, ~, ~] = fit(splineBlockMeanT,splineBlockSignal,'smoothingspline', 'SmoothingParam', params.splineSmoothingParam);
      else
        [curve, ~, ~] = fit(splineBlockMeanT,splineBlockSignal,'smoothingspline');
      end
      baseLine = feval(curve,t);
      if(~isempty(params.traceFixCorrection))
        % Do the traceFix Correction
        
        invalidPoints = params.traceFixCorrection;
        diffBaseline = diff(baseLine);
        invalidJump = diffBaseline(invalidPoints);
        for it = 1:length(invalidPoints)
          baseLine(invalidPoints(it)+1:end) = baseLine(invalidPoints(it)+1:end) - invalidJump(it);
        end
      end
      signalCorrected = signal - baseLine + F0;
      if(~params.baseLineCorrection.splineKinkCorrection || iters > maxIters)
        if(iters > maxIters)
          logMsg('Kink correction did not converge', 'w');
        end
        done = true;
      else
        invalid = find(baseLine > signal);
        if(isempty(invalid))
          done = true;
        else
          closestList = [];
          for it = 1:length(invalid)
            [~, closest] = min(abs(splineBlockMeanTframes-invalid(it)));
            closestList = [closestList; closest];
          end
          closestList = unique(closestList);
          splineBlockSignal(closestList) = splineBlockSignal(closestList)*0.99;
          iters = iters + 1;
        end
      end
    end
  case 'fft'
    f = signal;
    %f = detrend(signal);
    %baseLine = signal-f;
    baseLine = zeros(size(f));
    minF = fftFrequencies(1);
    maxF = fftFrequencies(2);
    df = 1/(t(2)-t(1))/length(t);
    %nfft    = 2^nextpow2(length(t));
    %y       = fft(f,nfft);
    y = fft(f);
    if(minF > 0)
      invalidLowerFrames = round(minF/df);
      y(1:invalidLowerFrames) = 0; 
      y(end-invalidLowerFrames+1:end)=0;
    end
    if(maxF < inf)
      invalidUpperFrames = round(maxF/df);
      y(invalidUpperFrames:(end-invalidUpperFrames+1)) = 0;
    end
    %iy = ifft(y,nfft);
    iy = ifft(y);
    signalCorrected = real(iy(1:length(t)));
  case 'none'
    % Do nothing
    signalCorrected = signal;
    baseLine = zeros(size(signalCorrected));
  otherwise % Otherwise it should be a number higher than 1
    if(str2double(polyFitType) > 1)
      dataFit = polyfit(t, signal, polyFitType);
      baseLine = polyval(dataFit, t);
      if(~isempty(params.traceFixCorrection))
        % Do the traceFix Correction
        invalidPoints = params.traceFixCorrection;
        diffBaseline = diff(baseLine);
        invalidJump = diffBaseline(invalidPoints);
        for it = 1:length(invalidPoints)
          baseLine(invalidPoints(it)+1:end) = baseLine(invalidPoints(it)+1:end) - invalidJump(it);
        end
      end
      signalCorrected = signal - baseLine + F0;
    else
      logMsg('Invalid polyFitType', 'e');
      return;
    end
end

%%% Moving percentile F0 correction
if(params.movingPercentileCorrection.active)
  prctileValue = params.movingPercentileCorrection.percentileThreshold;
  if(~isempty(params.movingPercentileCorrection.windowLength))
    windowSize = ceil(params.movingPercentileCorrection.windowLength/dt);
    %F0 = arrayfun(@(x) prctile(signalCorrected(max(1,x-windowSize):end), prctileValue), 1:length(signalCorrected))';
    %F0 = movquant(signalCorrected(:), prctileValue/100, windowSize);
    F0 = movquant(signalCorrected(:), prctileValue/100, windowSize, 1, false, 'truncate');
  else
    F0 = prctile(signalCorrected, prctileValue)';
  end
end

% Data normalization after fitting
switch dataNormalization
  case '100x(F-F0)/F0'
    signalCorrected = 100*(signalCorrected/mean(signalCorrected)-1);
  case '(F-F0)/F0'
    signalCorrected = signalCorrected/mean(signalCorrected)-1;
  case '(F-F0)/F0 fixed'
    signalCorrected = ((signalCorrected-double(F0))./double(F0));
  case '100x(F-F0)/F0 fixed'
    signalCorrected = 100*((signalCorrected-double(F0))./double(F0));
  otherwise
end

% Final baseline correction
%meanBlock = prctile(signalCorrected, finalMeanCorrectionFraction*100);
%signalCorrected = signalCorrected-meanBlock;

