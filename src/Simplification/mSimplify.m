function newExpr = mSimplify(expr)
% MSIMPLIFY Simplify expression using MATLAB's tools.
%
%   Inputs:
%       expr    A string representing an expression. E.g. A symbolic
%               expression in MATLAB will work if given as a string.
%               Cell array of elements of the above format will also
%               work. Format is the same as simplifyExpression.m.

    newExpr = expr;

    % Swap functions (swap4Symengine and swap4Simulink) don't appear to be
    % needed for the current simplify function being used - however, the
    % function will error in older versions.

    % Swap out MATLAB symbols for ones that symengine uses
    % expr = swap4Symengine(expr);

    % MATLAB simplify
    identifiers = getIdentifiers(newExpr);
    if ~isempty(identifiers)
        identifiersArray = strsplit(identifiers, ' ');
    else
        identifiersArray = {};
    end
    for i = 1:length(identifiersArray)
        id = identifiersArray{i};
        if ~isempty(id)
            eval([id ' = sym(id);']);
        end
    end

    newExpr = eval(newExpr); % type will change
    if isa(newExpr, 'double')
        newExpr = num2str(newExpr);
    elseif isa(newExpr, 'logical')
        if newExpr
            newExpr = 'TRUE';
        else
            newExpr = 'FALSE';
        end
    elseif isa(newExpr, 'sym')
        newExpr = simplify(newExpr, 'Steps', 100);
        newExpr = char(newExpr);
    else
        error('Unexpected expression.')
    end

    %Swap symbols back
%     expr = swap4Simulink(expr);
    % newExpression = strrep(newExpression, '=', '=='); % is this needed for newer versions for some reason? % should have to use the same regexprep line that the older version uses at least

    % Swap out special MuPAD operations
    % References:
    % https://www.mathworks.com/help/symbolic/operators-1.html
    % https://www.mathworks.com/help/matlab/matlab_prog/operator-precedence.html
    % https://www.mathworks.com/help/symbolic/mupad_ref/in.html

    % Swap out 'in {...}':
    newExpr = swapIn(newExpr);

    if ~isAtomic(newExpr)
        newExpr = ['(' newExpr ')'];
    end
end