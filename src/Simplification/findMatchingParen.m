function match = findMatchingParen(str, index)
% FINDMATCHINGPAREN finds the '(' to open  a ')' indicated by a given index, or
%                   finds the ')' to close a '(' indicated by a given index
%
%   Inputs:
%       str     Character array with balanced parentheses.
%       index   Index of a '(' or a ')'.
%
%   Ouputs:
%       match   Index of the matching parenthesis.
%

% Code adapted from: https://stackoverflow.com/questions/12752225/how-do-i-find-the-position-of-matching-parentheses-or-braces-in-a-given-piece-of

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