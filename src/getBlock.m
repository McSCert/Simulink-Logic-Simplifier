function blk = getBlock(h)
% GETBLOCK Get the block corresponding to a block or port handle.
%
%   Inputs:
%       h   Port or block handle.
%
%   Outputs:
%       blk Fullname of the block corresponding with h.
%
    
    if strcmp(get_param(h, 'Type'), 'block')
        blk = getfullname(h);
    elseif strcmp(get_param(h, 'Type'), 'port')
        blk = get_param(h, 'Parent');
    else
        error('Error, unexpected handle type. Handle needs to be associated with a block.');
    end
end