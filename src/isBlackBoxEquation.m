function bool = isBlackBoxEquation(equ)
% Check if an equation is for a blackbox.
% An equation is considered to be for a blackbox if it contains a "?"

bool = ~isempty(strfind(equ,'?')); % Warning suggests contains, but contains doesn't exist in older versions

end