function [minIntensity, maxIntensity] = autoLevelsFIJI2(imData, bpp, autoReset, updateAuto, excludeZero)
  persistent auto;
  if(isempty(auto))
    auto = 0.1;
  end
  if(nargin < 5 || isempty(excludeZero))
    excludeZero = false;
  end
  if(nargin < 4 || isempty(updateAuto))
    updateAuto = true;
  end
  if(nargin < 3 || isempty(autoReset))
    autoReset = false;
  end
  if(updateAuto)
    auto = auto*2;
    if(autoReset || auto > 49)
      auto = 0.05;
    end
  end  
  % Remove NaNs
  imData(isnan(imData)) = [];
  
  if(excludeZero)
    imData = imData(imData > 0);
  end
  %pixelCount = numel(imData);
  %limit = pixelCount/2;
  %threshold = pixelCount/auto;
  minIntensity = prctile(imData(:), auto);
  
  maxIntensity = prctile(imData(:), 100-auto);
end