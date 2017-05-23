function [ categoryBlocks ] = getCategoryBlocks( model, category)
% Obtains list of all category type blocks in model
    blockCategoryDic = getCategoryDic();
    categoryBlocks = {};
    categoryKeys = blockCategoryDic.keys;
    for i=1:length(categoryKeys)
        if (strcmp(blockCategoryDic(categoryKeys{i}), category))
            blocks = find_system(model, 'BlockType', categoryKeys{i});
            for j=1:length(blocks)
                categoryBlocks{end + 1} = blocks{j};
            end
        end
    end
end

