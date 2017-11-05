function [xx, yy] = getSigmoidConnection(X, Y, prefactor)


xx = linspace(-3, 3, 100);
yy = erf(xx*prefactor);

xx = X(1)+(xx-xx(1))/(xx(end)-xx(1))*diff(X);
yy = Y(1)+(yy-yy(1))/(yy(end)-yy(1))*diff(Y);