function subexprs = findNextSubexpressions(expr)
    % FINDSUBEXPRESSIONS Finds the immediate subexpressions for a given
    %   expression.
    %   E.g. (x&y)|z is an expression which we say has the following
    %   subexpressions:
    %       x, y, z, x&y, (x&y)
    %   We refer to (x&y) and z as the "immediate" subexpressions as they
    %   form a minimal set of subexpressions needed to determine all other
    %   subexpressions of (x&y)|z.
    %   E.g. (expr) is an expression with immediate subexpression of expr.
    %   I.e. parentheses are considered to create a new subexpression.
    %   E.g. x is an expression with the no immediate subexpression.
    %
    %   Input:
    %       expr        Char array of an expression.
    %
    %   Output:
    %       subexprs    Cell array of immediate subexpressions of expr.
    %                   Given in order from left-to-right within the
    %                   expression.
    %
    
    if strcmp(expr(1), '(') && findMatchingParen(expr,1) == length(expr)
        % Get rid of excess outer parentheses
        subexprs = {expr(2:end-1)};
    else
        [startIdx, endIdx] = findLastOp(expr);
        if startIdx == 0
            % no subexpression exists
            subexprs = {};
        else
            op = expr(startIdx:endIdx);
            if strcmp(op,'~')
                % expr is of form "~subexpr"
                assert(endIdx == 1)
                subexprs = {expr(endIdx+1:end)};
            else
                % expr is of form "subexpr1 op subexpr2"
                subexprs = {expr(1:startIdx-1), expr(endIdx+1:end)};
            end
        end
    end
end