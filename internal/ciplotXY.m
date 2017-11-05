function h = ciplotXY(lower,upper,xleft,xright,colour)
% ciplot(lower,upper)       
% ciplot(lower,upper,x)
% ciplot(lower,upper,x,colour)
%
% Plots a shaded region on a graph between specified lower and upper confidence intervals (L and U).
% l and u must be vectors of the same length.
% Uses the 'fill' function, not 'area'. Therefore multiple shaded plots
% can be overlayed without a problem. Make them transparent for total visibility.
% x data can be specified, otherwise plots against index values.
% colour can be specified (eg 'k'). Defaults to blue.

% Raymond Reynolds 24/11/06
% Modified by Javier G. Orlandi, 2017

if length(lower)~=length(upper)
    error('lower and upper vectors must be same length')
end

if nargin<5
    colour='b';
end



% convert to row vectors so fliplr can work
if find(size(xleft)==(max(size(xleft))))<2
xleft=xleft'; end
if find(size(xright)==(max(size(xright))))<2
xright=xright'; end
if find(size(lower)==(max(size(lower))))<2
lower=lower'; end
if find(size(upper)==(max(size(upper))))<2
upper=upper'; end

h = fill([xleft fliplr(xright)],[upper fliplr(lower)],colour);


