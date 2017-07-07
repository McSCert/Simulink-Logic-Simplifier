function deletedBlocks = deleteIfUnconnectedSignal(system, recursive)
% DELETEIFUNCONNECTEDSIGNAL Deletes all blocks in a given system which have
%   a port that does not connect to another block.
%
%   Inputs:
%       system      The system to delete blocks from.
%       recursive   Use true to turn this option on, false for off.
%                   When this option is turned on this function will be run
%                   recursively to delete blocks which newly meet the
%                   criteria to be deleted.
%   Outputs:
%       deletedBlocks   A list of block names of blocks that were deleted.
%                       Blocks within a deleted subsystem block will not be
%                       listed.

blocks = find_system(system,'FindAll','on','SearchDepth',1,'type','block');
connectivity = get_param(blocks, 'PortConnectivity');

deletedBlocks = {};
for i = 1:length(blocks)
    
    b = blocks(i);
    c = connectivity{i};
    
    doDelete = false;
    for j = 1:length(c) % for each port
        src = c(j).SrcBlock; % temp shorthand
        dst = c(j).DstBlock; % temp shorthand
        if (length(src) == 1 && src == -1) || (isempty(src) && isempty(dst))
            doDelete = true;
            break
        end
    end
    
    if doDelete
        name = get_param(b, 'Name');
        
        delete_block(b);
        
        assert(isempty(find_system(system,'SearchDepth',1,'Name',name)));
        deletedBlocks{end+1} = name;
    end
end

% Recurse on new system
if recursive && ~isempty(deletedBlocks)
    deletedBlocks = [deletedBlocks, deleteIfUnconnectedSignal(system, recursive)];
end

end