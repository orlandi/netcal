function [Cfull, Ccyc, Cmid, Cin, Cout, Cff, C] = clustering_coef_bd_full(A)
%CLUSTERING_COEF_BD     Clustering coefficient
%
%   [Cfull, Ccyc, Cmid, Cin, Cout, C] = clustering_coef_bd(A);
%
%   The clustering coefficient is the fraction of triangles around a node
%   (equiv. the fraction of node's neighbors that are neighbors of each other).
%
%   Input:      A,      binary directed connection matrix
%
%   Output:     C,      clustering coefficient vector
%
%   Reference: Fagiolo (2007) Phys Rev E 76:026107.
%
%
%   Mika Rubinov, UNSW, 2007-2010
%   Modified Javier G. Orlandi 2018 (to return all Clustering types)

%Methodological note: In directed graphs, 3 nodes generate up to 8 
%triangles (2*2*2 edges). The number of existing triangles is the main 
%diagonal of S^3/2. The number of all (in or out) neighbour pairs is 
%K(K-1)/2. Each neighbour pair may generate two triangles. "False pairs" 
%are i<->j edge pairs (these do not generate triangles). The number of 
%false pairs is the main diagonal of A^2.
%Thus the maximum possible number of triangles = 
%       = (2 edges)*([ALL PAIRS] - [FALSE PAIRS])
%       = 2 * (K(K-1)/2 - diag(A^2))
%       = K(K-1) - 2(diag(A^2))

% Using Fagiolo notation
A = double(A);
din = sum(A',2);
dout = sum(A, 2);
dtot = sum(A+A', 2);
dbi = diag(A^2);

tfull = diag((A+A')^3)/2;
tcyc = diag(A^3);
tmid = diag(A*(A')*A);
tin = diag((A')*A^2);
tout = diag(A^2*(A'));
tff = tmid+tin+tout;

Cfull = tfull./(dtot.*(dtot-1)-2*dbi);
Ccyc = tcyc./(din.*dout-dbi);
Cmid = tmid./(din.*dout-dbi);
Cin = tin./(din.*(din-1));
Cout = tout./(dout.*(dout-1));
Cff = tff./(din.*dout-dbi+din.*(din-1)+dout.*(dout-1));
% Fix NaNs
Cfull((dtot.*(dtot-1)-2*dbi) == 0) = NaN;
Ccyc((din.*dout-dbi) == 0) = NaN;
Cmid((din.*dout-dbi) == 0) = NaN;
Cin((din.*(din-1)) == 0) = NaN;
Cout((dout.*(dout-1)) == 0) = NaN;
Cff(din.*dout-dbi+din.*(din-1)+dout.*(dout-1) == 0) = NaN;

S=A+A.';                    %symmetrized input graph
K=sum(S,2);                 %total degree (in + out)
cyc3=diag(S^3)/2;           %number of 3-cycles (ie. directed triangles)
K(cyc3==0)=inf;             %if no 3-cycles exist, make C=0 (via K=inf)
CYC3=K.*(K-1)-2*diag(A^2);	%number of all possible 3-cycles
C=cyc3./CYC3;               %clustering coefficient

