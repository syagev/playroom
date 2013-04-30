function [objects, mObjVsBlobs, objCnt] = ...
    blob2reg(blob,objects,imBlob,mObjVsBlobs,IND,objCnt)

% identifying object support regions in 'blob'
% handle 4 cases discussed in section 3.1.2

% parameters
THRESH = 0.50;          % threshold for declaring object as invisible
Beta = 10;

if ~any(mObjVsBlobs(:,IND))
    
    % case 1, blob has no objects associated with it
%     id = find(cellfun('isempty',objects),1,'first');
    objCnt = objCnt + 1;
    if objCnt > 20
        objCnt = objCnt - 10;
    end
    if objCnt < 4
        k = 3;
    else
        k = 7;
    end
    objects{objCnt} = modOb(imBlob,1,k); % create object
    mObjVsBlobs(objCnt,IND) = 1;

    % case 2 is handled in ob2blob

elseif nnz(mObjVsBlobs(:,IND)) == 1
    % case 3, blob associated with a single object
    indtmp = mObjVsBlobs(:,IND) == 1;
    if indtmp < 4
        k = 3;
    else
        k = 7;
    end
    objects{indtmp} = modOb(imBlob,1,k); % update object model

else
    % case 4, blob associated with multiple objects
    imVec = reshape(imBlob,size(imBlob,1) * size(imBlob,2),size(imBlob,3));
    idxObj = find(mObjVsBlobs(:,IND));
    pix = zeros(size(blob,1),length(idxObj));
    [r, c] = ind2sub([size(imBlob,1),size(imBlob,2)],blob);
    
    % calculate Prob/Dist measure (eq. 7) for each pixel in the blob
    idxOcld = zeros(1,length(idxObj));
    for i = 1 : length(idxObj)   
        
        iObj = objects{idxObj(i)};
              
        % handle cases of occlusions
        if iObj.vis
            % appearance model is always measured the same
            iPr = 0.1 * pdf(iObj.g,imVec(blob,:));
%             iPr = posterior(iObj.g,imVec(blob.pix,2:3)) * iObj.g.PComponents';

            % distance is wrt object's spatial model
            iDist = mahal(iObj.pdf,[r,c]);
            pix(:,i) = iPr ./ iDist;
%             iDist =  1 / (2*pi*det(iObj.e)) * exp(-0.5 * iDist);
%             pix(:,i) = (iPr .* iDist)./ (iDist + Beta * iPr);
        else
            idxOcld(idxObj(i)) = 1;  
        end   
            
    end
    
    % loop over occluded objects, see if they reappear
    idxOcld = find(idxOcld);
    for i = 1 : length(idxOcld)
        
        iObj = objects{idxOcld(i)};
% %         if isempty(iObj)
% %             continue;   % object was removed earlier
% %         end
        iPr = 0.1 * pdf(iObj.g,imVec(blob,:));
%         iPr = posterior(iObj.g,imVec(blob.pix,2:3)) * iObj.g.PComponents';
        
        % loop over possible occluders
        pixTMP = zeros(size(blob,1),length(iObj.ocldrs));
        for j = 1 : length(iObj.ocldrs)
            
            if isempty(objects{iObj.ocldrs(j)})
                % occluder has disappeared
%                 objects{idxOcld(i)} = [];
%                 blob.objects = setdiff(blob.objects,idxOcld(i));
%                 idxObj(idxOcld(i)) = [];
%                 pix(:,idxOcld(i)) = [];
                continue;       % temporary test
            else
                % distance is wrt occluder's spatial model
                iDist = mahal(objects{iObj.ocldrs(j)}.pdf,[r,c]); 
                pixTMP(:,j) = iPr ./ iDist;
%                 iDist =  1 / (2*pi*det(objects{iObj.ocldrs(j)}.e)) * exp(-0.5 * iDist);
%                 pixTMP(:,j) = (iPr .* iDist)./ (iDist + Beta * iPr);
            end
            
        end
        
        [~, indPix] = max(pixTMP,[],2); % most probable region has most pix
        regCnt = histc(indPix,1 : length(iObj.ocldrs));
        indPix = find(regCnt == max(regCnt),1,'first');

        % update pixels of best region
        pix(:,idxObj == idxOcld(i)) = pixTMP(:,indPix);
        
    end
        
            
    [~, pix] = max(pix,[],2);
    
    % loop over objects again to update area and spatial model
    for i = 1 : length(idxObj)
        
        iObj = objects{idxObj(i)};
        iObj.pix = blob(pix == i);
        
        % check whether its visibiliy has changed status
        iObj.Ahat = length(iObj.pix);
        if (iObj.Ahat / iObj.A) < THRESH && (iObj.Ahat < 500)
            
            % update occluders
            iObj.ocldrs = unique([iObj.ocldrs,...
                    setdiff(find(mObjVsBlobs(:,IND)),idxObj(i))']);
                
            if (iObj.Ahat / iObj.A) < 0.2
                iObj.mu = mean([r, c], 1);
            end

            iObj.vis = 0;
        else
            
            % create mask of pixels associated with object
            iMask = nan * ones(size(imBlob,1) * size(imBlob,2),1);
            iMask(iObj.pix) = 1;
            imObj = bsxfun(@times,imBlob,reshape(iMask,size(imBlob,1),size(imBlob,2)));
            
% % %             if (iObj.Ahat / iObj.A) > 0.9
% % %                 % update spatial & color model (& AREA)
% % %                 iObj = modOb(imObj,1);
% % %             else
                % update spatial model (ellipse)
                objTmp = modOb(imObj,0);
                iObj.e = objTmp.e;
                iObj.mu = objTmp.mu + 0.5 * (objTmp.mu - iObj.mu);
                iObj.pdf = objTmp.pdf;
                iObj.vis = 1;
                iObj.ocldrs = []; % object not occluded
% % %             end
            
            % remove object's association to other blobs
            tmprow = zeros(1,size(mObjVsBlobs,2));
            tmprow(IND) = 1;
            mObjVsBlobs(idxObj(i),:) = tmprow;

        end 
        
        objects{idxObj(i)} = iObj;
        
    end         
end
