function  name  = getLocalVarName( blockName )
% This function gets a unique name (corresponding to some unique simulink 
% block name. It first computes hash digest of simulink block name, then
% maps it to an index.
    blockType = get_param(blockName, 'BlockType');
    if(strcmp(blockType, 'Outport') || strcmp(blockType, 'Inport'))
        name = get_param(blockName, 'Name');
    else
        index = int2str(getIndexForNameKey(string2hash(blockName)));
        name = [lower(blockType) index '_out'];
    end
end

