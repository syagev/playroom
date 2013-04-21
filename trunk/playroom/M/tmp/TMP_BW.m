hCorners = vision.ShapeInserter('Shape','Circles');
hCorners.BorderColor = 'White';

% prop sample
pts = [flipud(mPropsD'); 3 * ones(1,size(mPropsD,1))];
imTMP = hCorners.step(imProps,pts);
figure; imshow(imTMP)

% prop
pts = [flipud(iPropD'); 3 * ones(1,size(iPropD,1))];
imTMP = hCorners.step(imPropTMP,pts);
figure; imshow(imTMP)

% matched points
pts = [flipud(iPropD(iCor,:)'); 3 * ones(1,sum(iCor))];
imTMP = hCorners.step(imPropTMP,pts);
figure; imshow(imTMP); title('matched points')


% visualize, for debugging
hCorners = vision.ShapeInserter('Shape','Circles');
hCorners.BorderColor = 'White';
figure;
% prop sample
pts = [flipud(mPropsD'); 3 * ones(1,size(mPropsD,1))];
imTMP = hCorners.step(imProps,pts);
subplot(3,1,1); imshow(imTMP); title('sampled template')

% prop
pts = [flipud(iPropD'); 3 * ones(1,size(iPropD,1))];
imTMP = hCorners.step(imPropTMP,pts);
subplot(3,1,2); imshow(imTMP); title('detected template')

% matched points
pts = [flipud(iPropD(iCor,:)'); 3 * ones(1,sum(iCor))];
imTMP = hCorners.step(imPropTMP,pts);
subplot(3,1,3); imshow(imTMP); title('matched points')

NN = ones(size(iPropD,1) + size(mPropsD,1),1);
[x, orderedInd] = Hebert_Leordeanu(iPropD, mPropsD, n, 50, 1,NN);
Y = mPropsD(orderedInd(:,2),:)';
X = iPropD(orderedInd(:,1),:)';
R = Y * X' * inv(X * X');