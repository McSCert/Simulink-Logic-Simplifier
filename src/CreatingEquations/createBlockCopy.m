function [e_bh, e_blk] = createBlockCopy(s_blk, startSys, createIn, s2e_blockHandles)
% CREATEBLOCKCOPY Create a copy of a given block from a given system in another
% given system and record in a containers.Map object that the created block came
% from the given block.
%
%   Inputs:
%       s_blk               Full path or handle of a block.
%       startSys            System the block is from. (This input should be
%                           removed in a future release).
%       createIn            Target system to copy the block to.
%
%   Updates:
%       s2e_blockHandles    containers.Map object using handles of copied blocks
%                           as keys and handles of the pasted blocks as values.
%
%   Outputs:
%       e_bh                Handle of the pasted block.
%       e_blk               Fullname of the pasted block.
%

    % Create block
    e_bh = copy_block(s_blk, createIn);
    e_blk = getfullname(e_bh);

    % Record that the created block is related to s_blk
    s_bh = get_param(s_blk, 'Handle');
    s2e_blockHandles(s_bh) = e_bh; % This is a map object so it will be updated
end