function varargout = hsl2rgb(hue,sat,lum)
% function rgb = hsl2rgb(hue,sat,lum)
% function rgb = hsl2rgb(hsl)
% function [r g b] = hsl2rgb(...)

% Thomas Deneux
% Copyright 2015-2017

% input
if nargin==1
    [hue sat lum] = dealc(num2cell(hsl,1));
end
n = max([length(hue) length(sat) length(lum)]);

% hue
hue = 6*mod(hue(:),1); % between 0 and 1 -> between 0 and 6
mid = (1-abs(mod(hue,2)-1)); % between 0 and 1, as a sawtooth-patterned function of hue
rgb = zeros(n,3);
idx = (floor(hue)==0);
rgb(idx,:) = [ones(sum(idx),1) mid(idx) zeros(sum(idx),1)];
idx = (floor(hue)==1);
rgb(idx,:) = [mid(idx) ones(sum(idx),1) zeros(sum(idx),1)];
idx = (floor(hue)==2);
rgb(idx,:) = [zeros(sum(idx),1) ones(sum(idx),1) mid(idx)];
idx = (floor(hue)==3);
rgb(idx,:) = [zeros(sum(idx),1) mid(idx) ones(sum(idx),1)];
idx = (floor(hue)==4);
rgb(idx,:) = [mid(idx) zeros(sum(idx),1) ones(sum(idx),1)];
idx = (floor(hue)==5);
rgb(idx,:) = [ones(sum(idx),1) zeros(sum(idx),1) mid(idx)];

% sat and lum
rgb = fn_mult(lum(:),fn_add(1-sat(:),fn_mult(sat(:),rgb)));

% output
if nargout==3
    varargout = num2cell(rgb,1);
else
    varargout = {rgb};
end
