function quant_X = movquant(X, p, n, dim, nanflag, padding)
%% MOVQUANT - calculate moving quantile
%   Input parameters:
%      X - N-dimensional array
%      p - Quantile to calculate. Must be between 0 and 1 (both included).
%      n - Width of the moving window
%      dim - dimension to operate across. Default: first non-singleton dimension of X.
%      nanflag - 'includenan' (default): if there is a NaN in the moving window, NaN is also
%                 returned for the quantile. 'omitnan': if there is a NaN in the moving window,
%                 it is omitted for the quantile calculation, and a NaN is only returned for
%                 the quantile if there are no data available at all.
%      padding - 'zeropad' (default): pad both ends of the signal with zero. 'truncate': pad
%                 both ends of the signal with NaN. The resulting output depends on the nanflag
%                 provided.
%
% Eike Petersen, December 2020.
%
    sX = size(X);
    
    if nargin < 4 || isempty(dim)
        % operate across first non-singleton dimension; same default as medfilt1.
        dim = find(sX > 1, 1);
    end
    if nargin < 5 || isempty(nanflag)
        nanflag = 'includenan';
    end
    
    if strcmp(nanflag, 'includenan')
        includenan = true;
    else
        includenan = false;
    end
    
    if nargin < 6 || isempty(padding)
        padding = 'zeropad';
    end
    
    N = sX(dim);
    sX_wo_dim = sX((1:ndims(X) ~= dim));
    win_left_len = floor(n/2);
    win_right_len = floor(n/2-0.5);
    quant_X = zeros(size(X));
    
    for ii = 1:prod(sX_wo_dim)
        X_ax_idces = cell(ndims(X), 1);
        X_ax_idces{dim} = 1:N;
        if dim == 1
          % Fixed on 2025 - Javier G. Orlandi
            [X_ax_idces{2:end}] = ind2sub([sX_wo_dim, 1], ii);
        elseif dim == ndims(X)
            [X_ax_idces{1:end-1}] = ind2sub(sX_wo_dim, ii);
        else
            [X_ax_idces{[1:dim-1, dim+1:ndims(X)]}] = ind2sub(sX_wo_dim, ii);
        end
        if strcmp(padding, 'zeropad')
            padconst = 0;
        elseif strcmp(padding, 'truncate')
            padconst = nan;
        end
        
        X_ax = X(X_ax_idces{:});
        X_ax_pad = [padconst * ones(win_left_len, 1); X_ax(:); padconst * ones(win_right_len, 1)];
        
        % Initial sorting
        [sorted_win, sorted_win_idces] = sort(X_ax_pad(1:n));
        quant_idces = X_ax_idces;
        quant_idces{dim} = 1;
        numnan = sum(isnan(sorted_win));
        
        % Calculate quantile value at first sample
        if includenan && isnan(sorted_win(end))
            quant_X(quant_idces{:}) = nan;
        else
            N_win = length(sorted_win) - numnan;
            if N_win == 0
                quant_X(quant_idces{:}) = nan;
            else
                if p < 0.5/N_win
                    quant_X(quant_idces{:}) = sorted_win(1);
                elseif p > (N_win-0.5)/N_win
                    quant_X(quant_idces{:}) = sorted_win(N_win);
                else
                    % simple linear interpolation between the two neighboring data
                    idx1 = floor(N_win*p+0.5);
                    x1 = (idx1-0.5)/N_win;
                    y1 = sorted_win(idx1);
                    x2 = (idx1+0.5)/N_win;
                    y2 = sorted_win(idx1+1);
                    quant_X(quant_idces{:}) = y1 + (y2-y1)*(p-x1)/(x2-x1);
                end
            end
        end            
        % Now we only need to remove one element from the sorted array at each step
        % and insert a new one at the correct position
        for jj = 2:N
            % 1. Remove the oldest element
            sorted_win_trimmed = sorted_win(sorted_win_idces > 1);
            sorted_win_idces_trimmed = sorted_win_idces(sorted_win_idces > 1);
            sorted_win_idces_trimmed = sorted_win_idces_trimmed - 1;
            if isnan(sorted_win(sorted_win_idces == 1))
                numnan = numnan - 1;
            end
            
            % 2. Insert the new entry at the right positions
            value_to_insert = X_ax_pad(jj+n-1);
            if isnan(value_to_insert)
                % always insert NaNs at the end
                sorted_win = [sorted_win_trimmed; value_to_insert];
                sorted_win_idces = [sorted_win_idces_trimmed; n];
                numnan = numnan + 1;
            else
                index_to_insert = find(sorted_win_trimmed > value_to_insert, 1);
                if isempty(index_to_insert)
                    % Found new maximum
                    if numnan > 0
                        sorted_win = [sorted_win_trimmed(1:n-1-numnan); value_to_insert; nan * ones(numnan, 1)];
                        sorted_win_idces = ...
                            [sorted_win_idces_trimmed(1:n-1-numnan); n; sorted_win_idces_trimmed(n-numnan:end)];
                    else
                        sorted_win = [sorted_win_trimmed; value_to_insert];
                        sorted_win_idces = [sorted_win_idces_trimmed; n];
                    end
                elseif index_to_insert == 1
                    sorted_win = [value_to_insert; sorted_win_trimmed];
                    sorted_win_idces = [n; sorted_win_idces_trimmed];
                else
                    sorted_win = ...
                        [sorted_win_trimmed(1:index_to_insert-1); value_to_insert; sorted_win_trimmed(index_to_insert:end)];
                    sorted_win_idces = ...
                        [sorted_win_idces_trimmed(1:index_to_insert-1); n; sorted_win_idces_trimmed(index_to_insert:end)];
                end
            end
            
            % 3. Calculate quantile value
            quant_idces{dim} = jj;
            if includenan && isnan(sorted_win(end))
                quant_X(quant_idces{:}) = nan;
            else
                N_win = length(sorted_win) - numnan;
                if N_win == 0
                    quant_X(quant_idces{:}) = nan;
                else
                    if p < 0.5/N_win
                        quant_X(quant_idces{:}) = sorted_win(1);
                    elseif p > (N_win-0.5)/N_win
                        quant_X(quant_idces{:}) = sorted_win(N_win);
                    else
                        % simple linear interpolation between the two neighboring data
                        idx1 = floor(N_win*p+0.5);
                        x1 = (idx1-0.5)/N_win;
                        y1 = sorted_win(idx1);
                        x2 = (idx1+0.5)/N_win;
                        y2 = sorted_win(idx1+1);
                        quant_X(quant_idces{:}) = y1 + (y2-y1)*(p-x1)/(x2-x1);
                    end
                end
            end            
        end
    end
end