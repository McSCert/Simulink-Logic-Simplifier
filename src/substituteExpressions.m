function newExprs = substituteExpressions(exprs, subsIdx)
% SUBSTITUTEEXPRESSIONS Substitute indicated expressions into each other to
%   reduce the number of expressions and so they can be better simplified.
%
%   Inputs:
%       exprs   Cell array of expressions to simplify.
%       subsIdx Array of 1/0s corresponding with whether each expression in
%               exprs with the same indices should be substituted into
%               others.
%
%   Outputs:

%newExprs = exprs;

%% Temp implementation
% Basic replacement seems fine,
% but needs to be done recursively while guaranteeing no loops (which will
% hopefully already be guaranteed by input).

% for i = 1:length(exprs)-1
%     [lhs, rhs] = getExpressionLhsRhs(exprs{i});
%     for j = i+1:length(exprs)
%         newExprs{j} = strrep(exprs{j},lhs, ['(' rhs ')']);
%     end
% end

%% Another temp implementation:
% still doesn't necessarily handle loops in the most desirable way, but it
% seems pretty reasonable

newExprs = exprs;
removeIdx = zeros(1,length(exprs));
%

% subsMap = containers.Map(); % Map of substitutions which have already occured - use lhs as key

for i = length(newExprs):-1:2
    [lhs, rhs] = getExpressionLhsRhs(newExprs{i});
    if subsIdx(i)
        % Substitute expression into earlier expressions
        % Because it only subs into earlier expressions there shouldn't be
        % any problems with redoing substitutions due to loops.
        for j = i-1:-1:1 % This order was only chosen for testing
            idPat = ['([^0-9A-z_])', lhs, '([^0-9A-z_]|$)']; % Note the pattern is not supposed to be found at the start of the string
            if regexp(newExprs{j}, idPat, 'ONCE') % lhs is in rhs of another expression
                % Do substitution
                newExprs{j} = regexprep(newExprs{j}, idPat, ['(' rhs ')']);
                
                % This expression can ultimately be removed from the set of
                % expressions
                removeIdx(i) = 1;
            end
        end
    end
end

%%TODO don't remove expressions for blocks in the original input
% Remove unneeded expressions
for i = length(newExprs):-1:1
    if removeIdx(i) == 1
        newExprs(i) = [];
    end
end

end