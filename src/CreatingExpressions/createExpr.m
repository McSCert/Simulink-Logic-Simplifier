function connectSrcs = createExpr(lhs, exprs, startSys, createIn, s_lhsTable)
% CREATEEXPR Create an expression and all of the subexpressions that go
%   into it.
%
%   Inputs:
%       lhs             LHS of an expression in exprs.
%       exprs           Cell array of expressions.
%       startSys        System from which the original blocks come from.
%       createIn        System to work in when creating the blocks.
%       s_lhsTable      Map from block/port handle in the original system
%                       to lhs in exprs.
%
%   Output:
%       connectSrcs     If blackbox: A list of the outports of the expression's
%                       LHS. Else: Single outport from the generated expression.

% just getting some values that will be useful
[lefts, ~] = getAllLhsRhs(exprs);
idx = find(strcmp(lhs, lefts));
assert(length(idx) == 1, 'Error: Expected LHS to match 1 expression.')
expr = exprs{idx};
s_blk = getBlock(s_lhsTable.lookdown(lhs));

[~, rhs] = getExpressionLhsRhs(expr);

if isBlackBoxExpression(expr)
    [~, e_blk] = createBlockCopy(s_blk, startSys, createIn);
    
    % For each inport, create the corresponding expression, then connect to the 
    % inport.
    rhsTokens = regexp(rhs, '([^,]*),|([^,]*)', 'tokens');
    ph = get_param(e_blk, 'PortHandles');
    assert(length(rhsTokens) == length(ph.Inport), 'Error: Blackbox expression expected to have the same # of terms as the corresponding block has inports.')
    for j = 1:length(rhsTokens) % Note: j is also the port number of the input to s_blk
        % Find the handle to connect to
        connectDst  = ph.Inport(j);
        
        exprIdx = find(strcmp(rhsTokens{j}{1}, lefts));
        assert(length(exprIdx) == 1, 'Error: Expected subexpression to match the LHS of 1 expression.')
        
        if true % ~e_lhsTable.lookdown.isKey(rhsTokens{j})
            bbSrcs = createExpr(rhsTokens{j}{1}, exprs, startSys, createIn, s_lhsTable);
        else
            % TODO: Branch needed probably
            error('Error: Something went wrong because functionality isn''t fully implemented yet...')
        end
        
        assert(length(bbSrcs) == 1, 'Error: Expression should have only 1 outgoing connection.')
        connectPorts(createIn, bbSrcs, connectDst)
    end
    
    % connectSrcs should be a matrix of the outputs of the blackbox
    connectSrcs = ph.Outport;
else
    % Expression is a logical one that we can create
    % Create blocks based on the RHS to later connect to the LHS (outside
    % of this function)
    connectSrcs = createLogic(rhs, exprs, startSys, createIn, 1, s_lhsTable);
end
end

function [e_bh, e_blk] = createBlockCopy(s_blk, startSys, createIn)
% Doesn't create if the block already exists

e_blk = regexprep(s_blk,['^' startSys], createIn, 'ONCE'); % Name of the block to put in endSys
if isempty(find_system(createIn, 'Name', get_param(s_blk, 'Name'))) % block not made yet
    % Create block
    e_bh = add_block(s_blk, e_blk);
else
    e_bh = get_param(e_blk, 'Handle');
end
end