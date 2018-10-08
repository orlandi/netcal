function [mx, my, coarseMeasure] = neuronAverageDensityMap(network, measure, varargin)

params.mode = 'center';
params.coarseRadius = 0.3;
params.averageType = 'perNeuron';
params.measureType = 'full';
params.bins = 64;
params.periodic = false;

params.totalSizeX = network.totalSizeX;
params.totalSizeY = network.totalSizeY;

params.circularNetwork = false;
params.circularRadius = params.totalSizeX/2;

params.mirrorSizeX = params.totalSizeX/2;
params.mirrorSizeY = params.totalSizeY/2;
params.realIdx = 1:length(network.X);
params.returnSizeX = network.totalSizeX;
params.returnSizeY = network.totalSizeY;
params.xbins = linspace(-params.returnSizeX/2, params.returnSizeX/2, params.bins);
params.ybins = linspace(-params.returnSizeY/2, params.returnSizeY/2, params.bins);
params = parse_pv_pairs(params,varargin); 

RS = network.RS;
X = network.X;
Y = network.Y;
totalSizeX = params.totalSizeX;
totalSizeY = params.totalSizeY;

if(params.periodic)
    [X, Y, params.realIdx] = periodicSet(X, Y, totalSizeX, totalSizeY, params.mirrorSizeX, params.mirrorSizeY);
end

xbins = params.xbins;
ybins = params.ybins;

% Define the points over which we will average
if(strcmp(params.mode, 'center'))
    diffbins = diff(xbins);
    cxbins = params.xbins(1:end-1);
    cxbins = cxbins+diffbins/2;
    diffbins = diff(ybins);
    cybins = params.ybins(1:end-1);
    cybins = cybins+diffbins/2;
    [mx, my] = meshgrid(cxbins, cybins);
else
    [mx, my] = meshgrid(xbins, ybins);
end

coarseMeasure = zeros(size(my,1),size(mx,2));

for i=1:size(my,1)
    for j=1:size(mx,2)
        
        %%%%% Obtain the neurons inside the coarse area
        DL = (X(:)-mx(i,j)).^2+(Y(:)-my(i,j)).^2;
        neighbours = unique(params.realIdx(DL <= params.coarseRadius^2));
        
        %%%%% Sum all the contributions
        if(strcmp(params.measureType, 'full')) % Total of Measure
            coarseMeasure(i,j) = nansum(measure(neighbours)); 
        elseif(strcmp(params.measureType, 'internalK')) % Internal K
            subRS = RS(neighbours, neighbours); % The submatrix
            coarseMeasure(i,j) = nansum(subRS(:));
        end
        
        %%%%% Do the average
        if(strcmp(params.averageType,'perNeuron'))
          if(~isempty(neighbours))
            coarseMeasure(i,j) = coarseMeasure(i,j)/(length(neighbours)-sum(isnan(measure(neighbours))));
          else
            coarseMeasure(i,j) = 0;
          end
        elseif(strcmp(params.averageType,'perArea'))
            if(~params.periodic)
                if(params.circularNetwork)
                    R = params.circularRadius;
                    r = params.coarseRadius;
                    d = sqrt(mx(i,j)^2+my(i,j)^2);
                    if(d+r > R)
                        A = r^2*acos((d^2+r^2-R^2)/(2*d*r))+R^2*acos((d^2+R^2-r^2)/(2*d*R))-0.5*sqrt((R+r-d)*(d+r-R)*(d-r+R)*(d+r+R));
                    else
                        A = pi*r^2;
                    end
                    coarseMeasure(i,j) = coarseMeasure(i,j)/A;
                else
                    A = intersectRectangleCircle([xbins(1), xbins(end)], [ybins(1), ybins(end)], [mx(i,j), my(i,j)], params.coarseRadius);
                    coarseMeasure(i,j) = coarseMeasure(i,j)/A;
                end
            else
                coarseMeasure(i,j) = coarseMeasure(i,j)/pi/params.coarseRadius^2;
            end
        elseif(strcmp(params.averageType,'none'))
            coarseMeasure(i,j) = coarseMeasure(i,j);
        end
    end
end
