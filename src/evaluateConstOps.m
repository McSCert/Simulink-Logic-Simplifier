function newExpr = evaluateConstOps(expression)
% EVALUATECONSTOPS evaluates operations involving constants to simplify an
%   input expression.
%
%   Inputs:
%       expression  Character array of a logical expression consisting of
%                   brackets, logical negation, unary minus, relational
%                   operators, logical AND, logical OR, as well as
%                   whitespace, numeric values, boolean values, and
%                   identifiers. {(, ), ~, -, <, <=, >, >=, ==, ~=, &,
%                   |,  , [0-9]+, TRUE, FALSE, [a-zA-Z][a-zA-Z0-9]*}
%
%   Outputs:
%       newExpr     Reduced expression equivalent to the original, but
%                   after evaluating operators in which the operands were
%                   constants. Note that whitespace will be removed and
%                   brackets may be added to make precedence more clear
%                   (some of these brackets may be excessive).
%
%   Example:
%       evaluateConstOps('1 == 2 & a')
%       --> '0&a'

%   Test Case:
%       evaluateConstOps('((0))==1|0&a&1~=~-2')

% Remove whitespace
newExpr = regexprep(expression,'\s','');

% Apply brackets appropriately
newExpr = bracketForPrecedence(newExpr);

[~, newExpr] = reduceR(newExpr);

% Remove outer brackets
while strcmp(newExpr(1),'(')
    assert(strcmp(newExpr(end),')'));
    newExpr = newExpr(2:end-1);
end
end

function [isAtomic, newStr] = reduceR(str)
% Recursively reduce the given expression (str) by evaluating parts of the
% expression which can already be evaluated.

% % Method below returns the wrong value for isAtomic when str is a variable
% % Fast return in base case that already evaluates
% [isAtomic, newStr] = evalInEmptyWS(str);
% if isAtomic
%     return
% else
%     clear isAtomic newStr
% end

% Else do longer method (longer method will assume that the part above does
% not exist and thus will have some redundancies for expressions which
% evaluate on their own)

% If first char is '(', find match,
%   if match is end of str, recurse on contents
%   else find the operator after the match (guaranteed by
%       bracketForPrecedence function if parens are balanced), recurse on
%       left hand side of operator then on right hand side of operator.
%       i.e. (lhs)>(rhs) recurses on '(lhs)' and '(rhs)'
%       Then continue with other operators which may appear further on the
%       right.
% else if first char is '~|-' recurse on everything after
% else is variable or value

if strcmp(str(1), '(')
    % The form of the expression is either: 
    %   '(expr)' or '(expr1)OP(expr2)OP...OP(exprN)'
    %   where OP is a binary operator of constant precedence 
    %   and expr,expr1,expr2,...,exprN are expressions
    
    matchIndex = findMatchingParen(str,1);
    if matchIndex == length(str) % expression is of form '(expr)'
        [isAtomic, newStr] = reduceFullBracket(str);
    else % expression is of form '(expr1)OP(expr2)OP...OP(exprN)'
        [isAtomic, newStr] = reduceOps(str);
    end
elseif ~isempty(regexp(str(1),'~|-', 'once')) % is ~ or -
    [subIsAtomic, subStr] = reduceR(str(2:end));
    
    newStr = [str(1), subStr];
    
    if subIsAtomic
        [isAtomic, newStr] = evalInEmptyWS(newStr);
    else
        isAtomic = false;
    end
else
    newStr = str;
    isAtomic = true;
end

end

function [isAtomic, newStr] = reduceFullBracket(str)
% Reduces expressions of the form '(expr)' where expr is another expression

% Recurse over 'expr'
[subIsAtomic, subStr] = reduceR(str(2:end-1));
if subIsAtomic
    newStr = subStr;
    isAtomic = true;
else
    newStr = [str(1), subStr, str(end)];
    isAtomic = false;
end
end

function [isAtomic, newStr] = reduceOps(str)
% Reduces expressions of the form '(expr1)OP(expr2)OP...OP(exprN)'
% where expr1..N are sub-expressions

newStr = str;

isAtomic = false; % Init as false since true is a particular case here

% First see how far the chain can simply evaluate

ops = {}; % Ordered list of operators at the current bracketing level. I.e. '(1&0)<(5)==(1|0)~=(1|1|1)>=(a|b)' gives: <,==,~=,>=

close = findMatchingParen(newStr,1);
valid = true;
while close ~= length(newStr)
    ops{end+1} = regexp(newStr(close+1:end),'^[><]=?|[~=]=|&|\|', 'once', 'match');
    assert(strcmp(newStr(close + length(ops{end}) + 1),'(')) % There are brackets on either side of the operator
    
    open = close + length(ops{end}) + 1;
    close = findMatchingParen(newStr,open);
    
    [success, subStr] = evalInEmptyWS(newStr(1:close));
    if valid && success
        ops(end) = [];
        if close == length(newStr)
            newStr = ['(', subStr, ')'];
            close = length(newStr); % This time close is just updated to end the loop since the end of the string has been reached
            isAtomic = true; % Each OP fully evaluated (every other case in this function is false)
        else
            newStr = ['(', subStr, ')', newStr(close+1)]; % Adding brackets here to make the algorithm slightly simpler later on
            close = length(subStr)+2; % This time close just represents the index before the next operator
        end
    else
        valid = 0;
    end
