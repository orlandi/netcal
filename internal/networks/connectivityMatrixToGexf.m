function [ret] = connectivityMatrixToGexf(network, filename, varargin)

params.leadingScore = [];
params.clustering = false;
params.triangles = false;
params.offset = 0;
params.subnetwork = [];
params.weightsMatrix = [];

params = parse_pv_pairs(params,varargin); 

leadingScore = params.leadingScore;
triangles = params.triangles;
clustering = params.clustering;

if(triangles || clustering)
    [kinpG, koutG, CG, TG, TmaxG] = calculateGlobalClusteringFast(network);
end

RS = network.RS;
X = network.X;
Y = network.Y;

members = (1:length(RS))';
quad = zeros(size(members));
realPos = zeros(length(members), 2);
for j = 1:length(members)
    %[~, quad(j)] = findMinimumDistanceReverse(network, [network.X(j), network.Y(j)], network.center);
    realPos(j, :) = [network.X(j), network.Y(j)]/1000;
end
%realPos = moveToQuadrant(network, members, quad);
X = realPos(:,1);
Y = realPos(:,2);
    
% Decompose the matrix to create a new connectivity file for C code
[i,j, ~] = find(RS);
newConFile = [i-1, j-1];
newConFile = sortrows(newConFile,1);


fid = fopen(filename, 'w');
%fprintf(fid, '<gexf xmlns="http://www.gexf.net/1.1draft" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.gexf.net/1.1draft http://www.gexf.net/1.1draft/gexf.xsd" version="1.1">\n');
fprintf(fid, '<gexf xmlns:viz="http:///www.gexf.net/1.1draft/viz" version="1.1" xmlns="http://www.gexf.net/1.1draft">\n');
fprintf(fid, '<graph mode="static" defaultedgetype="directed">\n');
fprintf(fid, '<attributes class="node">\n');
fprintf(fid, '  <attribute id="0" title="leadingScore" type="float"/>\n');
fprintf(fid, '  <attribute id="1" title="clusterLoop" type="float"/>\n');
fprintf(fid, '  <attribute id="2" title="clusterAttractor" type="float"/>\n');
fprintf(fid, '  <attribute id="3" title="clusterRepeller" type="float"/>\n');
fprintf(fid, '  <attribute id="4" title="clusterConduit" type="float"/>\n');
fprintf(fid, '  <attribute id="5" title="clusterTotal" type="float"/>\n');
fprintf(fid, '  <attribute id="6" title="triangleLoop" type="float"/>\n');
fprintf(fid, '  <attribute id="7" title="triangleAttractor" type="float"/>\n');
fprintf(fid, '  <attribute id="8" title="triangleRepeller" type="float"/>\n');
fprintf(fid, '  <attribute id="9" title="triangleConduit" type="float"/>\n');
fprintf(fid, '  <attribute id="10" title="triangleTotal" type="float"/>\n');
fprintf(fid, '  <attribute id="11" title="subnetwork" type="float"/>\n');
fprintf(fid, '  <attribute id="12" title="ignitionTime" type="float"/>\n');
fprintf(fid, '</attributes>\n');


fprintf(fid, '<nodes>\n');
for i=1:length(RS);
    fprintf(fid, '<node id="%d" label="%d">\n', [i-1 i-1]+params.offset);
    fprintf(fid, '  <viz:position x="%.5f" y="%.5f" z="0.0"/>\n', [X(i) Y(i)]*1000);
    fprintf(fid, '  <attvalues>\n');
    if(~isempty(leadingScore))
        fprintf(fid, '    <attvalue for="0" value="%.5f"/>\n', leadingScore(i));
    end
    % T structure: LOOP - ATTRACTOR - REPELLER - CONDUIT - TOTAL
    if(clustering)
        fprintf(fid, '    <attvalue for="1" value="%.5f"/>\n', CG(i,1));
        fprintf(fid, '    <attvalue for="2" value="%.5f"/>\n', CG(i,2));
        fprintf(fid, '    <attvalue for="3" value="%.5f"/>\n', CG(i,3));
        fprintf(fid, '    <attvalue for="4" value="%.5f"/>\n', CG(i,4));
        fprintf(fid, '    <attvalue for="5" value="%.5f"/>\n', CG(i,5));
    end
    if(triangles)
        fprintf(fid, '    <attvalue for="6" value="%.5f"/>\n', TG(i,1));
        fprintf(fid, '    <attvalue for="7" value="%.5f"/>\n', TG(i,2));
        fprintf(fid, '    <attvalue for="8" value="%.5f"/>\n', TG(i,3));
        fprintf(fid, '    <attvalue for="9" value="%.5f"/>\n', TG(i,4));
        fprintf(fid, '    <attvalue for="10" value="%.5f"/>\n', TG(i,5));
    end
    if(~isempty(params.subnetwork))
        if(any(i==params.subnetwork.members))
            subnet = 1;
            itime = [];
            hit = params.subnetwork.members(find(i == params.subnetwork.members,1,'first'));
            hittime = find(hit == params.subnetwork.partConList(:,1), 1, 'first');
            if(isempty(hittime))
                hittime = find(hit == params.subnetwork.partConList(:,2), 1, 'first');
            end
            itime = params.subnetwork.partConList(hittime, 3);
        else
            subnet = 0;
            itime = [];
        end
        fprintf(fid, '    <attvalue for="11" value="%.5f"/>\n', subnet);
        fprintf(fid, '    <attvalue for="12" value="%.5f"/>\n', itime);
    end
    fprintf(fid, '  </attvalues>\n');
    fprintf(fid, '</node>\n');
end
fprintf(fid, '</nodes>\n');

fprintf(fid, '<edges>\n');
for i=1:length(newConFile);
    weight = 1;
    if(~isempty(params.subnetwork))
        if(any((newConFile(i,1)+1) == params.subnetwork.members) | any((newConFile(i,2)+1) == params.subnetwork.members))
            weight = 2;
        end
        if(params.subnetwork.fullRS(newConFile(i, 1)+1, newConFile(i, 2)+1) == 1)
            weight = 4;
        end
    end
    if(~isempty(params.weightsMatrix))
        weight = full(params.weightsMatrix(newConFile(i, 1)+1, newConFile(i, 2)+1));
    end
    fprintf(fid, '<edge id="%d" source="%d" target="%d"  weight="%d"/>\n', [i-1 newConFile(i, :)+params.offset weight]);
end
fprintf(fid, '</edges>\n');

fprintf(fid, '</graph>\n');
fprintf(fid, '</gexf>\n');
fclose(fid);

ret = 1;
