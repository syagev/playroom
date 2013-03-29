if (~exist('hVFR','var'))
    hVFR = vision.VideoFileReader('R1-bg-grab-move-1prop.wmv');
    hPl = vision.VideoPlayer;
    hPl2 = vision.VideoPlayer;
else
     hVFR.reset;   
end

%% Carpet detection

mCarpetMsk = zeros(360,640);
hShpTmp = vision.ShapeInserter('Shape','Polygons','Fill',true, ...
    'FillColor','white','Opacity',1);
pts = [32;110;90;414;320;360;250;60];
mCarpetMsk = hShpTmp.step(mCarpetMsk, pts);

% %read first frame to detect carpet
% imCarpet = hVFR.step;
% %imshow(imCarpet);
% 
% %threshold norm against carpet color
% CARPET_COLOR = 0.6222;
% CARPET_THRES = 0.005;
% 
% imCarpet = rgb2hsv(imCarpet);
% imCarpet = (imCarpet(:,:,1) - CARPET_COLOR).^2 < CARPET_THRES;
% 
% %find biggest blob
% hBlob = vision.BlobAnalysis;
% hBlob.AreaOutputPort = true;
% hBlob.CentroidOutputPort = false;
% hBlob.OrientationOutputPort = true;
% 
% [mAreas,mBBCarpet,mAngle] = hBlob.step(imCarpet);
% [~,ind] = max(mAreas);
% 
% imshow(imCarpet);
% hold on;
% 
% %extract bounding box coordinates
% mBox = [mBBCarpet(2,ind)                    mBBCarpet(1,ind); 
%         mBBCarpet(2,ind)+mBBCarpet(4,ind)   mBBCarpet(1,ind); 
%         mBBCarpet(2,ind)+mBBCarpet(4,ind)   mBBCarpet(1,ind)+mBBCarpet(3,ind);
%         mBBCarpet(2,ind)                    mBBCarpet(1,ind)+mBBCarpet(3,ind)];
% 
% %if carpet at angle need to refine box
% % CARPET_ANGLE = 0.04;
% % if (abs(mAngle(ind)) > CARPET_ANGLE)
% %     [y,x] = find(mBBCarpet
% % end
%     
% % mBox = int32(double(mBox) * [cos(vAngle(ind)) -sin(vAngle(ind));
% %                sin(vAngle(ind)) cos(vAngle(ind))]);
% 
% patch(mBox(:,1),mBox(:,2),1,'EdgeColor','r','FaceColor','none');

%% Learn background

% hVFR.reset;
% hFG = vision.ForegroundDetector;
% 
% while (~hVFR.isDone)
%     im = hVFR.step;
%     hPl2.step(im);
%     
%     im = hFG.step(rgb2gray(im));
%     
%     hPl.step(im);
%     
% end

%% Detect dog
hShp = vision.ShapeInserter('BorderColor','white');
hBlob = vision.BlobAnalysis;
hBlob.AreaOutputPort = true;
hBlob.CentroidOutputPort = false;
hBlob.OrientationOutputPort = false;
hBlob.BoundingBoxOutputPort = true;
hBlob.MinimumBlobAreaSource = 'Property';
hBlob.MinimumBlobArea = 169;

hCornerDet = vision.CornerDetector('MaximumCornerCount',3);
mFeat = zeros(size(mDogFeat,1),9);

%threshold against dog color
DOG_COLOR = 0.1176;
DOG_THRES = 0.05;
DOG_SAT = 0.5;
DOG_SAT_THRES = 0.2;
DOG_SIZE = [84, 136];

i = 0;
while (~hVFR.isDone)
    i = i + 1;
    
    imOrig = hVFR.step;
    imFrm = rgb2hsv(imOrig);

    imDog = mCarpetMsk & ...
            (abs(imFrm(:,:,1) - DOG_COLOR) < DOG_THRES) & ...
            (abs(imFrm(:,:,2) - DOG_SAT) < DOG_SAT_THRES) ;

    if (i == 500)
        i = 1000;
    end
    
    %find biggest blob
    [mAreas,mBBDog] = hBlob.step(imDog);
    
%     [~,ind] = max(mAreas);
    
    [~,idx] = sort(mAreas, 'descend');
    mFeat = single(zeros(size(mDogFeat,1),9));

    for j=1:3
        ind = idx(j);
        if (mAreas(ind) < 0)
            break;
        end
        
         mBox = double([mBBDog(2,ind)            mBBDog(1,ind); 
            mBBDog(2,ind)+mBBDog(4,ind)   mBBDog(1,ind); 
            mBBDog(2,ind)+mBBDog(4,ind)   mBBDog(1,ind)+mBBDog(3,ind);
            mBBDog(2,ind)                 mBBDog(1,ind)+mBBDog(3,ind)]);
    
        [mCorners, ~] = hCornerDet.step(imOrig(:,:,3) & poly2mask( ...
            mBox(:,1),mBox(:,2),360,640 ));
        
        [mFeat(:,((j-1)*3+1):(j*3)), ~] = extractFeatures(...
            imOrig(:,:,3), mCorners);
    end
    
    [mMatch, mMatchMet] = matchFeatures(mFeat, mDogFeat);
    if (~isempty(mMatch))
        i = 100;
    end
    
%     [~,ind] = max(mTmp(1:5) ./ (mBBDog(3,idx(1:5)) .* mBBDog(4,idx(1:5))));
%     ind = idx(ind);
    
    imOrig = hShp.step(imOrig, mBBDog(:,ind));
    
    %extract bounding box coordinates
    % mBox = [mBBCarpet(2,ind)                    mBBCarpet(1,ind); 
    %         mBBCarpet(2,ind)+mBBCarpet(4,ind)   mBBCarpet(1,ind); 
    %         mBBCarpet(2,ind)+mBBCarpet(4,ind)   mBBCarpet(1,ind)+mBBCarpet(3,ind);
    %         mBBCarpet(2,ind)                    mBBCarpet(1,ind)+mBBCarpet(3,ind)];
    % 
    
    hPl2.step(imOrig);
    hPl.step(imDog);
end

% 182 169 / 229 210