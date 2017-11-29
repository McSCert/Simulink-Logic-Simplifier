function bool = isSupportedBlock(h)
%

if strcmp(get_param(h, 'Type'), 'block')
    blk = h;
elseif strcmp(get_param(h, 'Type'), 'port')
    blk = get_param(h, 'Parent');
else
    error('Error, unexpected handle type. Handle needs to be associated with a block.');
end

blockType = get_param(blk, 'BlockType');
supportedBlockTypes = {};
bool = any(strcmp(blockType, supportedBlockTypes));
end