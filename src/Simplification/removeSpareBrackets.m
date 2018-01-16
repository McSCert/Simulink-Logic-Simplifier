function newExpr = removeSpareBrackets(expr)
% REMOVESPAREBRACKETS Takes an expression and removes any redundant
%   brackets, i.e. brackets which surround the entire expression 
%   (e.g. '(abc)' -> 'abc') or brackets which surround a subexpression 
%   which is surrounded in brackets (e.g. 'abc + ((def)) + ghi' ->
%   'abc + (def) + ghi').
%
%   Input:
%       expr        A char array. Brackets are expected to be balanced.
%
%   Output:
%       newExpr     A char array. The result of removing redundant brackets
%                   from expr.

newExpr = expr;

%% Remove brackets surrounding the whole expression
flag = true;
while flag
    flag = false;
    if strcmp(newExpr(1), '(')
        endIdx = findMatchingParen(newExpr,1);
        if endIdx == length(newExpr)
            % Remove brackets surrounding the whole expression
            newExpr = newExpr(2:end-1);
            
            % Set flag to true; continue looping until brackets no longer 
            % surround the whole expression.
            flag = true;
        end
    end
end

%% Remove brackets in which the enclosed expression is surrounded in brackets
i = 1;
while i < length(newExpr)
    if strcmp(newExpr(i), '(')
        endIdx = findMatchingParen(newExpr,i);
        subExpr = removeSpareBrackets(newExpr(i+1:endIdx-1));
        newExpr = [newExpr(1:i), subExpr, newExpr(endIdx:end)];
        i = i + length(subExpr) + 2; % Continue after the ending bracket
    else
        i = i + 1;
    end
end

end