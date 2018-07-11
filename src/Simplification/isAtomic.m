function b = isAtomic(expr)
    % expr is an identifier, a numeric value, or true/TRUE or false/FALSE
    
    % If there is no non-word character, then it is atomic
    b = isempty(regexp(expr,'\W','once'));
end