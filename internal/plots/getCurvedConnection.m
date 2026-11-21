function [xx, yy] = getCurvedConnection(X, Y, prefactor, mode)
if(nargin < 4)
  mode = 'custom';
end
switch mode
  case 'custom'
    % intermediate point (you have to choose your own)
    Xi = mean(X)*prefactor;
    Yi = mean(Y)*prefactor;


    Xa = [X(1) Xi X(2)];
    Ya = [Y(1) Yi Y(2)];

    t  = 1:numel(Xa);
    ts = linspace(min(t),max(t),numel(Xa)*10); % has to be a fine grid
    xx = spline(t,Xa,ts);
    yy = spline(t,Ya,ts);
  case 'tangent'
    x1 = X(1);
    x2 = X(2);
    y1 = Y(1);
    y2 = Y(2);
    y0 = 0;
    x0 = 0;
    m1 = (y1-y0)/(x1-x0);
    m2 = (y2-y0)/(x2-x0);
    m1p = -1./m1;
    m2p = -1./m2;
    xc = (y1-y2-m1p*x1+m2p*x2)/(m2p-m1p);
    yc = y1+m1p*(xc-x1);
    xc = xc*prefactor;
    yc = yc*prefactor;
    %plot([x1 xc], [y1 yc]);
    %plot([x2 xc], [y2 yc]);
    %plot(xc,yc, 'x');
    theta1 = atan2(y1-yc, x1-xc);
    theta2 = atan2(y2-yc, x2-xc);
    t = linspace(theta1,theta2, 500);
    r = sqrt((xc-x1).^2+(yc-y1).^2);
    xx = r*cos(t) + xc;
    yy = r*sin(t) + yc;
    %plot(xx,yy,'--');
end
