function [idsChar, idsCell] = getIdentifiers(expr)
    % GETIDENTIFIERS Gets the identifiers/variables in expr
    %
    %   Input:
    %       expr    A character array representing an expression
    %
    %   Output:
    %       idsChar     Character array of the identifiers. Identifiers are
    %                   separated by spaces.
    %       idsCell     Cell array of the identifiers
    %
    
    % Example:
    % expr = 'h 2 _3 TRUE e2l>lo h TRUE2 as 1a1 1_1 FALSE aFALSE 1a|)qwe'
    % getIdentifiers(expr) -> 'h e2l lo TRUE2 as a1 aFALSE a qwe '
    
    % Get all strings of word characters starting with a letter and
    % excluding 'TRUE', 'FALSE', and numbers. In particular, brackets,
    % spaces, operators, 'TRUE', 'FALSE', and numbers will be excluded.
    pat = '([a-zA-Z][\w]*)'; % Pattern for strings of word characters not starting with a digit or underscore
    tok = regexp(expr, pat, 'tokens');
    idsChar = [];
    idsCell = {};
    for i = 1:length(tok)
        if ~any(strcmp(tok{i}{1}, [{'true', 'false', 'TRUE', 'FALSE'}, idsCell])) % If not TRUE or FALSE and not already accounted for
            idsChar = [idsChar, tok{i}{1}, ' '];
            idsCell = [idsCell, tok{i}];
        end
    end
end