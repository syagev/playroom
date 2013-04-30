%% --------- PlayRoom v0.1 --------------------------------------
% 1 Dog prop, 3 hot-spots with sound feedback
%
% Real-Time and recorded video support.
%
% Manual carpet selection, Foreground detection with approximate 
% median, hue based segmentation, blob analysis and location 
% recognition with repeat-flags.

%% Parameters & Constants 

sFile = 'R1-nobg-grab-move-1prop.wmv';
MAX_PROPS = 1;
BB_COLOR = uint8([255 255 255; 0 255 0; 0 0 255]);   %colors for BBs
SOUND_DELAY = 15;           %number of frames afterwhich to turn off snd

%vision params
MIN_BLOB_AREA = 169;        %min size of blob to be considered prop

BG_THRES = 0.05;            %min difference from BG image to be FG
BG_ACCUM = 0.001;           %BG accum rate

HUE_THRES = 0.02;           %hue threshold
SAT_THRES = 0.30;           %saturation threshold

HOTSPOT_THRES = 30;         %min distance from hot-spot to trigger


%%%%%%%%%%
NUM_CRN = 100;              %num corners for orientation detection
%%%%%%%%%%


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
    im = getsnapshot(hCam);
else
    im = hVFR.step;
end

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
if (~exist('mProps','var'))
    f = figure('Name', 'Prop sampling');
    imshow(im);
    display('Mark center of props for hue sample');
    mPropsLoc = int32(ginput(MAX_PROPS)); %x,y matrix
    
    %%%%%%%%%%
    display('Mark prop bounding box')
    mPropsBB = ginput(4); %x,y matrix
    %%%%%%%%%%
    
    close(f);
    
    %extract hue & sat values
    imHSV = rgb2hsv(im);
    nProps = size(mPropsLoc,1);
    mProps = [diag(imHSV(mPropsLoc(:,2),mPropsLoc(:,1),1)) ...
              diag(imHSV(mPropsLoc(:,2),mPropsLoc(:,1),2))];
          
    %%%%%%%%%%
    % get features for front & back
    % crop prop and get corner descriptors
    imProps = im(min(mPropsBB(:,2)) : max(mPropsBB(:,2)),...
        min(mPropsBB(:,1)) : max(mPropsBB(:,1)));
    mPropsD = corner(imProps,'MinimumEigenvalue',NUM_CRN);
    mPropsD(mPropsD(1,:) == -1) = []; %remove redundant corners
    mPropsCr = mean(mPropsD,1);
    % sample & determine orientation
    hCorners = vision.ShapeInserter('Shape','Circles');
    hCorners.BorderColor = 'White';
    imTMP = hCorners.step(imProps,[flipud(mPropsCr'); 3]);
    f = figure('Name', 'Prop sampling');
    imshow(imTMP);
    display('Mark front of props relative to center for orientation tuning');
    mPropsFr = int32(ginput(MAX_PROPS));
    close(f);
    mPropsOr = atan(-1 * double(mPropsFr(2) - mPropsCr(2)) /...
        double(mPropsFr(1) - mPropsCr(1)));
    if mPropsCr(1) > mPropsFr(1)
        mPropsOr = mPropsOr + pi; % directional compensation
    end
    mPropsR = [cos(mPropsOr), -sin(mPropsOr); sin(mPropsOr), cos(mPropsOr)];
    % square
    mPropsSq = [120, 120];
    %%%%%%%%%%
end

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

% hVFR.reset;
% hFG = vision.ForegroundDetector('NumGaussians',3, 'AdaptLearningRate',true);

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

%% PlayRoom Core 

if (~exist('hBoxInsert','var'))
    hBoxInsert = vision.ShapeInserter('BorderColorSource','Input port');
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
if (~exist('hGTE','var'))
    hGTE = vision.GeometricTransformEstimator;
    hGTE.InlierOutputPort = 1;
    hGTE.Transform = 'Nonreflective similarity';
    hGTE.ExcludeOutliers = 0;
%     hGTE.InlierPercentageSource = 'Property';
%     hGTE.PixelDistanceThreshold = 10;
end
if (~exist('hPropOr','var'))
    hPropOr = vision.ShapeInserter;
    hPropOr.BorderColorSource = 'Input port';
    hPropOr.Shape = 'Lines';
end
if (~exist('hPropFr','var'))
    hPropFr = vision.ShapeInserter;
    hPropFr.BorderColorSource = 'Input port';
    hPropFr.Shape = 'Circles';
end
%%%%%%%%%%

%open a figure with the logo for keybaord input
fLogo = figure;
imshow(imread('logo.jpg'));
set(fLogo,'CurrentCharacter','k');

%start camera feed if necessery
if (bCam)
    start(hCam);
end

%set sound flags
iCurrentSound = [-1 -1];

%do the PlayRoom!
i = 0;
while (get(fLogo,'CurrentCharacter') ~= 'x')
    %get next frame
    if (bCam)
        if (strcmp(hCam.Running,'on'))
            imOrig = getdata(hCam,1);
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
    
    %make sure not over flow
    if (intmax - i) < 1
        i = 0;
    end
    i = i + 1;
    
    %convert to HSV
    imFrm = rgb2hsv(imOrig);
    
    %BG detection
    if (i == 1)
        %take first frame as background
        imBG = imFrm(:,:,3);
    else
        %adopt BG model
        imBG = imBG + (imFrm(:,:,3) > imBG) * BG_ACCUM;
        imBG = imBG - (imFrm(:,:,3) < imBG) * BG_ACCUM;
    end
    
    %BG subtraction and carpet mask
    imFG = mCarpetMsk & ...
        (abs(double(imFrm(:,:,3)) - double(imBG)) > BG_THRES);
    
    %prop detection
    for iProp=1:nProps
        %mask hue and FG filter
        imProp = imFG & ...
            (abs(imFrm(:,:,1) - mProps(iProp,1)) < HUE_THRES) & ...
            (abs(imFrm(:,:,2) - mProps(iProp,2)) < SAT_THRES) ;
        
        %find biggest blob
        [mAreas,mPos,mBB] = hBlob.step(imProp);
        [~,ind] = max(mAreas);
        
        
        %%%%%%%%%%
        %detect prop's orientation
        if any(mPos(ind) + 1)
            
            % crop prop
            if (i == 1097)
                i = 1097;
            end
            
            blobLoc = round(mPos(:,ind));
            imPropTMP = imFrm(blobLoc(1) - mPropsSq(1) : blobLoc(1) + mPropsSq(1),...
                blobLoc(2) - mPropsSq(2) : blobLoc(2) + mPropsSq(2),3);
            
            % get corners and find correspondence
            iPropD = corner(imPropTMP,'MinimumEigenvalue',NUM_CRN);
%             [tform, iCor] = step(hGTE, iPropD', mPropsD', uint8(NUM_CRN / 2));
%             tform = step(hGTE, iPropD', mPropsD', uint8(NUM_CRN / 2));
%             [x, orderedInd] = Hebert_Leordeanu(P, Q, n_or_scorelimit, threshold, sigd, ...
%     xcorr);
           
            % get absolute location & orientation in frame
            iPropD(iPropD(:,1) == -1,:) = []; % remove redundant corners
            cnLoc = flipud(mean(iPropD,1)'); % mean of detected corners
            cnLoc = blobLoc + cnLoc - [mPropsSq(1); mPropsSq(2)];
% % %             iPropOr = atan(-tform(2,1) / tform(1,1));
% % %             if tform(1,1) < 0
% % %                 iPropOr = iPropOr + pi; % directional compensation
% % %             end
% % %             iPropOr = iPropOr + mPropsOr;
            vec = tform(:,1:2) - eye(2);
            if norm(vec) > 0.1
                aaa = 1;
            end
            
            frLoc = cnLoc + 25 * (tform(:,1:2) * mPropsR) * [1; 0];
            
% % %             % visualize, for debugging
% % %             hCorners = vision.ShapeInserter('Shape','Circles');
% % %             hCorners.BorderColor = 'White';
% % %             figure;
% % %             % prop sample
% % %             pts = [flipud(mPropsD'); 3 * ones(1,size(mPropsD,1))];
% % %             imTMP = hCorners.step(imProps,pts);
% % %             subplot(3,1,1); imshow(imTMP); title('sampled template')
% % % 
% % %             % prop
% % %             pts = [flipud(iPropD'); 3 * ones(1,size(iPropD,1))];
% % %             imTMP = hCorners.step(imPropTMP,pts);
% % %             subplot(3,1,2); imshow(imTMP); title('detected template')
% % % 
% % %             % matched points
% % %             pts = [flipud(iPropD(iCor,:)'); 3 * ones(1,sum(iCor))];
% % %             imTMP = hCorners.step(imPropTMP,pts);
% % %             subplot(3,1,3); imshow(imTMP); title('matched points')

        end
        %%%%%%%%%%
        
        
        
        %check if close to a hot-spot
        bHitHotSpot = false;
        for iHotSpot=1:nHotSpots
            if (norm(mPos(:,ind) - mHotSpots(iHotSpot,:)') < HOTSPOT_THRES)
                %hot spot reahced, play the sound if not already so
                if (strcmp(hSound(iProp, iHotSpot).Running,'off'))
                    %stop the previous sound
                    if (iCurrentSound(1) > 0)
                        stop(hSound(iCurrentSound(1),iCurrentSound(2)));
                    end
                    
                    %play and set flahs
                    play(hSound(iProp,iHotSpot));
                    iCurrentSound = [iProp iHotSpot];
                    iPlayStartFrm = i;
                end
                
                bHitHotSpot = true;
                break;
            end
        end
        
        %if not on a hot spot for more then a delay make quiet
        if (iCurrentSound(1) ~= -1 && ~bHitHotSpot && ...
                (i < iPlayStartFrm || i - iPlayStartFrm > SOUND_DELAY))
            stop(hSound(iCurrentSound(1),iCurrentSound(2)));
            iCurrentSound(1) = -1;
        end            
        
        %draw bounding box
        imOrig = hBoxInsert.step(imOrig, mBB(:,ind), single(BB_COLOR(iProp,:)));
        
        %%%%%%%%%%
        % draw orientation
        if any(mPos(ind) + 1)
            imOrig = hPropOr.step(imOrig, [frLoc; cnLoc], single(BB_COLOR(iProp,:)));
            imOrig = hPropFr.step(imOrig, [frLoc; 7], single(BB_COLOR(iProp,:)));
        end
        %%%%%%%%%%
    end

    %it's always nice to see
    hPl2.step(imOrig);
    hPl.step(imProp);
    
    %for keyboard input
    drawnow;
end

%cleanup
if (bCam)
    stop(hCam);
end