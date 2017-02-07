function connectedLocalVar = checkForConnectedLocalVar(blockName)
    blockCategoryDic = getCategoryDic();
    [srcBlocks, ~] = getConnectedBlocks(blockName);
    connectedLocalVar = '';
    for i=1:length(srcBlocks)
        fullName = [srcBlocks{i}.Path '/' srcBlocks{i}.Name];
        blockType = srcBlocks{i}.BlockType;
        switch blockCategoryDic(blockType)
            case 'Branching'
                connectedLocalVar =...
                    getExpressionForBlock(fullName);
                return;
            case 'Memory'
                connectedLocalVar =...
                    getExpressionForBlock(fullName);
                return;
            otherwise
%           do nothing
        end
         
    end
end