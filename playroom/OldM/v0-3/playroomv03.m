%% --------- PlayRoom v0.1 --------------------------------------
% 1 Dog prop, 3 hot-spots with sound feedback
%
% Real-Time and recorded video support.
%
% Manual carpet selection, Foreground detection with approximate 
% median, hue based segmentation, blob analysis and location 
% recognition with repeat-flags.

%% Parameters & Constants 

% sFile = 'R2-bg-dog-occlusion.wmv';
sFile = 'KINECT';
MAX_PROPS = 3;
BB_COLOR = uint8([255 255 255; 0 255 0; 0 0 255]);   %colors for BBs
SOUND_DELAY = 15;           %number of frames afterwhich to turn off snd

%vision params
MIN_BLOB_AREA = 169;        %min size of blob to be considered prop

BG_THRES = 0.05;            %min difference from BG image to be FG
BG_ACCUM = 0.001;           %BG accum rate

HUE_THRES = 0.02;           %hue threshold
SAT_THRES = 0.30;           %saturation threshold

HOTSPOT_THRES = 30;         %min distance from hot-spot to trigger

% cmap = cmap(1:20,:);
% if (~exist('cmap','var'))
%     cmap = colormap('hsv');
%     k = 1 : 3 : 64;
%     k = k(randperm(length(k)));
%     cmap = cmap(k,:);
% end

cmap = [1 0 0; % red
    0 0.5 0; % green
    0 0 1; % blue
    1 1 0; % yellow
    0.95 0.04 0.85; % magenta
    0.44 0.96 0.9; % cyan
    0.98 0.4 0.0; %orange
    0.62 0 1; % purple
    1 1 1]; % white

%% Initialization 

setPath;
close all;

%initialize input - file or camera
if (strcmp(sFile,'CAM'))
    bCam = true;
    if (~exist('hCam','var'))
        hCam = videoinput('winvideo', 1);
        set(hCam,'FramesPerTrigger', 1);
        set(hCam,'TriggerRepeat', Inf);
        set(hCam,'FrameGrabInterval', 3);
    end
    stop(hCam);
elseif (strcmp(sFile,'KINECT'))
    bCam = true;
    if (~exist('hCam','var'))
        hCamDepth = videoinput('kinect',2,'Depth_640x480');
        hCam = videoinput('kinect',1,'RGB_640x480');
        triggerconfig([hCamDepth hCam],'manual');
        set([hCamDepth hCam] ,'FramesPerTrigger', 1000);
%         set([hCamDepth hCam],'TriggerRepeat', Inf);
        set([hCamDepth hCam],'FrameGrabInterval', 3);
    end
else
    bCam = false;
    if (~exist('hVFR','var'))
        hVFR = vision.VideoFileReader(sFile);
    else
        hVFR.reset;
    end
end

%initialize players
if (~exist('hPl','var'))
    hPl = vision.VideoPlayer;
    hPl2 = vision.VideoPlayer;
end

%load sounds
if (~exist('hSnd','var'))
    %sound matrix - rows props, cols hot spots
    [y, Fs]  = wavread('dog-eat');
    hSound(1,1) = audioplayer(y,Fs);
    [y, Fs]  = wavread('dog-drink');
    hSound(1,2) = audioplayer(y,Fs);
    [y, Fs]  = wavread('dog-bark');
    hSound(1,3) = audioplayer(y,Fs);
end

%get a frame so we know size
if (bCam)
%     im = getsnapshot(hCam);
    im = zeros(480,640,3);
else
    im = hVFR.step;
end

%%%%%%%%%
im = imresize(im,0.5);
%%%%%%%%%


%% Hot-spot selection 

if (~exist('mCarpetBox','var')) 
    f = figure('Name', 'Carpet boudnary selection');
    imshow(im);
    display('Mark carpet boudnary');
    mCarpetBox = ginput(4); %x,y matrix
    close(f);
