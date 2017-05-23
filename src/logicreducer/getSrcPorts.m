function srcPorts = getSrcPorts(blockName)

    srcPorts = [];
    
    lines = get_param(blockName, 'LineHandles');
    lines = lines.Inport;
    
    for i = 1:length(lines)
        srcPorts(end+1) = get_param(lines(i), 'SrcPortHandle');
    end

end