function [d,ib] = findClosest(a,b)
% for each element of vector a find the nearest element in vector b based
% on absolute difference
% a and b must be row vectors
% d ... difference vector
% id ... indices of the differences recorded in d

% very efficiently implemented solution for this problem by Roger Stafford 
% (found on Matlab Central)

m = size(a,2); n = size(b,2);
[~,p] = sort([a,b]);
q = 1:m+n; q(p) = q;
t = cumsum(p>m);
r = 1:n; r(t(q(m+1:m+n))) = r;
s = t(q(1:m));
id = r(max(s,1));
iu = r(min(s+1,n));
[d,it] = min([abs(a-b(id));abs(b(iu)-a)]);
ib = id+(it-1).*(iu-id);