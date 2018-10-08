function networkToGEXF(network, filename, varargin)
% NETWORKTOGEXF converts a MATLAB network structure into a GEXF file so it
% can be read with GEPHI
%
% USAGE:
%    networkToGEXF(network, fileName, varargin)
%
% INPUT arguments:
%
%    network - Network structure with the following elements:
%      network.RS - Sparse matrix of size NxN, being N the number of nodes.
%      Element RS(i,j) indicates the weight of the connection from i to j
%      (1 if unweighted).
%      network.X - Vector of length N with the X position of the nodes.
%      network.Y - Vector of length N with the Y position of the nodes.
%
%    fileName - GEXF output file.
%
% INPUT optional arguments ('key' followed by its value): 
%    'score', scoreList  - Always come in pairs. First entry corresponds to
%    the name of a node property. Second entry is the actual property list
%    (vector the same length as the number of nodes)
%
% OUTPUT arguments:
%    none
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

if(~isempty(varargin))
  scoreNames = cell(length(varargin)/2, 1);
  scoreVals = cell(length(varargin)/2, 1);
  for it = 1:(length(varargin)/2)
    scoreNames{it} = varargin{(it-1)*2+1};
    scoreVals{it} = varargin{it*2};
  end
else
  scoreNames = {};
  scoreVals = {};
end

sortEdges = true;

RS = network.RS;
X = network.X;
Y = network.Y;

% Decompose the matrix to create a new connectivity file for C code
[i,j, ~] = find(RS);
newConFile = [i-1, j-1];
newConFile = sortrows(newConFile,1);


fid = fopen(filename, 'w');
fprintf(fid, '<?xml version="1.0" encoding="UTF-8"?>\n');
fprintf(fid, '<gexf xmlns="http://www.gexf.net/1.2draft" xmlns:viz="http://www.gexf.net/1.1draft/viz" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.gexf.net/1.2draft http://www.gexf.net/1.2draft/gexf.xsd" version="1.2">\n');
fprintf(fid, '<graph mode="static" defaultedgetype="directed">\n');
if(~isempty(scoreNames))
  fprintf(fid, '<attributes class="node">\n');
  for it = 1:length(scoreNames)
    fprintf(fid, '  <attribute id="%d" title="%s" type="float"/>\n', it-1, scoreNames{it});
  end
  fprintf(fid, '</attributes>\n');
end

fprintf(fid, '<nodes>\n');
for i=1:length(RS)
    fprintf(fid, '<node id="%d" label="%d">\n', [i-1 i-1]);
    fprintf(fid, '  <viz:position x="%.5f" y="%.5f" z="0.0"/>\n', [X(i) Y(i)]);
    if(~isempty(scoreNames))
        fprintf(fid, '  <attvalues>\n');
        for it = 1:length(scoreNames)
          if(isnan(scoreVals{it}(i)))
            fprintf(fid, '    <attvalue for="%d" value=""/>\n', it-1);
          else
            fprintf(fid, '    <attvalue for="%d" value="%.5f"/>\n', it-1, scoreVals{it}(i));
          end
        end
        fprintf(fid, '  </attvalues>\n');    
    end
    fprintf(fid, '</node>\n');
end
fprintf(fid, '</nodes>\n');

fprintf(fid, '<edges>\n');

% Assign the weights to the 3rd column
newConFile = [newConFile(:,1), newConFile(:,2), zeros(size(newConFile(:,1)))];
for i=1:length(newConFile)
    newConFile(i,3) = full(RS(newConFile(i, 1)+1, newConFile(i, 2)+1));
end

% Sort the edges by weight
if(sortEdges)
  newConFile = sortrows(newConFile,-3);
end

for i=1:length(newConFile)
  fprintf(fid, '<edge id="%d" source="%d" target="%d"  weight="%d"/>\n', [i-1 newConFile(i, :)]);
end

fprintf(fid, '</edges>\n');

fprintf(fid, '</graph>\n');
fprintf(fid, '</gexf>\n');
fclose(fid);

