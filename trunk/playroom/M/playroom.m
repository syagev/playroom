%% --------- PlayRoom v0.4 --------------------------------------

%% Parameters & Constants 

% sFile = 'R2-bg-dog-occlusion.wmv';
sFile = 'KINECT';
sRec = 'none';
bProcess = true;
STOP_AFTER = Inf;

%vision params

% mCarpetPoints = [35 156;      
%                 119 116;      %flat carpet corners most left corner first (clockwise)
%                 238 143;
%                 195 217];


HUE_THRES = 0.05;           %hue threshold
SAT_THRES = 0.1;            %saturation threshold
U_THRES = 20;
V_THRES = 20;

TOUCH_THRES = 30;           %min distance from hot-spot to trigger
GRAB_THRES = 0.1;           %prct of pixels which were segmented between frames
GRAB_DIST_THRES = 100;       %maximum dist from hand to prop to consider a grab
PROP_BB_RATIO = 10;          %maximum ratio of width to height of a prop
MAX_ALLOWED_MOVEMENT = Inf;  %maximum movement of props between frames

%props definition
PROP_TO_DISPLAY = 1;

% HSV       Hue  Sat  Size  Color
% mProps = [0.1  0.7  169 0 0 1;];
%           0.09 0.23 10  1 0 0];

%YUV       U  V   Size  Color
% mProps = [106 142  169  1 0 1;
%           123 132  169  0 1 0;
%           106 153  169  1 1 0;
%           106 153  169  1 1 0;
%           106 153  169  0 0 1];

clear magicBlks;
magicBlks = MagicBlocks;


%% Framework Initialization 

HAND_LEFT = 8;
HAND_RIGHT = 12;

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
        hCam = videoinput('kinect',1);
        hCamDepth = videoinput('kinect',2);
        
        srcSettings = getselectedsource(hCamDepth);
        srcSettings.BodyPosture = 'Seated';
        srcSettings.TrackingMode = 'Skeleton';
                
        triggerconfig([hCamDepth hCam],'manual');
        
        set([hCamDepth hCam] ,'FramesPerTrigger', 1);
        set([hCamDepth hCam],'TriggerRepeat', Inf);
%         set([hCamDepth hCam],'FrameGrabInterval', 3);
    end
else
    bCam = false;
    if (~exist('hVFR','var'))
        hVFR = vision.VideoFileReader(sFile);
    else
        hVFR.reset;
    end
end

%initialize output if necessery
if (~strcmp(sRec,'none'))
    bSave = true;

    hVFW_clr = vision.VideoFileWriter('Filename', [sRec '_rgb.avi']);
    hVFW_clr.VideoCompressor = 'None (uncompressed)';
    hVFW_dep = vision.VideoFileWriter('Filename', [sRec '_dep.avi']);
    hVFW_dep.VideoCompressor = 'None (uncompressed)';
    hVFW_seg = vision.VideoFileWriter('Filename', [sRec '_seg.avi']);
    hVFW_seg.VideoCompressor = 'None (uncompressed)';
else
    bSave = false;
end

%initialize players
if (~exist('hPl','var'))
    hPl = vision.VideoPlayer;
    hPl2 = vision.VideoPlayer;
end

%load sounds
% if (~exist('hSound','var'))
%     %sound matrix - rows props, cols hot spots
%     [y, Fs]  = audioread('Wonderoom_loop.wav');
%     hSound(1,1) = audioplayer(y,Fs);
%         
%     [y, Fs]  = audioread('Drink.wav');
%     hSound(1,2) = audioplayer(y,Fs);
%     [y, Fs]  = audioread('Eat.wav');
%     hSound(1,3) = audioplayer(y,Fs);
%     [y, Fs]  = audioread('Bark.wav');
%     hSound(1,4) = audioplayer(y,Fs);    
% end

%get a frame so we know size
if (bCam)
    %kinect does not support snapshot unfortunately
    im = zeros(480,640,3);
else
    im = hVFR.step;
end

%%%%%%%%%
im = imresize(im,0.5);
%%%%%%%%%

%initialize shape inserters (for markers)
if (~exist('hBoxInsert','var'))
%     hBoxInsert = vision.ShapeInserter('BorderColorSource','Input port');
    hPointInsert = vision.MarkerInserter('BorderColor','custom', ...
        'BorderColorSource','Input port');
end

%initialize the main blob analysis
if (~exist('hBlob','var'))
    hBlob = vision.BlobAnalysis;
    hBlob.AreaOutputPort = true;
    hBlob.CentroidOutputPort = true;
    hBlob.OrientationOutputPort = false;
    hBlob.BoundingBoxOutputPort = true;
    hBlob.MinimumBlobAreaSource = 'Property';
    hBlob.LabelMatrixOutputPort = true;
