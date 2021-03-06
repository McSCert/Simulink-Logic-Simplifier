function [newexpression] = makeBoolsTorF(expression, tfCase)
% MAKEBOOLSTORF Swaps 1s and 0s in input string with TRUE or FALSE
%   respectively based on whether or not they are intended to be logical or
%   numerical as determined by context within the string.
%
%   Inputs:
%       expression      Character array
%       tfCase          The case to use to write TRUE/FALSE.
%                       'lower' -> true/false
%                       'upper' -> TRUE/FALSE
%
%   Outputs:
%       newexpression   Resulting expression after swapping logical 1s and
%                       0s with TRUE or FALSE respectively.
%
%   Usage:
%       makeBoolsTorF('0', 'upper') -> FALSE
%

    truestr = eval([tfCase '(''true'')']);
    falsestr = eval([tfCase '(''false'')']);

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

    % For reference, this is the expected grammar for the input expression
    % (start with an O):
    %
    % O -> A( '|' A)*
    % A -> R( '&' R)*
    % R -> P( ('[><]=?|[~=]=') P)*
    % P -> '(' O ')' | '~' P | NUMBER | VARIABLE | 'TRUE' | 'FALSE'

    % Test: makeBoolsTorF('~x  & y < 1 | (((1)) == ((0 < z)) ~= 0) & ~1 & 0 < 1 & (1 == FALSE | 0 == y)', 'upper')
    % Expected Output: '~x  & y < 1 | (((TRUE)) == ((0 < z)) ~= FALSE) & ~TRUE & 0 < 1 & (TRUE == FALSE | 0 == y)'

    % Remove whitespace
    temp_expr = regexprep(expression,'\s','');
    %temp_expr = regexprep(expression,'[^\w&_|~><=()]','');
    %^this also removes the minus even though it probably wasn't intended to

    % Remove unary-minus since it has no impact
    temp_expr = strrep(temp_expr,'-','');

    % Remove all brackets that don't surround at least one operator
    temp_expr = removeAtomixBrackets(temp_expr);

    % Identify which 0s and 1s need to change

    temp0sAnd1s = regexp(temp_expr, '[01]'); % Indices of 0s and 1s in the temp expression

    % whichToSwap: Goal is to use this to identify which 0s and 1s in the
    % original expression should be swapped. We'll set this such that if it is:
    % [false false true true], then we want to swap the 3rd and 4th 0/1.
    whichToSwap = zeros(1,length(temp0sAnd1s));
    count = 1;
    for index = temp0sAnd1s
        left = getLeft(temp_expr, index);
        right = getRight(temp_expr, index);
        if priority(right) > priority(left)
            if strcmp(right, 'L') || strcmp(right, '~')
                whichToSwap(count) = 1; count = count + 1;
            elseif strcmp(right, 'E')
                swap = checkRightEquality(temp_expr, index+2, truestr, falsestr);
                whichToSwap(count) = swap; count = count + 1;
            else
                whichToSwap(count) = 0; count = count + 1;
            end
        else
            if strcmp(left, 'L') || strcmp(left, '~')
                whichToSwap(count) = 1; count = count + 1;
            elseif strcmp(left, 'E')
                swap = checkLeftEquality(temp_expr, index-2, truestr, falsestr);
                whichToSwap(count) = swap; count = count + 1;
            else
                whichToSwap(count) = 0; count = count + 1;
            end
        end
    end

    bools01 = regexp(expression, '[01]'); % Indices of 0s and 1s in the original expression
    bools01 = bools01(logical(whichToSwap));


    % Swap 0 with FALSE and 1 with TRUE
    newexpression = expression;
    for i = length(bools01):-1:1
        if strcmp(newexpression(bools01(i)), '0')
            newexpression = swapBool(newexpression,bools01(i),falsestr);
        else % elseif strcmp(expression(bools01(i)), '1')
            newexpression = swapBool(newexpression,bools01(i),truestr);
        end
    end

    % Remove all brackets that don't surround at least one operator
    newexpression = removeAtomixBrackets(newexpression);

    % Replace newexpression with TRUE/FALSE if it's 1/0
    if strcmp(newexpression,'1')
        newexpression = truestr;
    elseif strcmp(newexpression,'0')
        newexpression = falsestr;
    end

    function str = swapBool(str,index,repStr)
        % Swap char at given index in str with repStr
        % (removes a single char, but may replace with multiple)
        str = [str(1:index-1), repStr, str(index+1:end)];
    end
end

function expr = removeAtomixBrackets(expr)
    % REMOVEATOMICBRACKETS removes all brackets that don't surround at least
    % one operator (as this means they surround an atomic value or identifier).

    cont = true;
    while cont
        old = expr;
        expr = regexprep(old,'(\()([^\(~\-><=&|]*)(\))', '$2');
        cont = ~strcmp(expr,old);
    end

