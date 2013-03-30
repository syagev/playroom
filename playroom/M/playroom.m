%% --------- PlayRoom v0.1 --------------------------------------
% 1 Dog prop, 3 hot-spots with sound feedback
%
% Real-Time and recorded video support.
%
% Manual carpet selection, Foreground detection with approximate 
% median, hue based segmentation, blob analysis and location 
% recognition with repeat-flags.

%% Parameters & Constants 

sFile = 'CAM';
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
        hVFR = vision.VideoFileReader('R1-bg-grab-move-1prop.wmv');
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
    close(f);
    
    %extract hue & sat values
    imHSV = rgb2hsv(im);
    nProps = size(mPropsLoc,1);
    mProps = [diag(imHSV(mPropsLoc(:,2),mPropsLoc(:,1),1)) ...
              diag(imHSV(mPropsLoc(:,2),mPropsLoc(:,1),2))];
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
        imOrig = hBoxInsert.step(imOrig, mBB(:,ind), BB_COLOR(iProp,:));
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