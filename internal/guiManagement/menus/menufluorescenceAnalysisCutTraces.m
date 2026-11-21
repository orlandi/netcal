function experiment = menufluorescenceAnalysisCutTraces(experiment)
  experiment = loadTraces(experiment, 'all');
  minT = experiment.rawT(1);
  maxT = experiment.rawT(end);
  answer = inputdlg({'Initial time','Final time'},...
                                  'Cut traces', [1 60], {num2str(minT), num2str(maxT)});
  if(isempty(answer))
    return;
  end
  minT = str2double(strtrim(answer{1}));
  maxT = str2double(strtrim(answer{2}));
  [~,validMinIdx] = min(abs(minT-experiment.rawT));
  [~,validMaxIdx] = min(abs(maxT-experiment.rawT));
  experiment.rawT = experiment.rawT(validMinIdx:validMaxIdx);
  experiment.rawTraces = experiment.rawTraces(validMinIdx:validMaxIdx, :);
  if(isfield(experiment,'traces'))
    experiment.t = experiment.t(validMinIdx:validMaxIdx);
    experiment.traces = experiment.traces(validMinIdx:validMaxIdx, :);
  end
  logMsg(sprintf('Cutting performed. New time range: (%.2f, %.2f) s', experiment.rawT(1), experiment.rawT(end)));
  logMsg('Only traces were cut. Anything else you will need to process again');
  experiment.saveBigFields = true;
  % The experiment is saved outside
end