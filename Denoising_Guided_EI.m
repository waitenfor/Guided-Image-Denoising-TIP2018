%--------------------------------------------------------------------------------------------------------------------
% External Prior Guided Internal Prior Learning for Real-World Noisy Image Denoising
% IEEE Transactions on Image Processing (TIP), 2018.
% Author:  Jun Xu, csjunxu@comp.polyu.edu.hk/nankaimathxujun@gmail.com
%              The Hong Kong Polytechnic University
%--------------------------------------------------------------------------------------------------------------------
function  [im_out,Par] = Denoising_Guided_EI(Par,model)
im_out = Par.nim;
[h,  w, ch] = size(im_out);
Par.maxr = h-Par.ps+1;
Par.maxc = w-Par.ps+1;
Par.maxrc = Par.maxr * Par.maxc;
Par.h = h;
Par.w = w;
Par.ch = ch;
r = 1:Par.step:Par.maxr;
Par.r = [r r(end)+1:Par.maxr];
c = 1:Par.step:Par.maxc;
Par.c = [c c(end)+1:Par.maxc];
Par.lenr = length(Par.r);
Par.lenc = length(Par.c);
Par.lenrc = Par.lenr*Par.lenc;
Par.ps2 = Par.ps^2;
Par.ps2ch = Par.ps2*Par.ch;
for ite = 1 : Par.IteNum
    % search non-local patch groups
    [nDCnlX,blk_arr,DC,Par] = Image2PGs( im_out, Par);
    % Gaussian dictionary selection by MAP
    if mod(ite-1,2) == 0
        %% GMM: full posterior calculation
        nPG = size(nDCnlX,2)/Par.nlsp; % number of PGs
        PYZ = zeros(model.nmodels,nPG);
        for i = 1:model.nmodels
            sigma = model.covs(:,:,i);
            [R,~] = chol(sigma);
            Q = R'\nDCnlX;
            TempPYZ = - sum(log(diag(R))) - dot(Q,Q,1)/2;
            TempPYZ = reshape(TempPYZ,[Par.nlsp nPG]);
            PYZ(i,:) = sum(TempPYZ);
        end
        %% find the most likely component for each patch group
        [~,dicidx] = max(PYZ);
        dicidx=repmat(dicidx, [Par.nlsp 1]);
        dicidx = dicidx(:);
        [idx,  s_idx] = sort(dicidx);
        idx2 = idx(1:end-1) - idx(2:end);
        seq = find(idx2);
        seg = [0; seq; length(dicidx)];
    end
    % Weighted Sparse Coding
    Y_hat = zeros(Par.ps2ch,Par.maxrc,'double');
    W_hat = zeros(Par.ps2ch,Par.maxrc,'double');
    for   j = 1:length(seg)-1
        idx =   s_idx(seg(j)+1:seg(j+1));
        cls =   dicidx(idx(1));
        Y = nDCnlX(:,idx);
        De = Par.D{cls};
        b = De'*Y;
        De = De(:,1:Par.En);
        Se = Par.S{cls};
        lambdae = repmat(Par.c1./ (sqrt(Se)+eps),[1 length(idx)]);
        % soft threshold
        alpha = sign(b).*max(abs(b)-lambdae,0);
        alphai = alpha(Par.En+1:end,:);
        [U,~,V] = svd((eye(size(Y,1))-De*De')*Y*alphai','econ');
        Di = U*V';
        % lambdai = repmat(Par.c2./ (sqrt(Se)+eps),[1 length(idx)]);
        Dnew = [De Di];
        bnew = Dnew'*Y;
        % soft threshold
        alphanew = sign(bnew).*max(abs(bnew)-lambdae,0);
        Dnew*alphanew;
        % add DC components and aggregation
        Y_hat(:,blk_arr(:,idx)) = Y_hat(:,blk_arr(:,idx)) + bsxfun(@plus, Dnew*alphanew, DC(:,blk_arr(:,idx)));
        W_hat(:,blk_arr(:,idx)) = W_hat(:,blk_arr(:,idx)) + ones(Par.ps2ch, length(idx));
    end
    % Reconstruction
    im_out = PGs2Image(Y_hat,W_hat,Par);
end
im_out(im_out > 1) = 1;
im_out(im_out < 0) = 0;
return;
