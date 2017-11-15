function depMat = getExprDepMat(exprs)
% GETEXPRDEPMAT Gets a dependency matrix for the LHS's of the expressions
%
%   Input
%       exprs       List of expressions.
%
%   Output
%       depMat      n = length(exprs). nxn array. Rows & columns correspond
%                   with the ordering of exprs. Element (i,j) means LHS_i
%                   depends on LHS_j.

% E.g. If we have the following expressions:
% A = B + C
% B = D * E
% C = 1
% D = D (this may not be realistic, but we want to cover edge cases like this)
% E = B
% 
% depMat = [0,1,1,1,1; % A depends on B,C,D,E
%           0,1,0,1,1; % B depends on B,D,E
%           0,0,0,0,0; % C depends on nothing
%           0,0,0,1,0; % D depends on D
%           0,1,0,1,1]; % E depends on B,D,E

exlen = length(exprs);

exprDeps = getExprDependencies(exprs);

lhs2idx = containers.Map();
for i = 1:exlen
    lhs2idx(exprDeps{i,1}) = i;
end

depMat = zeros(exlen,exlen);
for i = 1:exlen
    for k = 1:length(exprDeps{i,2})
        depMat(i,lhs2idx(exprDeps{i,2}{k})) = 1;
    end
end
end