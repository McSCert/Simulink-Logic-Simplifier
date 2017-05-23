function connectedLocalVar = checkForConnectedLocalVar(blockName)
    blockCategoryDic = getCategoryDic();
    [srcBlocks, ~] = getConnectedBlocks(blockName);
    connectedLocalVar = '';
    for i=1:length(srcBlocks)
        fullName = [srcBlocks{i}.Path '/' srcBlocks{i}.Name];
        blockType = srcBlocks{i}.BlockType;
        switch blockCategoryDic(blockType)
            case 'Branching'
                port = get_param(fullName, 'PortHandles');
                port = port.Outport;
                connectedLocalVar =...
                    getExpressionForBlock(port);
                return;
            case 'Memory'
                port = get_param(fullName, 'PortHandles');
                port = port.Outport;
                connectedLocalVar =...
                    getExpressionForBlock(port);
                return;
            otherwise
%           do nothing
        end
         
    end
end