end
if (~exist('mHotSpots','var'))
    f = figure('Name', 'Hot spot selection');
    imshow(im);
    display('Select 3 hot-spots (eat, drink, bark)');
    mHotSpots = ginput(3);  %x,y matrix
    %change to y,x matrix
    mHotSpots = mHotSpots(:,[2 1]);
    nHotSpots = size(mHotSpots,1);
    close(f);
end
% % % % % if (~exist('mProps','var'))
% % % % %     f = figure('Name', 'Prop sampling');
% % % % %     imshow(im);
% % % % %     display('Mark center of props for hue sample');
% % % % %     mPropsLoc = int32(ginput(MAX_PROPS)); %x,y matrix
% % % % %    
% % % % %     close(f);
% % % % %     
% % % % %     %extract hue & sat values
% % % % %     imHSV = rgb2hsv(im);
% % % % %     nProps = size(mPropsLoc,1);
% % % % %     mProps = [diag(imHSV(mPropsLoc(:,2),mPropsLoc(:,1),1)) ...
% % % % %               diag(imHSV(mPropsLoc(:,2),mPropsLoc(:,1),2))];
% % % % %           
% % % % % end

%% Carpet detection (currently manual) 

mCarpetMsk = poly2mask(mCarpetBox(:,1), mCarpetBox(:,2), ...
    size(im,1), size(im,2));

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

%% Learn background (unused)
% if (~exist('BG','var'))
%     imHSV = double(rgb2hsv(im));
%     imMasked = imHSV(:,:,1) .* mCarpetMsk;
%     imMasked = imMasked(:);
% 
%     vals = (imMasked(mCarpetMsk == 1));
%     BG.mean = mean(vals);
%     BG.std = sqrt(var(vals));
% end

% if (~exist('BS','var'))
%     % Create a subtractor
%     BS = cv.BackgroundSubtractorMOG2(500,16,'BShadowDetection',false);
% end

% hVFR.reset;
% % % hFG = vision.ForegroundDetector('NumGaussians',3, 'AdaptLearningRate',true);
% % % hFG.NumTrainingFrames = 270;
% % % hFG.MinimumBackgroundRatio = 0.8;
% % % 
% % % % i = 0;
% % % % while (~hVFR.isDone) && i < 270
% % % %     im = hVFR.step;
% % % %     
% % % %     %%%%%%%%%%
% % % %     im = imresize(im,0.5);
% % % %     imHSV = double(rgb2hsv(im));
% % % %     %%%%%%%%%%
% % % %     
% % % %     hPl2.step(im);
% % % %     
% % % %     imMasked = imHSV(:,:,1) .* mCarpetMsk;
% % % %     im = hFG.step(imMasked);
% % % %     
% % % %     hPl.step(im);
% % % %     
% % % %     i = i + 1;
% % % % end
% % % % 
% % % % hFG.LearningRate = eps;

% release(hPl);
% release(hPl2);

%% PlayRoom Core 

if (~exist('hBoxInsert','var'))
    hBoxInsert = vision.ShapeInserter('BorderColorSource','Input port');
    hPointInsert = vision.ShapeInserter('Shape', 'Circles',...
        'BorderColor','Custom','BorderColorSource','Input port');
end
if (~exist('hBlob','var'))
    hBlob = vision.BlobAnalysis;
    hBlob.AreaOutputPort = true;
    hBlob.CentroidOutputPort = true;
    hBlob.OrientationOutputPort = false;
    hBlob.BoundingBoxOutputPort = true;
    hBlob.MinimumBlobAreaSource = 'Property';
    hBlob.MinimumBlobArea = MIN_BLOB_AREA;
end

%%%%%%%%%%
if (~exist('hLabel','var'))
    hLabel = vision.ConnectedComponentLabeler('Connectivity',4);
    hLabel.LabelCountOutputPort = 0;
end
%%%%%%%%%%   
    


%open a figure with the logo for keybaord input
fLogo = figure;
imshow(imread('logo.jpg'));
set(fLogo,'CurrentCharacter','k');

%start camera feed if necessery
if (bCam)
    start(hCam);
    start(hCamDepth);
    trigger([hCam hCamDepth]);
