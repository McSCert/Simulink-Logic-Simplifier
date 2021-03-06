function [startIdx, endIdx] = findLastOp(expr, varargin)
% FINDLASTOP Finds the starting index in a given expression of the last
%   operator to evaluate. The significance of the operator is that it
%   determines the substructure of the expression. If there are no
%   operators, return startIdx = 0, endIdx = 0.
%
%   Inputs:
%       expr            Logic Simplifier expression.
%       varargin{1}     'alt' to call findLastOp_alt instead.
%
%   Outputs:
%       startIdx        Starting index of the last operator.
%       endIdx          Ending index of the last operator.
%
%   Example 1:
%       expr = '~x <= y';
%       [startIdx, endIdx] = getLastOp(expr) -> startIdx = 4, endIdx = 5
%   Example 2:
%       expr = '~x & y < 1 | (((TRUE)) == ((0 < z)) ~= FALSE) & ~TRUE & 0 < 1 & (TRUE == FALSE | 0 == y)';
%       %                  | <- this is the last
%       [startIdx, endIdx] = getLastOp(expr)
%       startIdx == 12 && endIdx == 12
%   Example 3:
%       expr = '~x & y < 1 | (((TRUE)) == ((0 < z)) ~= FALSE) & ~TRUE & 0 < 1 & (TRUE == FALSE | 0 == y) | x < y';
%       %                                                                            this is the last -> |
%       [startIdx, endIdx] = getLastOp(expr)
%   Example 4:
%       expr = '(~(x & y < 1) >= (((TRUE)) == ((0 < z)) ~= FALSE) & (~TRUE) & (0 < 1 & (TRUE == FALSE | 0 == y)) == x < y)';
%       %                                               this is the last -> &
%       [startIdx, endIdx] = getLastOp(expr)
%   Example 5:
%       expr = '~~x';
%       %       ~ <- this is the last
%       [startIdx, endIdx] = getLastOp(expr)
%   Example 6:
%       expr = 'x';
%       % no op so return 0
%       [startIdx, endIdx] = getLastOp(expr)
%
    
    % http://www.ele.uri.edu/~daly/106/precedence.html
    % Reference for order of precedence in MATLAB (1 is highest precedence):
    %   0. [0-9a-zA-Z]  (indicates the 1/0 should be associated with an identifier)
    %   1. ( )
    %   2. N/A
    %   3. ~
    %   4. -    (I'm assuming this operation is done like multiplication)
    %   5. N/A
    %   6. > >= < <= == ~=
    %   7. &
    %   8. |
    
    if ~isempty(varargin) && strcmp(varargin{1}, 'alt')
        [startIdx, endIdx] = findLastOp_alt(expr);
    else
        
        % Find operators that occur outside parentheses
        % For the operator type with lowest precedence, find the furthest left occurrence
        %   This is the last operator that will evaluate.
        % If no operators are outside parentheses, the last is the last of the
        % contents of those parentheses.
        
        if strcmp(expr(1), '(') && findMatchingParen(expr,1) == length(expr)
            [startIdx, endIdx] = findLastOp(expr(2:end-1));
            if startIdx ~= 0
                startIdx = 1 + startIdx;
                endIdx = 1 + endIdx;
            end
        else
            idx = 1;
            opIdxs = [];
            while idx < length(expr)
                nextOpen = idx - 1 + regexp(expr(idx:end), '\(', 'once');
                
                pat = '>=|<=|~=|==|>|<|~|&|\|';
                if isempty(nextOpen)
                    idx2 = length(expr);
                    opIdxs = getOdIdxs(opIdxs);
                    idx = length(expr);
                else
                    idx2 = nextOpen - 1;
                    opIdxs = getOdIdxs(opIdxs);
                    idx = findMatchingParen(expr,nextOpen) + 1;
                end
            end
            if isempty(opIdxs)
                startIdx = 0;
                endIdx = 0;
            else
                operator = getOp(expr(opIdxs(end):end));
                minPrec = getOpPrecedence(operator); % lowest operator precedence found thus far
                startIdx = opIdxs(end); % index of operator with lowest precedence found thus far
                for i = opIdxs(end-1:-1:1)
                    operator = getOp(expr(i:end));
                    if getOpPrecedence(operator) < minPrec
                        minPrec = getOpPrecedence(operator);
                        startIdx = i;
                    elseif getOpPrecedence(operator) == minPrec
                        % if precedence is equal,
                        %   take the rightmost because of left associativity (i.e.
                        %       x & y & z executes as (x & y) & z)
                        %   unless the operator is ~
                        %       when the operator is ~ take the leftmost (because
                        %       ~~x executes as ~(~x) and other situations will
                        %       have an operator of lower precedence)
                        
                        if strcmp(operator, '~')
                            startIdx = i;
                        end % else rightmost operator of this precedence is already selected
                    end
                end
                endIdx = startIdx - 1 + regexp(expr(startIdx:end), '^(>=|<=|~=|==|>|<|~|&|\|)','end');
            end
        end
    end
    
    assert((startIdx == 0 && endIdx == 0) || (startIdx ~= 0 && endIdx ~= 0))
    
    function idxs = getOdIdxs(idxs)
        idxs = [idxs, idx - 1 + regexp(expr(idx:idx2), pat)];
    end
    
    function op = getOp(str)
        % str is a char array beginning with an operator
        % op is a char array with just the operator
        opPat = '>=|<=|~=|==|>|<|~|&|\|';
        op = regexp(str,['^(' opPat ')'],'match');
        op = op{1};
    end
    function prec = getOpPrecedence(op)
        switch op
            case '~'
                prec = 4;
            case {'>','>=','<','<=','==','~='}
                prec = 3;
            case '&'
                prec = 2;
            case '|'
                prec = 1;
            otherwise
                error('Unexpected operator')
        end
    end
end

function [startIdx, endIdx] = findLastOp_alt(expr)
    % This alteration of findLastOp means that it will find the operators
    % for the next subexpression(s) rather than the last operator overall.
    % E.g. (expr) now has no 'last operator'  even if expr has an operator.
    % Only expressions of the following forms will have a 'last operator':
    %   expr op expr
    %   op expr
    % (whitespace can be ignored)
    
    if strcmp(expr(1), '(') && findMatchingParen(expr,1) == length(expr)
        startIdx = 0;
        endIdx = 0;
    else
        [startIdx, endIdx] = findLastOp(expr);
    end
end