end

%open a figure with the logo for keybaord input
fLogo = figure;
imshow(imread('logo.jpg'));
set(fLogo,'CurrentCharacter','k');

%start camera feed if necessery
if (bCam)
    start([hCam hCamDepth]);
end


%% Algorithm Initialization 

i = 0;          %frame no
cKey = 'l';     %input key

figure;         %for displaying FG mask
hold on;

mDisk = strel('disk',1);    %this is the smallest structure for erode/dilate

%the basic FG mask clear pixels left and right of extremals
mBaseFGMsk = ones(size(im,1),size(im,2));
mBaseFGMsk(:,1:min(mCarpetPoints(:,1))) = 0;
mBaseFGMsk(:,max(mCarpetPoints(:,1)):end) = 0;

%the prop structures array (flat X,Y, true Z) and blob matrices
props = struct('m', cell(1,size(mProps,1)));
for i=1:size(props,2)
    props(i).bGrabbed = false;
    props(i).mPos = int32([-1 -1 -1]);
    props(i).mBlob = zeros(size(im,1),size(im,2));
    props(i).iArea = mProps(i,3);
    props(i).iHue = mProps(i,1);
    props(i).iSat = mProps(i,2);
    props(i).mMarkerClr = mProps(i,4:6);
    props(i).iLastSeenArea = -1;
end

%calculate indices of pixels bounding the carpet. this is later used with
%the depth image to generate an imaginary walls filter
if (~exist('mImagWallMaxFilter','var'))
    hLineInsert = vision.ShapeInserter('Shape', 'Lines','BorderColor','white');
    clear mTopLineInd mBottomLineInd; 
    
    %insert two lines bounding the carpet from above
    mTmpMsk = zeros(size(im,1),size(im,2));
    mTmpMsk = hLineInsert.step(mTmpMsk, ...
        [mCarpetPoints(1,:) mCarpetPoints(2,:)]);
    mTmpMsk = hLineInsert.step(mTmpMsk, ...
        [mCarpetPoints(2,:) mCarpetPoints(3,:)]);
        
    [mTopLineInd(:,1),mTopLineInd(:,2)] = ind2sub(size(mTmpMsk), find(mTmpMsk));
    
    %insert two lines bounding the carpet from below
    mTmpMsk = zeros(size(im,1),size(im,2));
    mTmpMsk = hLineInsert.step(mTmpMsk, ...
        [mCarpetPoints(3,:) mCarpetPoints(4,:)]);
    mTmpMsk = hLineInsert.step(mTmpMsk, ...
        [mCarpetPoints(4,:) mCarpetPoints(1,:)]);
        
    [mBottomLineInd(:,1),mBottomLineInd(:,2)] = ind2sub(size(mTmpMsk), find(mTmpMsk));
    
    release(hLineInsert);
end

bPersonActive = false;

% set(hSound(1,1), 'StopFcn', {@loopSnd, hSound(1,1)});
% play(hSound(1,1));


%% PlayRoom Core 

%do the PlayRoom!
magicBlks.Start;

while (cKey ~= 'x' && i < STOP_AFTER)
    cKey = get(fLogo,'CurrentCharacter');
    
    %get next frame
    if (bCam)
        if (strcmp(hCam.Running,'on'))
            trigger([hCam hCamDepth]);
            [imOrig,  ~, metaDataClr] = getdata(hCam);
            [imDepth, ~, metaDataDep] = getdata(hCamDepth);
            
            %check player ind for skeleoton tracking, if none this will be empty
            iPlInd = find(metaDataDep.IsSkeletonTracked, 1, 'first');
            if (~isempty(iPlInd))
                if (~bPersonActive)
                    magicBlks.OnEnterPerson
                    bPersonActive = true;
                end
                
                imOrig(end-15:end,1:16,:) = zeros(16,16,3);
            end
            
            %resize coordinates (half the size, and depth normalized to cm)
            metaDataDep.JointImageIndices = metaDataDep.JointImageIndices * 0.5;
            metaDataDep.JointWorldCoordinates = metaDataDep.JointWorldCoordinates * 100;
            imDepth = imDepth / 10;
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
    
    %save the frame
    if (bSave)
        hVFW_clr.step(imOrig);
        hVFW_dep.step(imDepth);
        hVFW_seg.step(metaDataDep.SegmentationData);
    end
    
    %%%%%%%%%%
    imOrig = imresize(imOrig,0.5);
    imDepth = imresize(imDepth,0.5);
    %%%%%%%%%%
    
    if (bProcess)
        %make sure not over flow
        if (intmax - i) < 1
            i = 0;
        end
        i = i + 1;

    %     if (mod(i,3) > 0)
    %         continue;
    %     end

        % convert to hsv/yuv
        imHSV = double(rgb2hsv(imOrig));