end

%set sound flags
iCurrentSound = [-1 -1];

%do the PlayRoom!

%%%%%%%%%%%%
objects = cell(1,20);
blobs = cell(1,20);
mObjVsOcldrs = zeros(20);
objCnt = 0;
%%%%%%%%%%%%

i = 0;
cKey = 'l';

bLearning = true;
imBGAccum = zeros([size(im,1) size(im,2) 50]);
mBGStat = zeros([size(im,1) size(im,2) 2]);
iBGFrm = 1;

figure;
hold on;

while (cKey ~= 'x')
    cKey = get(fLogo,'CurrentCharacter');
    
    %get next frame
    if (bCam)
        if (strcmp(hCam.Running,'on'))
%             trigger([hCam hCamDepth]);
            imOrig = getdata(hCam,1);
            imDepth = getdata(hCamDepth,1);
        else
            break;
        end
    else
        if (~hVFR.isDone)
            imOrig = hVFR.step;
        else
            break;
        end
    end
    
    if (cKey == 'b' || iBGFrm > 50)
        bLearning = ~bLearning;
        iBGFrm = -1;
        mBGStat(:,30:end,1) = mean(imBGAccum(:,30:end,:),3);
        mBGStat(:,30:end,2) = std(imBGAccum(:,30:end,:),0,3);
        disp('Changed the learning mode');
        set(fLogo,'CurrentCharacter', 'c');
    end
    
    
% %     while i < 450
% %         imOrig = hVFR.step;
% %         i = i + 1;
% %     end
    
    %%%%%%%%%%
    imOrig = imresize(imOrig,0.5);
    imDepth = imresize(imDepth,0.5);
    %%%%%%%%%%

    %make sure not over flow
    if (intmax - i) < 1
        i = 0;
    end
    i = i + 1;

    
    if (~bLearning && mod(i,6) > 0)
        continue;
    end
        
    %%%%%%%%%%
    % convert to yuv & hsv
    imYUV = double(rgb2ycbcr(double(imOrig)));
    imHSV = double(rgb2hsv(imOrig));
    
    % hue key
% % % % %     imYUV(:,:,1) = 3 * (imYUV(:,:,1) - imHSV(:,:,3));
% % % % %     imYUV = cat(3,imYUV,imHSV(:,:,1),imHSV(:,:,2));
    imYUV(:,:,1) = [];
        
    % detect foreground 
% % %     fgMask = hFG.step(imHSV(:,:,1) .* mCarpetMsk);
%     fgMask = 0.3 * abs(imHSV(:,:,1) - BG.mean) / BG.std;
%     fgMask = fgMask .* mCarpetMsk;
%     fgMask = fgMask > 1;
        
    if (bLearning)
%         mskFG = logical(BS.apply(imHSV(:,:,1)*255, 'LearningRate', -1));
        imBGAccum(:,:,iBGFrm) = imDepth;
        iBGFrm = iBGFrm + 1;
        continue;
    else
%         mskFG = logical(BS.apply(imHSV(:,:,1)*255, 'LearningRate', 0.00000001));
%         mskFG = logical(cv.dilate(cv.erode(mskFG), 'Iterations',3));
%         mskFG = logical(cv.dilate(mskFG));
        mskFG = abs(double(imDepth) - mBGStat(:,:,1)) ./ mBGStat(:,:,2) > 10;
        mskFG(:,1:30) = 0;
    end

    mskFG = mskFG & mCarpetMsk;
    imshow(mskFG);
