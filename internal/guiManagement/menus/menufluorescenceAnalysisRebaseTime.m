function experiment = menufluorescenceAnalysisRebaseTime(experiment)
  experiment = loadTraces(experiment, 'all');
  minT = experiment.rawT(1)-1/experiment.fps;
  answer = inputdlg({'New initial time (in seconds)'},...
                                  'Cut traces', [1 60], {num2str(minT)});
  if(isempty(answer))
    return;
  end
  minT = str2double(strtrim(answer{1}));
  
  experiment.rawT = ((1:size(experiment.rawTraces, 1))-1)/experiment.fps+minT+1/experiment.fps;
  
  if(isfield(experiment,'traces'))
    experiment.t = ((1:size(experiment.traces, 1))-1)/experiment.fps+minT+1/experiment.fps;
  end
  logMsg(sprintf('Rebase performed. New time range: (%.2f, %.2f) s', experiment.rawT(1), experiment.rawT(end)));
  logMsg('Only traces were rebased. Anything else involving absolute times you will need to process again');
  % The experiment is saved outside
end