function bool = isBlackBoxEquation(equ)
% ISBLACKBOXEQUATION Check if an equation is for a blackbox.
%   An equation is considered to be for a blackbox if it contains a "?".
%
%   Inputs:
%       equ     Char array representing an equation from the Logic Simplifier
%               Tool.
%
%   Outputs:
%       bool    Logical true if equ is for a blackbox.
%

bool = ~isempty(strfind(equ,'?')); % Warning suggests contains, but contains doesn't exist in older versions

end