function obj = modOb(im,new,k)

% im is in YUV space

% paremters
% k = 3; % number of components in GMM

% get ellipse shape
ind = find(not(isnan(im(:,:,1))));
[x, y] = ind2sub([size(im,1), size(im,2)],ind);
obj.e = cov([x, y]);
obj.mu = mean([x,y],1);
obj.pdf = gmdistribution(obj.mu,obj.e);

if new
    % get GMM
    imVec = reshape(im,size(im,1) * size(im,2),size(im,3));
    clrpdf = imVec(ind,:);
    warning('off','stats:gmdistribution:FailedToConverge');
    obj.g = gmdistribution.fit(double(clrpdf),k,'Regularize',1e-5);

    % object is visible
    obj.vis = 1;
    
    % pixel set
    obj.pix = find(not(isnan(im(:,:,1))));

    % set fixed area
    obj.A = length(ind);
    obj.Ahat = obj.A;
    
    %object is not occluded
    obj.ocldrs = [];
end