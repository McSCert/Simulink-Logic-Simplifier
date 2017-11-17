function connectSrcs = createExpr(lhs, exprs, startSys, createIn, s_lhsTable, e_lhs2handle, s2e_blockHandles)
% CREATEEXPR Create an expression and all of the subexpressions that go
%   into it.
%
%   Inputs:
%       lhs             LHS of an expression in exprs.
%       exprs           Cell array of expressions.
%       startSys        System from which the original blocks come from.
%       createIn        System to work in when creating the blocks.
%       s_lhsTable      Map from block/port handle in the original system
%                       to lhs in exprs and vice versa. (2-way map)
%       e_lhs2handle    Map from lhs in exprs to block/port handle in the 
%                       final system. (1-way map)
%       s2e_blockHandles    Map of block handles from the start system to the
%                           end system.
%
%   Output:
%       connectSrcs     If blackbox: A list of the outports of the expression's
%                       LHS. Else: Single outport from the generated expression.

% just getting some values that will be useful
[lefts, ~] = getAllLhsRhs(exprs);
idx = find(strcmp(lhs, lefts));
assert(length(idx) == 1, 'Error: Expected LHS to match 1 expression.')
expr = exprs{idx};
s_h = s_lhsTable.lookdown(lhs);
s_blk = getBlock(s_h);

[~, rhs] = getExpressionLhsRhs(expr);

if isBlackBoxExpression(expr)
    
    if ~e_lhs2handle.isKey(lhs)
        s_bh = get_param(s_blk, 'Handle');
        if ~s2e_blockHandles.isKey(s_bh)
            [~, e_blk] = createBlockCopy(s_blk, startSys, createIn, s2e_blockHandles);
        else
           % block already created 
           e_blk = getfullname(s2e_blockHandles(s_bh));
        end
        
        % Record that lhs has been added
        switch expressionType(s_h)
            case 'out'
                oPorts = getPorts(e_blk, 'Outport');
                pNum = getExprPortNumber(expr, s_lhsTable);
                e_h = oPorts(pNum);
                e_lhs2handle(lhs) = e_h;
            case 'blk'
                e_h = e_bh;
                e_lhs2handle(lhs) = e_h;
            case 'in'
                error('Error: Something went wrong, expression type should not be ''in'' as well as blackbox.')
            otherwise
                error('Error: Unexpected eType')
        end
    else
        e_blk = getBlock(e_lhs2handle(lhs));
    end
    
    % For each inport, create the corresponding expression, then connect to the 
    % inport.
    rhsTokens = regexp(rhs, '([^,]*),|([^,]*)', 'tokens');
    inPorts = getPorts(e_blk, 'In');
    assert(length(rhsTokens) == length(inPorts), 'Error: Blackbox expression expected to have the same # of terms as the corresponding block has inports.')
    for j = 1:length(rhsTokens) % Note: j is also the port number of the input to s_blk
        % Find the handle to connect to
        connectDst  = inPorts(j);
        
        exprIdx = find(strcmp(rhsTokens{j}{1}, lefts));
        assert(length(exprIdx) == 1, 'Error: Expected subexpression to match the LHS of 1 expression.')
        
        if true % ~e_lhs2handle.isKey(rhsTokens{j})
            bbSrcs = createExpr(rhsTokens{j}{1}, exprs, startSys, createIn, s_lhsTable, e_lhs2handle, s2e_blockHandles);
        else
            % TODO: Branch needed probably
            error('Error: Something went wrong because functionality isn''t fully implemented yet...')
        end
        
        assert(length(bbSrcs) == 1, 'Error: Expression should have only 1 outgoing connection.')
        connectPorts(createIn, bbSrcs, connectDst);
    end
    
    switch expressionType(s_h)
        case 'out'
            connectSrcs = e_lhs2handle(lhs);
        case 'blk'
            % connectSrcs should be a matrix of the outputs of the blackbox
            connectSrcs = getPorts(e_blk, 'Outport');
        case 'in'
            error('Error: Expression type should not be ''in'' as well as blackbox.')
        otherwise
            error('Error: Unexpected eType')
    end
else
    % Expression is a logical one that we can create
    % Create blocks based on the RHS to later connect to the LHS (outside
    % of this function)
    connectSrcs = createLogic(rhs, exprs, startSys, createIn, 1, s_lhsTable, e_lhs2handle, s2e_blockHandles);
    
    assert(length(connectSrcs) == 1, 'Error: Non-blackbox expression didn''t have 1 output.')
    e_lhs2handle(lhs) = connectSrcs;
end
end

function [e_bh, e_blk] = createBlockCopy(s_blk, startSys, createIn, s2e_blockHandles)

e_blk = regexprep(s_blk,['^' startSys], createIn, 'ONCE'); % Default name of the block to put in endSys

% Create block
e_bh = add_block(s_blk, e_blk, 'MakeNameUnique', 'On');
e_blk = getfullname(e_bh);

% Record that the created block is related to s_blk
s_bh = get_param(s_blk, 'Handle');
s2e_blockHandles(s_bh) = e_bh; % This is a map object so it will be updated

end

% function [e_bh, e_blk] = createBlockCopy(s_blk, startSys, createIn)
% % Doesn't create if the block already exists
% 
% e_blk = regexprep(s_blk,['^' startSys], createIn, 'ONCE'); % Name of the block to put in endSys
% if isempty(find_system(createIn, 'Name', get_param(s_blk, 'Name'))) % block not made yet
%     % Create block
%     e_bh = add_block(s_blk, e_blk);
% else
%     e_bh = get_param(e_blk, 'Handle');
% end
% end