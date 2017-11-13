Readme for modelCalcium.m by
Henry Luetcke & Fritjof Helmchen
Brain Research Institut
University of Zurich
Switzerland

For details on the simulations please also see the corresponding manuscript:
Luetcke, Gerhard, Zenke, Gerstner & Helmchen (in revision), Frontiers in Neural Circuits

Note: Add the folder 'etc' recursively to your Matlab path to run this function.

Usage: S = modelCalcium(S,doPlot)
    S ... configuration structure
    doPlot ... generate plots?
Run the function without any input arguments first, to get the configuration structure S:
S = modelCalcium

Parameters in S can then be changed (see ParseInputs sub-function doc for explanation of the parameters)
An example input structure is also provided in the file S.mat
