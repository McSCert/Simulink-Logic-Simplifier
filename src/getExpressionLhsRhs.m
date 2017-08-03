function [lhs, rhs] = getExpressionLhsRhs(expr)
% GETEXPRESSIONLHSRHS Gets the left-hand-side and right-hand-side of input
%   expression. In this context this will mean the portion to the left and
%   right of the first "=" repectively (whitespace ignored).
%
%   Input:
%       expr    A character array containing the "=" symbol.
%
%   Output:
%       lhs     Left-hand-side of expr.
%       rhs     Right-hand-side of expr.

% Create pattern for lhs:
% Start with any amount of not "=",
% followed by any whitespace, then "=", any whitespace,
% then followed by anything until the end.
% Make token before and after the "=".
patLhsRhs = '^([^=]*[^=\s])\s*=\s*(.*)$';

lhsrhs = regexp(expr, patLhsRhs, 'tokens', 'once');

lhs = lhsrhs{1};
rhs = lhsrhs{2};
end