%     if (bLearning || mod(i,3))
%         continue;
%     end
    
    % blob analysis / connected components
    mBlobs = hLabel.step(mskFG);
    
    % BEGIN:  tracking with occlusions
    numBlobs = setdiff(unique(mBlobs),0);
    if any(numBlobs)
        indrem = zeros(1,length(numBlobs));
        for j = 1 : length(numBlobs)
            mskBlob = (mBlobs == j);
            if nnz(mskBlob) < 400
                mBlobs(mskBlob) = 0;
                indrem(j) = 1;
            end
        end
        numBlobs(indrem == 1) = [];
    end
    
    blobs = cell(1,20);
    mObjVsBlobs = zeros(20);
    
    % loop over objects and assign to blobs
    iOcld = zeros(1,length(objects)); % indices of occluded objects
    for j = 1 : length(objects)
        if not(isempty(objects{j}))
            
            % loop over visible objects first
            if objects{j}.vis || (j < 4)
                idxBlob = ob2blob(mBlobs,objects{j},imYUV);
                % assign to blob
                if isempty(idxBlob)
                    if (j < 4)
                        objects{j}.ocldrs = setdiff(find(~cellfun('isempty',objects)),j);
                        objects{j}.vis = 0;
                        mObjVsBlobs(j,1:length(numBlobs)) = 1;
                        iOcld(j) = 1;
                    else
                        objects{j} = [];
                    end
                    % need to remove from lists of occluders
                    % but this is done in blob2reg by checking if object is
                    % empty (line ~56)
                else
% % %                     if not(isfield(blobs{idxBlob},'objects'))
% % %                         blobs{idxBlob}.objects = j;
% % %                     else
% % %                         blobs{idxBlob}.objects = ...
% % %                             [blobs{idxBlob}.objects, j];
% % %                     end
                    
                    mObjVsBlobs(j,idxBlob) = 1;
                    
                end
            else
                
                iOcld(j) = 1;
            end
          
        end
    end
    
    % loop over occlueded objects
    % and assign them to blobs that contain a potential occluder
    idxBlobs = find(any(mObjVsBlobs,1));  %indexes of all non-empty blobs
    iOcld = find(iOcld);        %indexes of all occluded objects
    for j = 1 : length(iOcld);
        for k = 1 : length(idxBlobs)
            %intersection between occluders of object j and objects
            %associated with blob k
% % %         	idTMP = intersect(blobs{idxBlobs(k)}.objects,...
% % %                 objects{iOcld(j)}.ocldrs);
            
            idTMP = intersect(find(mObjVsBlobs(:,idxBlobs(k))),...
                objects{iOcld(j)}.ocldrs);

            if any(idTMP)
                mObjVsBlobs(iOcld(j),idxBlobs(k)) = 1;
            end
            
            %if there is an intersection add the j'th object to the k'th
            %blob (keeping the list unique)
% % %             if any(idTMP) && not(any(blobs{idxBlobs(k)}.objects == iOcld(j)))
% % %                 blobs{idxBlobs(k)}.objects = [blobs{idxBlobs(k)}.objects, iOcld(j)];
% % %             end
            
        end
    end
    
%     tmpObjectsUsed = zeros(100,1);
%     for j = 1 : length(blobs)
%         if (~isempty(blobs{j}))
%             tmpObjectsUsed(blobs{j}.objects) = ...
%                 tmpObjectsUsed(blobs{j}.objects) + 1;
%         end
%     end
%     if (max(tmpObjectsUsed) > 1)
%         tmpObjectsUsed = 'shit';
%     end
    
    % loop over blobs and assign regions
    for j = 1 : length(numBlobs)
      blobs{j} = find(mBlobs == numBlobs(j));
