function blk = getBlock(h)
% h is a port or block handle

if strcmp(get_param(h, 'Type'), 'block')
    blk = getfullname(h);
elseif strcmp(get_param(h, 'Type'), 'port')
    blk = get_param(h, 'Parent');
else
    error('Error, unexpected handle type. Handle needs to be associated with a block.');
end
end