end

function p = priority(symbol)
    % Note: This priority is a bit different from the precedence (these
    % priorities are just used to determine how to interpret 0/1)
    %
    % Symbol mapping:
    %   ( ) -> !
    %   [0-9a-zA-Z] -> #
    %   ~ -> ~
    %   > >= < <= -> R
    %   == ~= -> E
    %   & | -> L
    %
    % Since exact priority wasn't needed to determine what to do with
    % 0/1s, this code will treat some as equal where it does not matter
    % (e.g. & and | ).

    switch symbol
        case '#'
            p = 4;
        case '~'
            p = 3;
        case 'R'
            p = 2;
        case 'E'
            p = 2;
        case 'L'
            p = 1;
        case '!'
            p = 0;
    end
end

function left = getLeft(str,i)
if i <= 1 || ~isempty(regexp(str(i-1), '[)(]', 'ONCE'))
    % Null (or effectively null)
    left = '!';
elseif ~isempty(regexp(str(i-1), '[0-9a-zA-Z_]', 'ONCE'))
    % Alphanumeric
    left = '#';
elseif ~isempty(regexp(str(i-1), '[~]', 'ONCE'))
    % Unary not operator
    left = '~';
elseif ~isempty(regexp(str(i-1), '[><]', 'ONCE')) % catch > or <
    % Binary relational operator (not equality)
    left = 'R';
elseif ~isempty(regexp(str(i-1), '[=]', 'ONCE'))
    if ~isempty(regexp(str(i-2), '[><]', 'ONCE')) % catch >= or <=
        % Binary relational operator (not equality)
        left = 'R';
    elseif ~isempty(regexp(str(i-2), '[~=]', 'ONCE')) % catch ~= or ==
        % Binary equality or inequality
        left = 'E';
    end
elseif ~isempty(regexp(str(i-1), '[&|]', 'ONCE'))
    % Binary logical operator
    left = 'L';
end
end

function right = getRight(str,i)
if i >= length(str) || ~isempty(regexp(str(i+1), '[)(]', 'ONCE'))
    % Null (or effectively null)
    right = '!'; % Arbitrary character chosen to indicate null
elseif ~isempty(regexp(str(i+1), '[0-9a-zA-Z_]', 'ONCE'))
    % Alphanumeric
    right = '#';
elseif ~isempty(regexp(str(i+1), '[><]', 'ONCE'))
    % Binary relational operator (not equality)
    right = 'R';
elseif ~isempty(regexp(str(i+1), '[~=]', 'ONCE'))
    % Binary equality or inequality
    right = 'E';
elseif ~isempty(regexp(str(i+1), '[&|]', 'ONCE'))
    % Binary logical operator
    right = 'L';
end
end

function makeBool = checkLeftEquality(expr, index, truestr, falsestr)
% Checks the left side of an equality or inequality (== or ~=) in expr to
% see if the right side should be numeric or logical. Returns 1 if it
% should be logical else 0. Assumes the input is correct (i.e. that index
% is right after an equality and that there is a proper term or expression
% on that side).

expr = expr(1:index-1);

pat = ['(' truestr '|' falsestr '|\))$'];
if ~isempty(regexp(expr, pat, 'ONCE'))
    makeBool = 1;
else
    next1 = regexp(expr, '<=|>=|>|<|~=|==|&|\||~|\(');
    next2 = regexp(expr, '<=|>=|>|<|~=|==|~'); %if previous symbol is one of these, then make it bool
    % ^ could have flipped expr and then used the 'ONCE' option to be more
    % efficient since we only need the last match (didn't for simplicity)

    if isempty(next2)
        makeBool = 0;
    elseif next2(end) == next1(end)
        makeBool = 1;
    else
        makeBool = 0;
    end
end
end

function makeBool = checkRightEquality(expr, index, truestr, falsestr)
% Checks the right side of an equality or inequality (== or ~=) in expr to
% see if the left side should be numeric or logical. Returns 1 if it
% should be logical else 0. Assumes the input is correct (i.e. that index
% is right after an equality and that there is a proper term or expression
% on that side).

expr = expr(index+1:end);

pat = ['^(' truestr '|' falsestr '|~|\()'];
if ~isempty(regexp(expr, pat, 'ONCE'))
    makeBool = 1;
else
    makeBool = 0;
    %%% Old version before realising MATLAB gives equal precedence to == and >:
    %
    %     next1 = regexp(expr, '<=|>=|>|<|~=|==|&|\||\)', 'ONCE');
    %     next2 = regexp(expr, '<=|>=|>|<', 'ONCE'); %if next symbol is one of these, then make it bool
    %
    %     if isempty(next2)
    %         makeBool = 0;
    %     elseif next2(1) == next1(1)
    %         makeBool = 1;
    %     else
    %         makeBool = 0;
    %     end
end
end