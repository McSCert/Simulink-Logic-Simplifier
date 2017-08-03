function deletedBlocks = deleteIfNoOut(blocks, recursive)
% DELETEIFNOOUT Deletes any of the given blocks in a given system which 
%   don't contribute to output. Specifically, if a block has only 
%   unconnected outports then it will be assumed to have no outputs unless 
%   it is a SubSystem in which case it will be assumed to have implicit 
%   outputs (from usage of goto/from or data store read/write blocks). This
%   may be performed recursively to delete all blocks in a chain that don't
%   contribute output.
%
%   Inputs:
%       blocks      Vector of blocks that may be deleted.
%       recursive   Use true to turn this option on, false for off.
%                   When this option is turned on this function will be run
%                   recursively to delete blocks which newly meet the
%                   criteria to be deleted.
%   Outputs:
%       deletedBlocks   A list of names of blocks that were deleted.
%
%   Example:
%       blocks = find_system(logicSys,'FindAll','on','SearchDepth',1,'type','block');
%       deleteIfNoOut(blocks, true);

% connectivity = get_param(blocks, 'PortConnectivity');

deletedBlocks = {};
for i = length(blocks):-1:1
    
    b = blocks(i);
%     c = connectivity{i};
    
%     doDelete = false;
%     doDelete = true;
%     p = find_system(b,'FindAll','on','SearchDepth',1,'Type','port','Parent',getfullname(b));
    if strcmp(get_param(b, 'BlockType'), 'SubSystem')
        doDelete = false;
    else
        p = get_param(b, 'PortHandles');
        o = p.Outport;
        if ~isempty(o)
            doDelete = true; % May become false again later
        else
            doDelete = false;
        end
        
        for j = 1:length(o) % for each outport
            % If outport and IS connected then doDelete = false
%             if strcmp(get_param(p(j),'PortType'),'outport') % is outport
            line = get_param(o(j), 'Line');
            if line ~= -1 % line exists
                if get_param(line,'DstPortHandle') ~= -1 % line is connected
                    doDelete = false;
                    break
                end
            end
%             end
        end
    end
%     for j = 1:length(c) % for each port
%         src = c(j).SrcBlock; % temp shorthand
%         dst = c(j).DstBlock; % temp shorthand
%         if (length(src) == 1 && src == -1) || (isempty(src) && isempty(dst))
%             doDelete = true;
%             break
%         end
%     end
    
    if doDelete
        name = get_param(b, 'Name');
        sys = get_param(b, 'Parent');
        
        delete_block(b);
        
        assert(isempty(find_system(sys,'SearchDepth',1,'Name',name)));
        deletedBlocks{end+1} = name;
        blocks(i) = [];
    end
end

% Recurse on new system
if recursive && ~isempty(deletedBlocks)
    deletedBlocks = [deletedBlocks, deleteIfNoOut(blocks, recursive)];
end

end