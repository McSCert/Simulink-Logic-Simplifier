function deleteBlockChain(block, mode)
    % DELETEBLOCKCHAIN Deletes input block, and then recursively deletes
    % the chain of blocks which only impacted the input block.
    %
    %   Input:
    %       block   Block name or handle at the head of a deletion chain.
    %       mode    TODO: Currently has no impact
    
    mode = 'default'; % TODO: Define mode to change the conditions on recursing
    
    sys = get_param(block, 'Parent');
    
    % Get source blocks for recursion
    srcs = getSrcs(block);
    srcBlocks = zeros(length(srcs),1);
    for i = 1:length(srcs)
        if strcmp(get_param(srcs{i}, 'Type'), 'port')
            srcBlocks(i) = get_param(get_param(srcs{i}, 'Parent'), 'Handle');
        else
            srcBlocks(i) = get_param(srcs{i}, 'Handle');
        end
    end
    srcBlocks = unique(srcBlocks); % No need for duplicates
    
    % Delete block and the lines connected to it
    lines = get_param(block, 'LineHandles');
    fields = fieldnames(lines);
    for i = 1:length(fields)
        for j = 1:length(lines.(fields{i}))
            if lines.(fields{i})(j) ~= -1
                delete_line(lines.(fields{i})(j));
            end
        end
    end
    delete_block(block);
    
    % Recurse on the source blocks
    for i = 1:length(srcBlocks)
        if strcmp(mode, 'default')
            if isempty(getDsts(srcBlocks(i))) ... % Must not impact others
                    && strcmp(get_param(srcBlocks(i), 'Parent'), sys) ... % Must be in starting system
                    && ~strcmp(get_param(srcBlocks(i), 'BlockType'), 'Inport') % Must not be an inport
                    % TODO: Should be allowed to impact others as long as
                    % the others are contained within srcBlocks
                deleteBlockChain(srcBlocks(i))
            end
        else
            deleteBlockChain(srcBlocks(i))
        end
    end
end