function smoothedSignal = applySmoothing(time, signal, smoothing, window)
%Smooths the signal using different methods.
%  Details
%
if(nargin < 4)
  window = 0;
end

switch smoothing
  case 'moving average'
    if(window == 0)
      window = 5;
    end
      smoothedSignal = smooth(signal, window,'moving');
  case 'median filter'
    if(window == 0)
      window = 5;
    end
    smoothedSignal = medfilt1(signal, window, 'truncate');
  case 'Savitzky-Golay'
    if(window == 0)
      window = 12;
    end
    smoothedSignal = smooth(signal, window,'sgolay', 3);
  case 'backwards moving average'
    if(window == 0)
      window = 5;
    end
    b = (1/window)*ones(1,window);
    a = 1;
    smoothedSignal = filter(b, a, signal);
    for i = window-1:-1:1
      b = (1/i)*ones(1,i);
      filteredSignal = filter(b, a, signal);
      smoothedSignal(i) = filteredSignal(i);
    end
  case 'local regression'
    if(window == 0)
      window = 5;
    end
    smoothedSignal = smooth(signal,window, 'rlowess'); 
  case 'peak enhancement'
    smoothedSignal = mslowess(time,signal);
  otherwise
    smoothedSignal = signal;
end