%         imHSV = double(rgb2ycbcr(imOrig));

        %if imag walls filter not initialized
        if (~exist('mImagWallMaxFilter', 'var'))
            
            %build the imaginary wall filter by sampling depth along the
            %bounding lines and extruding to the top/bottom of the image
            mImagWallMaxFilter = ones(size(imDepth)) * Inf;
            mImagWallMinFilter = zeros(size(imDepth));
            
            for i = 1:size(mTopLineInd,1)
                mImagWallMaxFilter(1:mTopLineInd(i,1), mTopLineInd(i,2)) = ...
                    imDepth(mTopLineInd(i,1), mTopLineInd(i,2));
            end
            for i = 1:size(mBottomLineInd,1)
                mImagWallMinFilter(mBottomLineInd(i,1):end, mBottomLineInd(i,2)) = ...
                    imDepth(mBottomLineInd(i,1), mBottomLineInd(i,2));
            end
        end

        %fg - which is basically imaginary wall filter
        mFGMsk = mBaseFGMsk & (imDepth < mImagWallMaxFilter) & ...
            (imDepth > mImagWallMinFilter);
        imHSV(repmat(~mFGMsk | (imDepth == 0),[1 1 3])) = NaN;

        imshow(mFGMsk);

        %clear the players using sed-mask
        mSegMsk = imresize(metaDataDep.SegmentationData > 0, 0.5);
%         imHSV(mSegMsk) = NaN;

        %prop detection
        mNewlyGrabbed = zeros(size(props,2),1);
        for iProp=1:size(props,2)
                   
            %check grab condition
            if (~isempty(iPlInd) && ...
                (nnz(props(iProp).mBlob & mSegMsk) / ...
                 props(iProp).iLastSeenArea) > GRAB_THRES && ( ...
                norm([metaDataDep.JointImageIndices(HAND_LEFT,:,iPlInd) ...
                    metaDataDep.JointWorldCoordinates(HAND_LEFT,3,iPlInd)] - ...
                    double(props(iProp).mPos)) < GRAB_DIST_THRES || ...
                norm([metaDataDep.JointImageIndices(HAND_RIGHT,:,iPlInd) ...
                    metaDataDep.JointWorldCoordinates(HAND_RIGHT,3,iPlInd)] - ...
                    double(props(iProp).mPos)) < GRAB_DIST_THRES))
                
                if (~props(iProp).bGrabbed)
%                     play(hSound(1,4));
%                     mNewlyGrabbed(iProp) = 1;
                end
                
                %check which hand grabbed
%                 if (norm([metaDataDep.JointImageIndices(HAND_LEFT,:,iPlInd) ...
%                         metaDataDep.JointWorldCoordinates(HAND_LEFT,3,iPlInd)] - ...
%                         double(props(iProp).mPos)) < ...
%                     norm([metaDataDep.JointImageIndices(HAND_RIGHT,:,iPlInd) ...
%                         metaDataDep.JointWorldCoordinates(HAND_RIGHT,3,iPlInd)] - ...
%                         double(props(iProp).mPos)))
%                     
%                     disp('Grab Left');
%                     props(iProp).iGrabbedHand = HAND_LEFT;
%                 else
%                     disp('Grab Right');
%                     props(iProp).iGrabbedHand = HAND_RIGHT;
%                 end
            else
%                 beep;
                props(iProp).bGrabbed = false;
            end
            
            %detect prop from threshold
            if (iProp == 2)
                imProp = ...
                (abs(imHSV(:,:,1) - props(iProp).iHue) < HUE_THRES) & ...
                (abs(imHSV(:,:,2) - props(iProp).iSat) < SAT_THRES * 2) ;
            elseif (iProp == 5)
                imProp = ...
                (abs(imHSV(:,:,1) - props(iProp).iHue) < HUE_THRES) & ...
                (abs(imHSV(:,:,2) - props(iProp).iSat) < SAT_THRES * 2) ;
            else
            imProp = ...
                (abs(imHSV(:,:,1) - props(iProp).iHue) < HUE_THRES) & ...
                (abs(imHSV(:,:,2) - props(iProp).iSat) < SAT_THRES) ;
            end
