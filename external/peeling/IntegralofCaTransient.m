function ca_p = IntegralofCaTransient(ca_p, peel_p, exp_p, data)
% ca_p - parameter for calcium dynamics  
% intvl = window from onset for integral calculation (s)
% calculate integral for window:
% 
% Oct 2013: added saturatDFF mode
% last update: 25.20.2013 fh

if (peel_p.spk_recmode == 'linDFF')
    ca_p.integral = ca_p.amp1*(ca_p.tau1*(1-exp(-peel_p.intcheckwin/ca_p.tau1)) - ca_p.tau1/(1+ca_p.tau1/ca_p.onsettau)* ...
                (1-exp(-peel_p.intcheckwin*(1+ca_p.tau1/ca_p.onsettau)/ca_p.tau1)) );
    ca_p.integral = ca_p.integral + ...
                ca_p.amp2*(ca_p.tau2*(1-exp(-peel_p.intcheckwin/ca_p.tau2)) - ca_p.tau2/(1+ca_p.tau2/ca_p.onsettau)* ...
                (1-exp(-peel_p.intcheckwin*(1+ca_p.tau2/ca_p.onsettau)/ca_p.tau2)) );
    ca_p.integral = ca_p.integral * ca_p.scale;

    % negative integral for subtraction check
    ca_p.negintegral = ca_p.amp1*(ca_p.tau1*(1-exp(-peel_p.negintwin/ca_p.tau1)) - ca_p.tau1/(1+ca_p.tau1/ca_p.onsettau)* ...
                    (1-exp(-peel_p.negintwin*(1+ca_p.tau1/ca_p.onsettau)/ca_p.tau1)) );
    ca_p.negintegral = ca_p.negintegral + ...
                    ca_p.amp2*(ca_p.tau2*(1-exp(-peel_p.negintwin/ca_p.tau2)) - ca_p.tau2/(1+ca_p.tau2/ca_p.onsettau)* ...
                    (1-exp(-peel_p.negintwin*(1+ca_p.tau2/ca_p.onsettau)/ca_p.tau2)) );
    ca_p.negintegral = ca_p.negintegral * -1.0 * ca_p.scale;

elseif (peel_p.spk_recmode == 'satDFF')
    startIdx = min( round(ca_p.onsetposition.*exp_p.acqrate), (length(data.singleTransient)-1) );
    stopIdx = min( round( (ca_p.onsetposition+peel_p.intcheckwin).*exp_p.acqrate), length(data.singleTransient));
    
    currentTim = data.tim(startIdx:stopIdx);
    currentTransient = data.singleTransient(startIdx:stopIdx);
    ca_p.integral = trapz(currentTim,currentTransient);
    ca_p.integral = ca_p.integral * ca_p.scale;

    stopIdx = min(round( (ca_p.onsetposition+peel_p.negintwin).*exp_p.acqrate), length(data.singleTransient) );
    
    currentTim = data.tim(startIdx:stopIdx);
    currentTransient = data.singleTransient(startIdx:stopIdx);
    ca_p.negintegral = trapz(currentTim,currentTransient);
    ca_p.negintegral = ca_p.negintegral * -1.0 * ca_p.scale;
else
    error('Error in CaIntegral calculation. Illdefined mode.');
end
    