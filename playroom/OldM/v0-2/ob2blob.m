function j = ob2blob(blobs,object,im)

imVec = reshape(im,size(im,1) * size(im,2),size(im,3));

% associate object with blob
numBlobs = setdiff(unique(blobs(:)),0);
pr = zeros(1,length(numBlobs));
for i = 1 : length(numBlobs)
    ind = find(blobs == numBlobs(i));   %find the j'th blob's pixels
    [r, c] = ind2sub(size(blobs),ind);
    jointPix = mahal(object.pdf,[r, c]);
    %find pixel's probability to be a part 
    %of the object's color model (Eq 3)
%     iPr = posterior(object.g,imVec(jointPix < 1,2:3)) * object.g.PComponents';
    iPr = pdf(object.g,imVec(jointPix < 1,:));
    pr(i) = sum(iPr);
end

j = find(pr == max(pr),1,'first');

% handle case 2 of 3.1.2, object not associated to blob
if pr(j) == 0
    j = [];
end
    