%             imProp = ...
%                 (abs(imHSV(:,:,2) - props(iProp).iHue) < U_THRES) & ...
%                 (abs(imHSV(:,:,3) - props(iProp).iSat) < V_THRES) ;
             
            %erode and dilate
            imProp = imerode(imProp,mDisk);
            imProp = imdilate(imProp,mDisk);
            imProp = imdilate(imProp,mDisk);
            
            %find biggest blob
            hBlob.MinimumBlobArea = props(iProp).iArea;
            [mAreas,mPos,mBB,mPropLabels] = hBlob.step(imProp);
            
            if (~isempty(mPos))
                %sort blobs according to size and re-index all arrays
                [mAreas, idx] = sort(mAreas, 'descend');
                mPos = mPos(idx,:); mBB = mBB(idx,:);
                ind = 1;
                
                %find a blob which matches proportions constraints
                while ((mBB(ind,3) / mBB(ind,4) > PROP_BB_RATIO || ...
                    mBB(ind,3) / mBB(ind,4) < 1/PROP_BB_RATIO) && ind < size(mAreas,1))

                    ind = ind + 1;
                end
                
                %select it's data as the current blob
                iCurArea = mAreas(ind);
                mCurPropPos = int32(mPos(ind,:));
                mCurBlob = (mPropLabels == idx(ind));
                mCurBB = mBB(ind,:);
                
                %delete the blob's pixel from the image
                imHSV(mCurBlob) = NaN;
            else
                %this signals the rest of the code that no blob was found
                mCurPropPos = [];
            end
            
            
            %check un-grab condition (as large as last seen)
%             if (props(iProp).bGrabbed)
%                 if (isempty(iPlInd) || (~isempty(mCurPropPos) && ...
%                         iCurArea >= props(iProp).iLastSeenArea))
%                     %re-appearance
%                     props(iProp).bGrabbed = false;
%                     
%                     %this neutralizes the prev position test
%                     props(iProp).mPos(1) = -1;
%                     beep;
%                     disp('Reappearance');
%                 else
%                     %inherit hand position
%                     props(iProp).mPos = int32([metaDataDep.JointImageIndices( ...
%                         HAND_LEFT,:,iPlInd) ...
%                         metaDataDep.JointWorldCoordinates(HAND_RIGHT,3,iPlInd)]);
%                 end
%             end
            
            %save position
            %only if not grabbed, and succesful blob extraction, and does
            %not exceed acceptable movement from prev position
            if (~isempty(mCurPropPos))
                mCandidatePos = int32([mPos(ind,:) ...
                    imDepth(mCurPropPos(2), mCurPropPos(1))]);
            else
                mCandidatePos = [];
            end
                
            if (... ~props(iProp).bGrabbed && ...
                ~isempty(mCandidatePos) && ...
                (props(iProp).mPos(1) < 0 || ...
                norm(double(props(iProp).mPos - mCandidatePos)) < MAX_ALLOWED_MOVEMENT))
                
                props(iProp).mPos = mCandidatePos;

                %save prop's blob pixel data and area
                props(iProp).mBlob = mCurBlob;
                props(iProp).mBB = mCurBB;
                props(iProp).iLastSeenArea =  iCurArea; %props(iProp).iArea;
            end
        end
        
        %display low-level colored blob image and insert markers
        imAllProps = zeros(size(imOrig,1) * size(imOrig,2),3);
        for j = 1:size(mProps,1)
            if (props(j).mPos(1) >= 0)
                mPropClr = repmat(mProps(j,end-2:end),nnz(props(j).mBlob),1);
                imAllProps(find(props(j).mBlob == 1),:) = mPropClr;
                
                %draw circle marker
                imOrig = hPointInsert.step(imOrig, props(j).mPos(1:2), ...
                    uint8(255*props(j).mMarkerClr));
            end      
        end
        imAllProps = reshape(imAllProps,size(imOrig));
        hPl.step(imAllProps);
        
        %check interactions
        
%         if (props(1).mPos(1) >= 0 && props(2).mPos(1) >= 0)
%             if (norm(double(props(1).mPos - props(2).mPos)) < TOUCH_THRES)
%                 imOrig(end-50:end,1:51,:) = zeros(51,51,3);
%             end
%         end

        magicBlks.i = i;
        magicBlks.mNewlyGrabbed = mNewlyGrabbed;
        magicBlks.props = props;
        magicBlks.imDepth = imDepth;
        magicBlks.metaData = metaDataDep;
        
        iGrabbedProp = magicBlks.StoryFlow;
        if (~isempty(iGrabbedProp))
            props(iGrabbedProp).bGrabbed = true;
        end

    end
    
    %it's always nice to see
    hPl2.step(imOrig);
        
    %for keyboard input
    drawnow;
end


%% cleanup
if (bCam)
    stop([hCam hCamDepth]);
end

magicBlks.Stop;
% set(hSound(1,1), 'StopFcn', []);
% stop(hSound(1,1));

if (bSave)
    release(hVFW_clr);
    release(hVFW_dep);
    release(hVFW_seg);
    clear hVFW*;
end