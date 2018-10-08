function spikeTimes = PoissonSpikeTrain(rate, dur)
% Generate Poisson Spike Train with firing rate and duration


dt = 0.0001;

spikeTimes=[];

% Generating spikes from a exponential distribution
for t=0:dt:dur
    if (rate*dt)>=rand
        spikeTimes(end+1,1)=t;
    end
end
