function [srcBlocks, destBlocks] = getConnectedBlocks(blockName)
% get the connected simulink blocks to another simulink block
%
    srcBlocks = {};
    destBlocks = {};
    conns = get_param(blockName, 'PortConnectivity');
    n=numel(conns);
    for j=1:n    
        for k=1:length(conns(j).SrcBlock)
            srcBlocks{end + 1} = get(conns(j).SrcBlock(k));
        end
        for i=1:length(conns(j).DstBlock)
            destBlocks{end + 1} = get(conns(j).DstBlock(i));
        end
    end
end

