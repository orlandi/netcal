function [meanTime, burstLength, IBI] = detectGlobalBursts(avgF, T, varargin)
% DETECTGLOBALBURSTS creates a new firings from a subset of electrodes
%       Standard paremeters:
%       --------------------
%       binSize: histogram binning
%       maxGap: in s
%       debug: true/false
%       threshold: in sigma deviations

params.maxGap = 0.1;
%params.maxGap = 1;
params.threshold = 3;
params.debug = false;
params = parse_pv_pairs(params,varargin);

if(params.debug)
    figure;
end

x = T;
y = avgF;
stdy = std(y);
meany = mean(y);
y((y-meany) < params.threshold*stdy) = 0;
if(params.debug)
    hold on;plot(x,y,'r.');
    line(xlim, [1 1]*(meany+params.threshold*stdy));
    line(xlim, [1 1]*(meany));
end
% Coordinates with bursts
ypos = find(y ~= 0);

i = 1;
k=1;
initialTime = [];
finalTime = [];
% Start by setting the burst limits
length(ypos)
while(i <= length(ypos))
    j = i+1;
    while(j <= length(ypos))
        if((ypos(j) - ypos(i)) == (j-i))
            j = j+1;
        elseif((x(ypos(j))-x(ypos(j-1))) < params.maxGap)
            j = j+1;
        else
            initialTime(k) = x(ypos(i));
            finalTime(k) = x(ypos(j-1));
            k = k+1;
            i = j-1;
            j = 1;
            break;
        end
    end
    if((j >= length(ypos)) || (i == length(ypos)))
        initialTime(k) = x(ypos(i));
        finalTime(k) = x(ypos(end));
        break;
    end
    i=i+1;
end
burstLength = finalTime-initialTime;

meanTime = initialTime+(finalTime-initialTime)/2; % Duh
IBI = diff(meanTime);
