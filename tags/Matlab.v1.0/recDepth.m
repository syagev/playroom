hVFR = vision.VideoFileReader('itai_garden2_dep.avi');
if (~exist('hPl','var'))
    hPl = vision.VideoPlayer;
end
hVFW = vision.VideoFileWriter('../../Media/Pres/itai_garden2_dep_conv.avi');

while (~hVFR.isDone)
    im = double(hVFR.step) * 100;
%     im = im(:,:,1);
    
    
    
    hPl.step(im);
    hVFW.step(im);
end

release(hVFW);