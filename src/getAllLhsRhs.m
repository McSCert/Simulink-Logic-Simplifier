function [lefts, rights] = getAllLhsRhs(exprs)
% GETALLLHSRHS Get left hand sides (LHS's) and right hand sides (RHS's)
%   from a set of expressions.
%
%   Input:
%       exprs   Cell array of expressions of form: LHS = RHS or LHS =? RHS.
%
%   Output:
%       lefts   Cell array of the LHS from each expression. Indexes line up
%               between lefts and exprs.
%       rights  Cell array of the RHS from each expression. Indexes line up
%               between rights and exprs.

len_exprs = length(exprs);

% Get all LHSs and RHSs of the expressions
lefts = cell(1,len_exprs);
rights = cell(1,len_exprs);
for i = 1:len_exprs
    % Get LHS and RHS of a single expression
    [lefts{i}, rights{i}] = getExpressionLhsRhs(exprs{i});
end
end