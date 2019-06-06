function [lhs, rhs] = getEquationLhsRhs(equ)
% GETEQUATIONLHSRHS Gets the left-hand-side and right-hand-side of input
%   equation. In this context this will mean the portion to the left and
%   right of the first "=" (or "=?") repectively (whitespace ignored).
%
%   Input:
%       equ     A character array containing the "=" symbol.
%
%   Output:
%       lhs     Left-hand-side of equ.
%       rhs     Right-hand-side of equ.
%
    
    % Create pattern for lhs:
    % Start with any amount of not "=" ending with not whitespace,
    % followed by any whitespace, then "=", opionally "?",
    % any whitespace, then followed by anything until the end.
    % Make token before and after the "="/"=?".
    patLhsRhs = '^([^=]*[^=\s])\s*=[?]?\s*(.*)$';
    
    lhsrhs = regexp(equ, patLhsRhs, 'tokens', 'once');
    
    lhs = lhsrhs{1};
    rhs = lhsrhs{2};
end