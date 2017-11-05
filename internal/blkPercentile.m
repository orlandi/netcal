function vals = blkPercentile(p, experiment, frameList, fID)

rArray = zeros(experiment.height, experiment.width, N, dataType);
idx = 0;
ncbar('Computing percentiles with reservoir sampling');
for it1 = 1:N
  cFrame = getFrame(experiment, chosenFrames(it1), fID);
  rArray(:, :, it1) = getFrame(experiment, chosenFrames(it1), fID);

  ncbar.update(it1/N);
end
closeVideoStream(fID);
ncbar.close();
% Now the percentiles
pList = prctile(rArray, p, 3);
toc