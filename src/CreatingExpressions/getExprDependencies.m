function exprDeps = getExprDependencies(exprs)
% GETEXPRDEPENDENCIES Gets the dependencies of the LHS of each expression.
%
%   Input
%       exprs       List of expressions.
%
%   Output
%       exprDeps    nx2 cell array which stores an LHS with its 
%                   dependencies. column 1: LHS; 
%                   column 2: cell array listing dependencies

% E.g. If we have the following expressions:
% A = B + C
% B = D * E
% C = 1
% D = D (this may not be realistic, but we want to cover edge cases like this)
% E = B
%
% A directly depends on: B, C; A ultimately depends on: B, C, D, E
% B directly depends on: D, E; B ultimately depends on: D, E, B
% C directly depends on: n/a ; C ultimately depends on: n/a
% D directly depends on: D   ; D ultimately depends on: D
% E directly depends on: B   ; E ultimately depends on: B, D, E

[lefts, rights] = getAllLhsRhs(exprs);

len_exprs = length(exprs);
exprDeps = cell(len_exprs,2);
for i = 1:len_exprs
    exprDeps{i,1} = lefts{i};
    exprDeps{i,2} = {}; % Leave the dependencies empty for now
end

% Find direct dependencies
% (by this we mean dependencies apparent directly from the RHS of an expression)
for i = 1:len_exprs
    idPat = ['(^|[^0-9A-z_])(', lefts{i}, ')([^0-9A-z_]|$)'];
    for j = 1:len_exprs
        if regexp(rights{j}, idPat, 'ONCE') % The jth expression directly depends on the ith expression
            exprDeps{j,2}{end+1} = lefts{i};
        end
    end
end
% Make sure there are no duplicate dependencies
for i = 1:len_exprs
    x = exprDeps{i,2};
    assert(length(unique(x)) == length(x), ['Something went wrong in ' mfilename ' dependencies should not have been listed twice.'])
end

% Fill in indirect dependencies.
exprDeps = getAllFinalDependencies(exprDeps);
end

function finalDeps = getAllFinalDependencies(baseDeps)
% From a base set of direct dependencies, finds indirect dependencies and
%   adds them to the dependency list.
%
% baseDeps and finalDeps are nx2 cell arrays which store an identifier with
% its dependencies.
% column 1: identifier; column 2: cell array listing dependencies
% (dependencies are other identifiers)
%
% E.g.1. If base dependencies are given such that:
%   A depends on B, B depends on C, and C depends on D,
%   then C and D will be added to dependencies of A
%   and D will be added to dependencies of B
% E.g.2. If base dependencies are given such that:
%   A depends on B, and B depends on A,
%   then A will be added to dependencies of A
%   and B will be added to dependencies of B
% The dependencies being added in the examples above are the 'indirect'
% dependencies.

% For each identifier, Ai, add its dependencies to dependencies of other
% identifiers, Bj, that include Ai as a dependency.
for i = 1:length(baseDeps)
    for j = setdiff(1:length(baseDeps),i)
        if ismember(baseDeps{i,1},baseDeps{j,2})
            % Then add baseDeps{i,2} to baseDeps{j,2}
            baseDeps{j,2} = unique([baseDeps{j,2}, baseDeps{i,2}]);
        end
    end
end
finalDeps = baseDeps;
end