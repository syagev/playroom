function [x, orderedInd] = Hebert_Leordeanu(P, Q, n_or_scorelimit, threshold, sigd, ...
    xcorr)
    
    %finds correspondence of two point clouds by the Hebert algorithm
    %P - np*2 vector with the source point cloud
    %Q - nq*2 vector with target point cloud
    %n_or_scorelimit - which type of threshold being used 't'|'n'
    %threshold - the algorithm's breakpoint, either a number specifying how
    %   many points to match or a maximal ratio between difference in distances
    %   to the image's diameter
    %sigd - algorithm's threshold for noise
    %xcorr - a binary row vector of size np*nq signifying which
    %   correspondences should be considered
    %
    %x - binary vector of size np*nq with the calculated assignment
    
    np = int64(size(P,1));
    nq = int64(size(Q,1));
    
    %get the possible correlation and break them down to proper indices
    abcorr = int64(find(xcorr>0));
    
    %construct the score matrix, we save only indexes & values so we can
    %later construct a sparse matrix
    m = length(abcorr);
    Mtemp = zeros(m^2,3);
    n = 0;
    
    %traverse relevant entries representing actual correspondences
    %matrix ordered as follows (total of (np*nq)*(np*nq) entries:
    %(1->1, 1->2, ..., 1->np, 2->1, 2->2, ..., 2->np, ... nq->1, ..., nq->np)
    for a = 1:m
        for b = a+1:m
            %get the i,j subscripts for the points of the correspondences a and b
            %[i,i_] = ind2sub([nq np], abcorr(a));
            %[j,j_] = ind2sub([nq np], abcorr(b));
            ij = idivide([abcorr(a) abcorr(b)]-1,nq)+1;
            i_j_ = mod([abcorr(a) abcorr(b)]-1,nq)+1;
            
            %calculate the difference in length between the vector of the
            %two points in Q and the 2 corr. points in P
            d = norm(Q(ij(1),:)-Q(ij(2),:)) - norm(P(i_j_(1),:)-P(i_j_(2),:));

            %the algorithm's answer to the universe
            if (abs(d) <= 3*sigd)
                n = n + 1;
                Mtemp(n,1) = double(abcorr(a));
                Mtemp(n,2) = double(abcorr(b));
                Mtemp(n,3) = 4.5 - (d^2)/(2*sigd^2);
            end
        end
    end

    np = double(np);
    nq = double(nq);
    
    %matrix is of course symmetric
    Mtemp((n+1):(2*n),1) = Mtemp(1:n,2);
    Mtemp((n+1):(2*n),2) = Mtemp(1:n,1);
    Mtemp((n+1):(2*n),3) = Mtemp(1:n,3);

    M = sparse(Mtemp(1:2*n,1),Mtemp(1:2*n,2),Mtemp(1:2*n,3),nq*np,nq*np,n*2);
    
    %indices of accepted matches and their scores
    xind = zeros(nq,1);
    scores = zeros(nq,1);
    
    %get the principal eigen vector (sign indifferent)
    [x_,~] = eigs(M,1);
    x_ = abs(x_);
    
    %if threshold is by distance, calculate image diameter squared
    if (n_or_scorelimit == 't')
        d = (max(P(:,1))-min(P(:,1)))^2 + (max(P(:,2))-min(P(:,2)))^2; end
    
    %iterate at the algorithm's rule, taking best match every time and
    %eliminating all conflicting candidates for evert accepted match
    [c,a_] = max(x_);
    
    %get the unique rows in from the source points, this is used to rule
    %out assignments from the same coordinates but not same index
    
    [sortQ,sort_ndx] = sortrows(Q);     %sort points by coordinates
    sortGrp = sortQ(1:nq-1,:)~=sortQ(2:nq,:);   %group identical values the array
    sortGrp = any(sortGrp,2);
    sortGrp = [true; sortGrp; 1];       %pad the "grouping" to make it valid
    rndx(sort_ndx) = 1:nq;   %translates indices to sorted indices
    
    n = 0;
    while (c ~= 0 && (n_or_scorelimit == 't' || threshold > 0))

        %the current match in question
        [i,i_] = ind2sub([nq np], a_);
        
        %if working by 'n' best matches decrease counter to keep count
        if (n_or_scorelimit == 'n')
            threshold = threshold - 1;
            
        %if we are working by threshold, check maximum distance from
        %accepted matches
        elseif (n > 0)
            %indexes of all previously accepted matches
            [j,j_] = ind2sub([nq np], xind(1:n));
            
            %calclate ratio of distances of current match with all
            %previously accepted matches
            distsP = P(i_*ones(n,1),:)-P(j_,:);
            distsQ = Q(i*ones(n,1),:)-Q(j,:);
            dists = (sqrt(distsP(:,1).^2+distsP(:,2).^2) - ...
                sqrt(distsQ(:,1).^2+distsQ(:,2).^2)).^2 / d;
            
            if (max(dists)>threshold)
                break;
            end
        end
        
        %this is an accepted match, save it in result vector
        n = n + 1;
        xind(n) = a_;
        scores(n) = c;

        %if the match we took is (i, i_) eliminate all (i, k) and (q, i_)
        x_(sub2ind([nq np], repmat(i,1,np), (1:np))) = 0;
        x_(sub2ind([nq np], (1:nq), repmat(i_,1,np))) = 0;
        
        %also, eliminate all (i^, k) where i^ has the same coordinates as i
        %not to worry, in all points that are unique both conditions are
        %false and loops are not run
        
        sort_i = rndx(i);   %get the sorted index of the point
        if (sortGrp(sort_i) == 0)      %is it a part of a group of replicates?
            tmp_sort_i = sort_i;          %save for the second loop
            
            %loop until head of group is found and eliminate pairs
            while 1
                tmp_sort_i = tmp_sort_i - 1;
                x_(sub2ind([nq np], ...
                    repmat(sort_ndx(tmp_sort_i),1,np), (1:np))) = 0;
                if (sortGrp(tmp_sort_i) == 1) 
                    break; end
            end
        end
        %loop until the next group is met and eliminate pairs
        while (sortGrp(sort_i+1) == 0)
            sort_i = sort_i + 1;
            x_(sub2ind([nq np], repmat(sort_ndx(sort_i),1,np), (1:np))) = 0;
        end
        
        [c,a_] = max(x_);
    end
    
    %construct the resulting sparse vector
    x = sparse(xind(1:n), 1, true, nq^2, 1);
    
    %if required, output the ordered pairs and their scores
    if (nargout > 1)
        [i, i_] = ind2sub([nq nq],xind(1:n));
        orderedInd = [i i_ scores(1:n)];
    end
end