function P = plot_arc(a,b,h,k,r1,r2,l)
% Plot a circular arc as a pie wedge.
% a is start of arc in radians, 
% b is end of arc in radians, 
% (h,k) is the center of the circle.
% r is the radius.
% Try this:   plot_arc(pi/4,3*pi/4,9,-4,3)
% Author:  Matt Fig
t = linspace(a,b,l);
x1 = r1*cos(t) + h;
y1 = r1*sin(t) + k;
x2 = r2*cos(t(end:-1:1)) + h;
y2 = r2*sin(t(end:-1:1)) + k;

x = [x1 x2];
y = [y1 y2];
P = fill(x,y,'r');
%axis([h-r2-1 h+r2+1 k-r2-1 k+r2+1]) 
%axis square;
