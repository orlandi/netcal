function [minIntensity, maxIntensity] = autoLevelsFIJI(imData, bpp, autoReset, updateAuto, excludeZero)
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
% function [minIntensity, maxIntensity] = autoLevelsFIJI(imData, bpp, autoReset, updateAuto, excludeZero)
%   downSampled = false;
%   if(bpp == 32)
%     bpp = 16;
%     imData = double(imData)/2^16;
%     downSampled = true;
%   end
%   persistent auto;
%   if(isempty(auto))
%     auto = 10000;
%   end
%   if(nargin < 5 || isempty(excludeZero))
%     excludeZero = false;
%   end
%   if(nargin < 4 || isempty(updateAuto))
%     updateAuto = true;
%   end
%   if(nargin < 3 || isempty(autoReset))
%     autoReset = false;
%   end
%   if(updateAuto)
%     auto = auto/2;
%     if(autoReset || auto < 2)
%       auto = 5000;
%     end
%   end  
%   % Remove NaNs
%   imData(isnan(imData)) = [];
%   
%   if(excludeZero)
%     imData = imData(imData > 0);
%   end
%   pixelCount = numel(imData);
%   limit = pixelCount/2;
%   threshold = pixelCount/auto;
%   
%   [histCount0, histValues] = hist(imData(:), 0:2^bpp-1);
%   histCount = cumsum(histCount0);
%   minIntensity = 0;
%   for i = 1:length(histValues)
%     count = histCount(i);
%     if(count > limit)
%       count = 0;
%     end
%     if(count > threshold)
%       minIntensity = i-1;
%       break;
%     end
%   end
%   histCount = cumsum(histCount0, 'reverse');
%   maxIntensity = 2^bpp-1;
%   for i = length(histValues):-1:1
%     count = histCount(i);
%     if(count > limit)
%       count = 0;
%     end
%     if(count > threshold)
%       maxIntensity = i-1;
%       break;
%     end
%   end
%   if(downSampled)
%     minIntensity = minIntensity*2^16;
%     maxIntensity = maxIntensity*2^16;
%   end
% end