% % %       if not(isfield(blobs{j},'objects'))
% % %           blobs{j}.objects = [];
% % %       end
      mBlobsTMP = ones(size(mBlobs));
      mBlobsTMP(mBlobs ~= numBlobs(j)) = nan;
      imBlob = bsxfun(@times,imYUV,mBlobsTMP);
      [objects, mObjVsBlobs, objCnt] = ...
          blob2reg(blobs{j},objects,imBlob,mObjVsBlobs,j,objCnt); 
    end
    
    i = i;
    % display
    mBlobs = zeros(size(mBlobs,1) * size(mBlobs,2), 3);
    for j = 1 : length(objects)
        if not(isempty(objects{j}))
            mBlobs(objects{j}.pix,:) = repmat(cmap(j,:),length(objects{j}.pix),1);
            imOrig = hPointInsert.step(imOrig, int32([objects{j}.mu';5]),uint8(255*cmap(j,:)'));
            imOrig(end-14:end,(j-1)*15 + 1:j*15,:) = ...
                255 * cat(3,cmap(j,1) * ones(15),cmap(j,2) * ones(15),cmap(j,3) * ones(15));
        end
    end
    mBlobs = reshape(mBlobs,size(imOrig));
            
            
    % END: tracking with occlusions
    
    %%%%%%%%%%

% % % % %     %convert to HSV
% % % % %     imFrm = rgb2hsv(imOrig);
% % % % %     
% % % % %     %BG detection
% % % % %     if (i == 1)
% % % % %         %take first frame as background
% % % % %         imBG = imFrm(:,:,3);
% % % % %     else
% % % % %         %adopt BG model
% % % % %         imBG = imBG + (imFrm(:,:,3) > imBG) * BG_ACCUM;
% % % % %         imBG = imBG - (imFrm(:,:,3) < imBG) * BG_ACCUM;
% % % % %     end
% % % % %     
% % % % %     %BG subtraction and carpet mask
% % % % %     imFG = mCarpetMsk & ...
% % % % %         (abs(double(imFrm(:,:,3)) - double(imBG)) > BG_THRES);
% % % % %     
% % % % %     %prop detection
% % % % %     for iProp=1:nProps
% % % % %         %mask hue and FG filter
% % % % %         imProp = imFG & ...
% % % % %             (abs(imFrm(:,:,1) - mProps(iProp,1)) < HUE_THRES) & ...
% % % % %             (abs(imFrm(:,:,2) - mProps(iProp,2)) < SAT_THRES) ;
% % % % %         
% % % % %         %find biggest blob
% % % % %         [mAreas,mPos,mBB] = hBlob.step(imProp);
% % % % %         [~,ind] = max(mAreas);
% % % % %         
% % % % %         %check if close to a hot-spot
% % % % %         bHitHotSpot = false;
% % % % %         for iHotSpot=1:nHotSpots
% % % % %             if (norm(mPos(:,ind) - mHotSpots(iHotSpot,:)') < HOTSPOT_THRES)
% % % % %                 %hot spot reahced, play the sound if not already so
% % % % %                 if (strcmp(hSound(iProp, iHotSpot).Running,'off'))
% % % % %                     %stop the previous sound
% % % % %                     if (iCurrentSound(1) > 0)
% % % % %                         stop(hSound(iCurrentSound(1),iCurrentSound(2)));
% % % % %                     end
% % % % %                     
% % % % %                     %play and set flahs
% % % % %                     play(hSound(iProp,iHotSpot));
% % % % %                     iCurrentSound = [iProp iHotSpot];
% % % % %                     iPlayStartFrm = i;
% % % % %                 end
% % % % %                 
% % % % %                 bHitHotSpot = true;
% % % % %                 break;
% % % % %             end
% % % % %         end
% % % % %         
% % % % %         %if not on a hot spot for more then a delay make quiet
% % % % %         if (iCurrentSound(1) ~= -1 && ~bHitHotSpot && ...
% % % % %                 (i < iPlayStartFrm || i - iPlayStartFrm > SOUND_DELAY))
% % % % %             stop(hSound(iCurrentSound(1),iCurrentSound(2)));
% % % % %             iCurrentSound(1) = -1;
% % % % %         end            
% % % % %         
% % % % %         %draw bounding box
% % % % %         imOrig = hBoxInsert.step(imOrig, mBB(:,ind), single(BB_COLOR(iProp,:)));
% % % % %         
% % % % %     end

    %it's always nice to see
    hPl2.step(imOrig);
    mBlobs = uint8(255 * mBlobs / max(mBlobs(:)));
    hPl.step(mBlobs);
    
    %for keyboard input
    drawnow;
end

%cleanup
if (bCam)
    stop(hCam);
    stop(hCamDepth);
end