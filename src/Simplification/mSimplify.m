function newExpr = mSimplify(expr)
    
    newExpr = expr;
    
    % Swap functions (swap4Symengine and swap4Simulink) don't appear to be
    % needed for the current simplify function being used - however, the
    % function will error in older versions.
    
    % Swap out MATLAB symbols for ones that symengine uses
%     expr = swap4Symengine(expr);

    % MATLAB simplify
    identifiers = getIdentifiers(newExpr);
    eval(['syms ' identifiers]);
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