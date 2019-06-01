function deleteBlockChain(block, mode, delBlocks)
% DELETEBLOCKCHAIN Delete the input block, and then recursively delete the chain
% of blocks which only impacted the input block.
%
%   Inputs:
%       block       Block name or handle at the head of a deletion chain.
%       mode        TODO: Currently has no impact [Optional]
%       delBlocks   Upper bound for which blocks may be deleted. If not
%                   provided, it is assumed that any block sharing a
%                   system with block may be deleted. [Optional]

    mode = 'default'; % TODO: Define mode to change the conditions on recursing

    sys = get_param(block, 'Parent');
    block = get_param(block, 'Handle');

    if nargin < 3
        delBlocks = [];
    else
        delBlocks = inputToNumeric(delBlocks);
    end

    % Get source blocks for recursion
    srcBlocks = getSrcBlocks(block);

    % Delete block and the lines connected to it
    if isempty(delBlocks) || any(block == delBlocks)
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
    end % else not allowed to delete the block. Lines not deleted now may still be deleted in recursive calls.

    % Recurse on the source blocks
    for i = 1:length(srcBlocks)
        if strcmp(mode, 'default')
            if isempty(getDstObjs(srcBlocks(i))) ... % Must not impact others
                    && strcmp(get_param(srcBlocks(i), 'Parent'), sys) ... % Must be in starting system
                    && ~strcmp(get_param(srcBlocks(i), 'BlockType'), 'Inport') % Must not be an inport
                    % TODO: Should be allowed to impact others as long as
                    % the others are contained within srcBlocks
                deleteBlockChain(srcBlocks(i), mode, delBlocks)
            end
        else
            deleteBlockChain(srcBlocks(i), mode, delBlocks)
        end
    end
end

function srcBlocks = getSrcBlocks(block)
    srcBlocks = getSrcs(block, 'IncludeImplicit', 'on', ...
        'ExitSubsystems', 'off', 'EnterSubsystems', 'off', ...
        'Method', 'ReturnSameType');
end
function srcBlocks = getSrcBlocks_old(block)
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
end

function dstBlocks = getDstObjs(block)
    dstBlocks = getDsts(block, 'IncludeImplicit', 'on', ...
        'ExitSubsystems', 'off', 'EnterSubsystems', 'off', ...
        'Method', 'ReturnSameType');
end
function dstObjs = getDstObjs_old(block)
    dstObjs = getDsts(block);
end