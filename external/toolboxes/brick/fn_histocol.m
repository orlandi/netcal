function fn_histocol(x,xwidth,cidx,cmap)
% function fn_histocol(x,xwidth,cidx,cmap)
%---
% Draw a histogram of x values with bins of width xwidth, and color each
% element according to the provided color indices cidx and color map cmap

% Thomas Deneux
% Copyright 2015-2017

% Input
ok = ~isnan(x) & ~isnan(cidx);
x = x(ok);
cidx = cidx(ok);

% Group x values into bins
x1 = floor(x/xwidth);

% Display
if ~strcmp(get(gca,'NextPlot'),'add'), cla, end
for i=min(x1):max(x1)
    % sort according to y values
    cidxi = sort(cidx(x1==i));
    
    % display each value as a small rectangle
    for j=1:length(cidxi)
        rectangle('position',[i*xwidth j-1 xwidth 1],'facecolor',cmap(cidxi(j),:))
    end
end
