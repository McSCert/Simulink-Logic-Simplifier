function depth = getDepth(startSys, block)
    % GETDEPTH Gets the depth of block relative to an initial system. If
    % the block is directly within the system, then its depth is 0. If the
    % block is not directly within the system, then its depth is that of
    % its parent subsystem plus 1.
    %
    % Assumes: block is somewhere within startSys
    
    startSys = getfullname(startSys); % If startSys is a handle
    
    depth = 0;
    sys = get_param(block, 'Parent');
    while ~strcmp(startSys, sys)
        depth = depth + 1;
        sys = get_param(sys, 'Parent');
    end
end