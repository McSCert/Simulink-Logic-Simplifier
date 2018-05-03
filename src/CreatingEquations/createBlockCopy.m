function [e_bh, e_blk] = createBlockCopy(s_blk, startSys, createIn, s2e_blockHandles)
    
    % Create block
    assert(startSys, get_param(block, 'Parent'))
    e_bh = copy_block(s_blk, createIn);
    e_blk = getfullname(e_bh);
    
    % Record that the created block is related to s_blk
    s_bh = get_param(s_blk, 'Handle');
    s2e_blockHandles(s_bh) = e_bh; % This is a map object so it will be updated
    
end