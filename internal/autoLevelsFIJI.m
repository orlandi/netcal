function [minIntensity, maxIntensity] = autoLevelsFIJI(imData, bpp, autoReset, updateAuto)
  persistent auto;
  if(isempty(auto))
    auto = 10000;
  end
  if(nargin < 4)
    updateAuto = true;
  end
  if(nargin < 3)
    autoReset = false;
  end
  if(updateAuto)
    auto = auto/2;
    if(autoReset || auto < 2)
      auto = 5000;
    end
  end  
      
  pixelCount = numel(imData);
  limit = pixelCount/2;
  threshold = pixelCount/auto;
  [histCount0, histValues] = hist(imData(:), 0:2^bpp-1);
  histCount = cumsum(histCount0);
  minIntensity = 0;
  for i = 1:length(histValues)
    count = histCount(i);
    if(count > limit)
      count = 0;
    end
    if(count > threshold)
      minIntensity = i-1;
      break;
    end
  end
  histCount = cumsum(histCount0, 'reverse');
  maxIntensity = 2^bpp-1;
  for i = length(histValues):-1:1
    count = histCount(i);
    if(count > limit)
      count = 0;
    end
    if(count > threshold)
      maxIntensity = i-1;
      break;
    end
  end
end