end

% Next, find reduced form of the remaining sub-expressions.
% Start from right and work toward the left to minimize changing indices
close = length(newStr);
open = findMatchingParen(newStr, close);
count = 1;
while open > 1
    subStr = newStr(open:close);
    [subIsAtomic, subStr] = reduceFullBracket(subStr);
    if subIsAtomic
        newStr = [newStr(1:open-1), subStr, newStr(close+1:end)];
    else
        newStr = [newStr(1:open), subStr, newStr(close:end)];
    end
    
    assert(strcmp(newStr(open - length(ops{end+1-count}) - 1),')')) % There are brackets on either side of the operator
    
    close = open - length(ops{end+1-count}) - 1;
    open = findMatchingParen(newStr,close);
    
    count = count + 1;
end
subStr = newStr(open:close);
[subIsAtomic, subStr] = reduceFullBracket(subStr);
if subIsAtomic
    newStr = [newStr(1:open-1), subStr, newStr(close+1:end)];
else
    newStr = [newStr(1:open), subStr, newStr(close:end)];
end

end

function [valid, result] = evalInEmptyWS(expression)
% EVALINEMPTYWS Attempts to evaluate a logical or numerical expression in
%   an empty workspace
%
%   Inputs:
%       expression  A MATLAB expression which is considered invalid if it
%                   does not evaluate to a logical or numerical value.
%
%   Outputs:
%       valid       Logical 1 means the expression evaluated properly.
%       result      Is a char array of the result of the evaluation or the
%                   original expression if it failed.

% If a variable in the workspace is in the expression, then the
% expression is invalid (cannot be evaluated in an empty workspace).
% Else if expression does not evaluate in MATLAB, then the expression is
% invalid (cannot evaluate).
% Else if expression does not evaluate to a logical or numerical value,
% then the expression is invalid (unexpected expression type).
try
    % Variable in expression -> invalid
    % The only variable in the workspace is expression so:
    assert(isempty(findstr(expression,'expression')))
    
    % Expression does not evaluate -> invalid
    result = eval(expression); % Assumes no variables in the workspace appear in it because we've already checked
    
    % Result is not logical or numerical -> invalid
    result = num2str(result);
    
    valid = true;
catch
    result = expression;
    valid = false;
end
end

function match = findMatchingParen(str, index)
% Finds the '(' to open  a ')' indicated by a given index, or
% finds the ')' to close a '(' indicated by a given index
% Assumes str is a character array with balanced parentheses
% Assumes index is the index of a '(' or a ')'

%Code adapted from: https://stackoverflow.com/questions/12752225/how-do-i-find-the-position-of-matching-parentheses-or-braces-in-a-given-piece-of

if strcmp(str(index), '(')
    counter = 1;
    while (counter > 0)
        index = index + 1;
        assert(index <= length(str), 'Closing bracket not found')
        char = str(index);
        if strcmp(char, '(')
            counter = counter + 1;
        elseif strcmp(char, ')')
            counter = counter - 1;
        end
    end
elseif strcmp(str(index), ')')
    counter = 1;
    while (counter > 0)
        index = index - 1;
        assert(index >= 1, 'Opening bracket not found')
        char = str(index);
        if strcmp(char, '(')
            counter = counter - 1;
        elseif strcmp(char, ')')
            counter = counter + 1;
        end
    end
else
    error('Either ''('' or '')'' expected at indicated position, but not found.')
end

match = index;
end

% function [isAtomic, newStr] = handleOps1(str,matchIndex)
% %version 1 - doesn't work for exprOPexprOPexpr if 1st 2 parts don't eval
%         % Identify expr1 and expr2
%         lhs = str(1:matchIndex); % lhs: left hand side
%         opEndIndex = regexp(str(matchIndex+1:end),'^[><]=?|[~=]=|&|\|', 'once', 'end');
%         assert(strcmp(str(matchIndex + opEndIndex + 1),'(')) % There are brackets on either side of the operator
%         rhsMatch = findMatchingParen(str,matchIndex + opEndIndex + 1);
%         rhs = str(matchIndex + opEndIndex + 1:rhsMatch); % rhs: right hand side
%         
%         % Recurse over both cases of 'expr'
%         [subIsAtomicL, subStrL] = reduceR(lhs);
%         [subIsAtomicR, subStrR] = reduceR(rhs);
%         
%         % Replace expressions with simplified ones
%         if subIsAtomicR
%             str = [str(1:matchIndex + opEndIndex), subStrR];
%             % Note, this preserves the validity of matchIndex and opEndIndex
%         end
%         if subIsAtomicL
%             str = [subStrL, str(matchIndex+1:end)];
%             clear matchIndex opEndIndex % These are no longer valid
%         end
%         newStr = str;
%         
%         % Determine if the result is atomic (and reduce if it is)
%         if subIsAtomicL && subIsAtomicR
%             [isAtomic, newStr] = evalInEmptyWS(newStr);
%         else
%             isAtomic = false;
%         end
% end