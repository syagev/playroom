if (~exist('hVFR','var'))
    hVFR = vision.VideoFileReader('R1-bg-grab-move-1prop.wmv');
    hPl = vision.VideoPlayer;
    hPl2 = vision.VideoPlayer;
end

%% Carpet detection

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
% CARPET_ANGLE = 0.04;
% if (abs(mAngle(ind)) > CARPET_ANGLE)
%     [y,x] = find(mBBCarpet
% end
%     
% % mBox = int32(double(mBox) * [cos(vAngle(ind)) -sin(vAngle(ind));
% %                sin(vAngle(ind)) cos(vAngle(ind))]);
% 
% patch(mBox(:,1),mBox(:,2),1,'EdgeColor','r','FaceColor','none');

%% Learn background

hVFR.reset;
hFG = vision.ForegroundDetector;

while (~hVFR.isDone)
    im = hVFR.step;
    hPl2.step(im);
    
    im = hFG.step(rgb2gray(im));
    
    hPl.step(im);
    
end