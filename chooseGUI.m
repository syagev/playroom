%PR parameters GUI selection

im = imOrig;

f = figure('Name', 'Carpet boudnary selection');
imshow(im);
display('Mark carpet boudnary');
mCarpetPoints = ginput(4); %x,y matrix
close(f);

f = figure('Name', 'Hot spot selection');
imshow(im);
display('Select 3 hot-spots (eat, drink, bark)');
mHotSpots = ginput(3);  %x,y matrix
close(f);

f = figure('Name', 'Prop sampling');
imshow(im);
display('Mark center of props for hue sample');
mPropsLoc = int32(ginput(size(mProps,1))); %x,y matrix
close(f);

%extract hue & sat values
imHSV = rgb2hsv(im);
mProps(:,1:2) = [diag(imHSV(mPropsLoc(:,2),mPropsLoc(:,1),1)) ...
    diag(imHSV(mPropsLoc(:,2),mPropsLoc(:,1),2))];
% extract UV values
% imHSV = rgb2ycbcr(im);
% mProps(:,1:2) = [diag(imHSV(mPropsLoc(:,2),mPropsLoc(:,1),2)) ...
%     diag(imHSV(mPropsLoc(:,2),mPropsLoc(:,1),3))];