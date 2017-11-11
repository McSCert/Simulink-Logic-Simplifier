function bool = isBlackBoxExpression(expr)
% Check if an expression is for a blackbox.
% An expression is considered to be for a blackbox if it contains a "?"

bool = ~isempty(strfind(expr,'?')); % Warning suggests contains, but contains doesn't exist in older versions

end