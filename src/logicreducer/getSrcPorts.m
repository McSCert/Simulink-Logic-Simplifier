function srcPorts = getSrcPorts(block)
%
% block can be either the name or the handle
%
% srcPorts is the handles of the ports which act as sources to the given
%   block

    srcPorts = [];
    
    lines = get_param(block, 'LineHandles');
    lines = lines.Inport;
    
    for i = 1:length(lines)
        srcPorts(end+1) = get_param(lines(i), 'SrcPortHandle');
    end

end