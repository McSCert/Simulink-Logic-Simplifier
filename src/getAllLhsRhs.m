function [lefts, rights] = getAllLhsRhs(equs)
% GETALLLHSRHS Get left hand sides (LHS's) and right hand sides (RHS's)
%   from a set of equations.
%
%   Input:
%       equs   Cell array of equations of form: LHS = RHS or LHS =? RHS.
%
%   Output:
%       lefts   Cell array of the LHS from each equations. Indexes line up
%               between lefts and equs.
%       rights  Cell array of the RHS from each equations. Indexes line up
%               between rights and equs.

len_equs = length(equs);

% Get all LHSs and RHSs of the equations
lefts = cell(1,len_equs);
rights = cell(1,len_equs);
for i = 1:len_equs
    % Get LHS and RHS of a single equations
    [lefts{i}, rights{i}] = getEquationLhsRhs(equs{i});
end
end