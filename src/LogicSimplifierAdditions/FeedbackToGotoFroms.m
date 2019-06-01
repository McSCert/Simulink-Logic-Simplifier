function FeedbackToGotoFroms(model)
% FEEDBACKTOGOTOFROMS Turn feedback signals into Goto/From connections.
%
%   Inputs:
%       model   Model name.
%
%    Outputs:
%       N/A

    % Get the start blocks
    startBlocks = getStartBlocks(model);

    % Find line feedbacks by traversing forward through model and finding
    % revisited blocks. This uses a breadth first search of the model.
    visitedBlocks = {};
    feedbackLines = [];
    recurseCell = startBlocks;
    while ~isempty(recurseCell)
        currentBlock = recurseCell{1};
        if (length(recurseCell) > 1)
            recurseCell = recurseCell{2:end};
            if ~iscell(recurseCell)
                recurseCell = {recurseCell};
            end
        else
            recurseCell ={};
        end
        visitedBlocks{end + 1} = currentBlock;
        outLines = get_param(currentBlock, 'LineHandles');
        outLines = outLines.Outport;
        for i = 1:length(outLines)
            currLine = outLines(i);
            dstBlocks = getfullname(get_param(currLine, 'DstBlockHandle'));
            if ~iscell(dstBlocks)
                dstBlocks = {dstBlocks};
            end
            for j = 1:length(dstBlocks)
                if isempty(intersect(visitedBlocks, dstBlocks{j}))
                    recurseCell{end + 1} = [recurseCell dstBlocks{j}];
                else
                    feedbackLines(end + 1) = currLine;
                end
            end
        end
    end

    for i = 1:length(feedbackLines)
        try
            line2Goto(model, feedbackLines(i), ['Feedback_' num2str(i)])
        end
    end
end