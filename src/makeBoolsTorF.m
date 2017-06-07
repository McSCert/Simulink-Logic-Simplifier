function [newexpression] = makeBoolsTorF(expression)
% MAKEBOOLSTORF Swaps 1s and 0s in input string with TRUE or FALSE
%   respectively based on whether or not they are intended to be logical or
%   numerical as determined by context within the string.
%
%   Inputs:
%       expression  Character array
%
%   Outputs:
%       newexpression   Resulting expression after swapping logical 1s and
%                       0s with TRUE or FALSE respectively.

% Test: makeBoolsTorF('~x  & y < 1 | (((1)) == ((0 < z)) ~= 0) & ~1 & 0 < 1 & (1 == FALSE | 0 == y)')
% Expected Output: '~x  & y < 1 | (((TRUE)) == ((0 < z)) ~= FALSE) & ~TRUE & 0 < 1 & (TRUE == FALSE | 0 ~= y)'

% Remove whitespace
temp_expr = regexprep(expression,'[^\w&_|~><=()]','');

% Remove some brackets that are in the way
cont = ~isempty(findstr(temp_expr,'(0)')); % Flag to stop while loop
while cont
    temp_expr = strrep(temp_expr,'(0)','0');
    cont = ~isempty(findstr(temp_expr,'(0)'));
end
cont = ~isempty(findstr(temp_expr,'(1)')); % Flag to stop while loop
while cont
    temp_expr = strrep(temp_expr,'(1)','1');
    cont = ~isempty(findstr(temp_expr,'(1)'));
end

%%
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
            whichToSwap(count) = logical(1); count = count + 1;
        else
            whichToSwap(count) = logical(0); count = count + 1;
        end
    else
        if strcmp(left, 'L') || strcmp(left, '~')
            whichToSwap(count) = logical(1); count = count + 1;
        else
            whichToSwap(count) = logical(0); count = count + 1;
        end
    end
end

% Reference for order of precedence (1 is highest precedence):
%   0. [0-9a-zA-Z]  (number should be associated with an identifier)
%   1. ( )
%   2. ~
%   3. > >= < <=
%   4. == ~=
%   5. &
%   6. |
    function p = priority(symbol)
        % Note: This priority is a bit different from the precedence (these
        % priorities are just used to determine how to interpret 0/1)
        %
        % Symbol mapping:
        %   ( ) -> !
        %   [0-9a-zA-Z] -> #
        %   ~ -> ~
        %   > >= < <= == ~= -> R
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
        elseif ~isempty(regexp(str(i-1), '[0-9a-zA-Z]', 'ONCE'))
            % Alphanumeric
            left = '#';
        elseif ~isempty(regexp(str(i-1), '[~]', 'ONCE'))
            % Unary not operator
            left = '~';
        elseif ~isempty(regexp(str(i-1), '[><=]', 'ONCE'))
            % Binary relational operator
            left = 'R';
        elseif ~isempty(regexp(str(i-1), '[&|]', 'ONCE'))
            % Binary logical operator
            left = 'L';
        end
    end
    function right = getRight(str,i)
        if i >= length(str) || ~isempty(regexp(str(i+1), '[)(]', 'ONCE'))
            % Null (or effectively null)
            right = '!'; % Arbitrary character chosen to indicate null
        elseif ~isempty(regexp(str(i+1), '[0-9a-zA-Z]', 'ONCE'))
            % Alphanumeric
            right = '#';
        elseif ~isempty(regexp(str(i+1), '[><~=]', 'ONCE'))
            % Binary relational operator
            right = 'R';
        elseif ~isempty(regexp(str(i+1), '[&|]', 'ONCE'))
            % Binary logical operator
            right = 'L';
        end
    end

bools01 = regexp(expression, '[01]'); % Indices of 0s and 1s in the original expression
bools01 = bools01(logical(whichToSwap));
%%

% Swap 0 with FALSE and 1 with TRUE
newexpression = expression;
for i = length(bools01):-1:1
    if strcmp(newexpression(bools01(i)), '0')
        newexpression = swapBool(newexpression,bools01(i),'FALSE');
    else % elseif strcmp(expression(bools01(i)), '1')
        newexpression = swapBool(newexpression,bools01(i),'TRUE');
    end
end
    function str = swapBool(str,index,repStr)
        % Swap char at given index in str with repStr
        % (removes a single char, but may replace with multiple)
        str = [str(1:index-1), repStr, str(index+1:end)];
    end
end

