function cmap=black(n,varargin)

p=inputParser;
p.addParamValue('gamma',1.8, @(x)x>0);
p.addParamValue('minColor','none');
p.addParamValue('maxColor','none');
p.addParamValue('invert',0, @(x)x==0 || x==1);

if nargin==1
    p.addRequired('n', @(x)x>0 && mod(x,1)==0);
    p.parse(n);
elseif nargin>1
    p.addRequired('n', @(x)x>0 && mod(x,1)==0);
    p.parse(n, varargin{:});
else
    p.addParamValue('n',256, @(x)x>0 && mod(x,1)==0);
    p.parse();
end
config = p.Results;
n=config.n;

%the ControlPoints and the spacing between them
%the ControlPoints in a very isoluminescence case
cP(:,1) = [90  190 245]./255; k(1)=1;  %cyan at index 1
cP(:,2) = [157 157 200]./255; k(2)=16; %purple at index 16
cP(:,3) = [220 150 130]./255; k(3)=32; %purple at index 32
cP(:,4) = [245 120 80 ]./255; k(4)=43; %redish at index 43
cP(:,5) = [180 180 0  ]./255; k(5)=64; %yellow at index 64

% Making them strictly isoluminescent
tempgraymap = mean((cP).^config.gamma,1);
tempgraymap = tempgraymap .^(1/config.gamma);
cP(1,:)=cP(1,:)./tempgraymap.*mean(tempgraymap);
cP(2,:)=cP(2,:)./tempgraymap.*mean(tempgraymap);
cP(3,:)=cP(3,:)./tempgraymap.*mean(tempgraymap);

for i=1:4  % interpolation between control points, while keeping the luminescence constant
    f{i} = linspace(0,1,(k(i+1)-k(i)+1))';  % linear space between these controlpoints
    ind{i} = linspace(k(i),k(i+1),(k(i+1)-k(i)+1))';
    
    cmap(ind{i},1) = ((1-f{i})*cP(1,i)^config.gamma + f{i}*cP(1,i+1)^config.gamma).^(1/config.gamma);
    cmap(ind{i},2) = ((1-f{i})*cP(2,i)^config.gamma + f{i}*cP(2,i+1)^config.gamma).^(1/config.gamma);
    cmap(ind{i},3) = ((1-f{i})*cP(3,i)^config.gamma + f{i}*cP(3,i+1)^config.gamma).^(1/config.gamma);
end


% normal linear interpolation to achieve the required number of points for the colormap
cmap = abs(interp1(linspace(0,1,size(cmap,1)),cmap,linspace(0,1,n)));

if config.invert
    cmap = flipud(cmap);
end

if ischar(config.minColor)
    if ~strcmp(config.minColor,'none')
        switch config.minColor
            case 'white'
                cmap(1,:) = [1 1 1];
            case 'black'
                cmap(1,:) = [0 0 0];
            case 'lightgray'
                cmap(1,:) = [0.8 0.8 0.8];
            case 'darkgray'
                cmap(1,:) = [0.2 0.2 0.2];
        end
    end
else
    cmap(1,:) = config.minColor;
end
if ischar(config.maxColor)
    if ~strcmp(config.maxColor,'none')
        switch config.maxColor
            case 'white'
                cmap(end,:) = [1 1 1];
            case 'black'
                cmap(end,:) = [0 0 0];
            case 'lightgray'
                cmap(end,:) = [0.8 0.8 0.8];
            case 'darkgray'
                cmap(end,:) = [0.2 0.2 0.2];
        end
    end
else
    cmap(end,:) = config.maxColor;
end
% HACK EVERYTHING
cmap = zeros(size(cmap));