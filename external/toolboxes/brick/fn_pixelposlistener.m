function hl = fn_pixelposlistener(hobj,callback)
% function hl = fn_pixelposlistener(hobj,callback)
%---
% Add a listener that will execute whenever the pixel position of an object
% is changed. 
% In Matlab version R2014b and later, this just adds a listener to the
% object 'LocationChanged' event. In earlier versions, this is a wrapper
% for pixelposwatcher class.
%
% See also fn_pixelpos, fn_pixelsizelistener

% Thomas Deneux
% Copyright 2015-2017

if fn_matlabversion('newgraphics')
    hl = [addlistener(hobj,'LocationChanged',callback) addlistener(hobj,'SizeChanged',callback)];
else
    ppw = pixelposwatcher(hobj);
    hl = addlistener(ppw,'changepos',callback);
end

if nargout==0, clear hl, end
