function [W, IX] = nchoosecrit(S, FUN)
% NCHOOSECRIT - subsets (combinations of elements of a set) that fulfill a criterion
%
%   W = NCHOOSECRIT(S, FUN) returns those combinations of one or more elements
%   of the set S (called a subset) that fulfill a specific criterion.
%   This criterion is specified by the function FUN. FUN is a function
%   handle to a function that takes one input argument and returns a
%   logical scalar value.  
%   W will be cell array of row vectors. Each cell of W holds one of the
%   combinations C of S for which FH(C) is true.  
% 
%   [W, IX] = NCHOOSECRIT(S, FUN) also returns the indices, such that
%   S(IX{k}) equals W{k}.
%   
%   Maximally, there are 2^N-1 possible subsets of S (N being the number of
%   elements of S). This number therefore grows rapidly with increasing N.
%   W is a selection of those subsets.
%
%   S can be a cell array, and each cell of W will then contain a cell array.  
%
%   Examples:
%      % find the subsets that sum op to 6
%        nchoosecrit([1 2 3 4 5 6], @(x) sum(x)==6)
%      %  -> { [1 2 3], [2 4], [1 5], [6]}
%
%      % find subgroups of 4 or more people that contain either James or Bob,
%      % but not both!
%        S = {'Bob' 'Tom' 'Joe' 'Bill' 'James', 'Henry'} ; % the whole group
%      % criterion 1:
%        fh1 = @(x) numel(x) >= 4 ; 
%      % criterion 2
%        fhname = @(x,y) any(strncmp(y,x,numel(y))) ;
%        fh2 = @(x) xor(fhname(x,'James'), fhname(x,'Bob')) ;
%      % the 2 criterions combined:
%        fhcomb = @(x) fh1(x) && fh2(x) ;
%      [W, IX] = nchoosecrit(S, fhcomb)
%      S(IX{2}), W{2} % check
%
%   Notes:
%   - If S contain non-unique elements (e.g. S = [1 1 2]), NCHOOSECRIT will
%     return non-unique cells. In other words, NCHOOSECRIT treats all elements
%     of S as being unique. One could use NCHOOSECRIT(UNIQUE(S)) to avoid that.
%   - The output is the same as
%       Wtemp = nchoose(S) ; W = Wtemp(cellfun(Wtemp, fh)) ;
%     but does not create the (possible very large) temporary array Wtemp.
%   
%   See also NCHOOSEK, PERMS
%            NCHOOSE, PERMN, ALLCOMB on the File Exchange

% version 2.0 (feb 2018)
% tested in Matlab 2017b, but should work in most versions
% (c) Jos van der Geest
% http://www.mathworks.nl/matlabcentral/fileexchange/authors/10584
% email: samelinoa@gmail.comw

% History
% 1.1, feb 2013 - inspired by a post on Matlab Answers
% 2.0, feb 2018 - return subset indices as well

narginchk(2,2) ;

N = numel(S) ;
if N == 0
    % nothing to do
    W = {} ;
    IX = {} ;
    return ;
end

try
    % these two tries catch many errors
    X1 = FUN(S(1)) ; % try it on a single element
    X2 = FUN(S) ; % try it on the whole set
catch ME
    disp('This seems to be an invalid criterion function.') ;
    rethrow(ME)
end

if numel(X1) ~= 1 || numel(X2) ~= 1 || ~islogical(X1) || ~islogical(X2)
    error('The criterion function should return a logical scalar.') ;
end

M = (2^N)-1 ; % The total number of possible combinations

% The selection of elements is based on the binary representation of all
% numbers X between 1 and M. This binary representation is is retrieved by
% the formula: bitget(X * (2.^(N-1:-1:0)),N) > 0 
% See NCHOOSE (available on the File Exchange) for details

idx0 = 1:N ;
p2=2.^(N-1:-1:0) ; % This part of the formula can be taken out of the loop

% We pre-allocate the output, but only to a certain extend
W = cell(2^12,1) ;
SetCounter = 0 ; % We'll add the subsets to the list one by one

% loop over all subsets, this can take some time ...
for k=1:M
    % calculate the (reversed) binary representation of k
    % select the elements of the set based on this representation
    tf = bitget(k*p2, N) > 0 ;
    subset = S(tf) ;
    if FUN(subset)
        % does it fullfill the criterion? 
        SetCounter = SetCounter + 1 ; % go to the next element in W
        W{SetCounter} = idx0(tf) ;
    end
end
     
% W now contains the indices into the subsets
% Do not forget to remove the unused pre-allocated elements (>wk)
if nargout==2
    % retain the indices
    IX = W(1:SetCounter) ;
end

% get the subsets
W = cellfun(@(c) S(c), W(1:SetCounter), 'un', 0) ;