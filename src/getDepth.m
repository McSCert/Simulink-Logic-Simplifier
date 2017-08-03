function depth = getDepth(startSys, block)

startSys = getfullname(startSys); % If startSys is a handle

depth = 0;
sys = get_param(block, 'Parent');
while ~strcmp(startSys, sys)
    depth = depth + 1;
    sys = get_param(sys, 'Parent');
end
end