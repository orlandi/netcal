function [ca_p, peel_p,data] = FindNextEvent(ca_p, exp_p, peel_p, data, starttim)
% exp_p - parameter of data set (either experimental or simulated)
% alg_p - algorithm parameters/settings
% starttim - time point for starting search (s)

peel_p.evtfound=0;
if (starttim < 0) || (starttim > exp_p.numpnts/exp_p.acqrate)
%     starttim
    return
end

wsiz = round(peel_p.slidwinsiz*exp_p.acqrate);
peel_p.padding = wsiz;
data = PaddingTraces(exp_p, peel_p, data);

checkwsiz = round(peel_p.intcheckwin*exp_p.acqrate);
ca_p.onsetposition = 1./exp_p.acqrate;
ca_p = IntegralofCaTransient(ca_p, peel_p, exp_p, data);

nstart = round(starttim*exp_p.acqrate+0.5)+wsiz;    % start as frame number

updateFit = peel_p.fitupdatetime; % update fit only from time to time
updateFitFrames = ceil(updateFit*exp_p.acqrate);
frameCounter = updateFitFrames+1;

for n = nstart:length(data.peel_pad)-wsiz
    if frameCounter > updateFitFrames
        frameCounter = 0;
        currentwin = data.peel_pad(n-wsiz:n-1);
        currenttim = data.tim_pad(n-wsiz:n-1);
        linefit = polyfit(currenttim,currentwin,1);
        tmpslope = linefit(1);
        if tmpslope > peel_p.maxbaseslope
            tmpslope = peel_p.maxbaseslope;
        elseif tmpslope < -peel_p.maxbaseslope
            tmpslope = -peel_p.maxbaseslope;
        end
    else
        frameCounter = frameCounter + 1;
    end
    
    currentoffset = tmpslope*data.tim_pad(n-1) + linefit(2);
    
    % Schmitt trigger Loop
    if (data.peel_pad(n)-currentoffset>peel_p.smtthigh)
        if n+peel_p.smttmindurFrames <= length(data.peel_pad)
            currentDff = data.peel_pad(n:n+peel_p.smttmindurFrames);
        else
            currentDff = data.peel_pad(n:end);
        end
        
        %         if any(currentDff<=peel_p.smttlow)
        if length(find(currentDff<=peel_p.smttlow)) > peel_p.smttlowMinEvents
            n = n + find(currentDff<=peel_p.smttlow,1,'last');
            if n > length(data.peel_pad)-wsiz
                break
            end
            frameCounter = frameCounter + find(currentDff<=peel_p.smttlow,1,'last');
            continue
        end
        data.slide_pad = data.peel_pad - currentoffset;
        data.temp_pad = tmpslope*data.tim_pad + linefit(2) - currentoffset;
        data.slide_pad = data.slide_pad - data.temp_pad;
        
        currentIntegral = trapz(data.tim_pad(n:n+checkwsiz),...
            data.slide_pad(n:n+checkwsiz));
        
        if (peel_p.spk_recmode == 'linDFF')
        elseif (peel_p.spk_recmode == 'satDFF')
            ca_p.onsetposition = (n-wsiz) ./ exp_p.acqrate;
            ca_p = IntegralofCaTransient(ca_p, peel_p, exp_p, data);
        end
        
        if currentIntegral>(ca_p.integral*peel_p.intacclevel)
            peel_p.evtfound=1;
            break
        end
        
        %         if (data.temp_pad(n+checkwsiz)-data.temp_pad(n))>(ca_p.integral*peel_p.intacclevel)
        %             peel_p.evtfound=1;
        %             break
        %         end
    end
end
if peel_p.evtfound
    peel_p.nextevtframe = n-wsiz-1;
    peel_p.nextevt = (n-wsiz-1) / exp_p.acqrate;
end

data.peel(1:end) = data.peel_pad(peel_p.padding+1:peel_p.padding+exp_p.numpnts);



