function F = preprocess_traces(F)
T       = length(F);
f       = detrend(F);
nfft    = 2^nextpow2(T);
y       = fft(f,nfft);
bw      = 3;
y(1:bw) = 0; y(end-bw+1:end)=0;
iy      = ifft(y,nfft);
F       = z1(real(iy(1:T))); %*** whats z1?
end
