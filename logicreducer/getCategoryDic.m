function  blockCategoryDic  = getCategoryDic( )
%GETCATEGORYDIC Summary of this function goes here
%   Detailed explanation goes here
    if(~exist('categoryDic', 'var'))
        global categoryDic;
        categoryDic = getConfigInfo('config.xml');
        blockCategoryDic = categoryDic;
    else
        blockCategoryDic = categoryDic;
    end

end

