function startBlocks = getStartBlocks(model)
% GETSTARTBLOCKS Find blocks that are starting points in a model (inports, froms, etc.).
%
%   Inputs:
%       model   Model name.
%
%    Outputs:
%       N/A

    blocks = find_system(model, 'SearchDepth', 1, 'FollowLinks', 'on', 'LookUnderMasks', 'all');
    blocks = setdiff(blocks, model);
    startBlocks = {};

    for i = 1:length(blocks)
        lines = get_param(blocks{i}, 'LineHandles');
        inLines = lines.Inport;
        if isempty(inLines)
            startBlocks{end+1} = blocks{i};
        end
    end
end