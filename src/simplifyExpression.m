function expr = simplifyExpression(expr)
% SIMPLIFYEXPRESSION Takes an expression extracted from a Simulink system
%   and attempts to simplify it (though what is 'simple' is not not well
%   defined).
%
%   Inputs:
%       expr    An expression extracted from a Simulink system. Should be
%               similar to a logical expression in MATLAB.
%
%   Outputs:
%       expr    A simplified form of the original expression.

% Swap operators for MATLAB equivalents
% TODO: check if the following needs to be done for other symbols
expr = strrep(expr,'<>','~=');

% Evaluate parts that MATLAB can already evaluate
% TODO fix bug that occurs if TRUE is contained within the name of
% another identifier. This situation may be nearly impossible or simply
% unlikely to occur.

% TODO:
% comment these lines while checking for errors as it may hide some
% uncomment for releases
expr = strrep(expr, 'TRUE', '1'); % Replace TRUE/FALSE with 1/0 so that MATLAB can evaluate them
expr = strrep(expr, 'FALSE', '0');
expr = evaluateConstOps(expr);

% Add brackets to remove potential ambiguity
expr = bracketForPrecedence(expr);

% Swap logical 1/0 for TRUE/FALSE (determine if 1/0 is logical from context)
% This is done because symengine will assume 1/0 are numerical
expr = makeBoolsTorF(expr,'upper');

% Swap out MATLAB symbols for ones that symengine uses
expr = swap4Symengine(expr);

% Let MATLAB simplify the expression as a condition
prev = expr; % Can use this to check equivalence between steps
expr = evalin(symengine, ['simplify(' prev ', condition)']);
expr = char(expr); % Convert from symbolic type to string

% Let MATLAB simplify the expression as a logical expression
prev = expr; % Can use this to check equivalence between steps
expr = evalin(symengine, ['simplify(' prev ', logic)']);
expr = char(expr); % Convert from symbolic type to string

%Let MATLAB simplify the expression using a different function
prev = expr; % Can use this to check equivalence between steps
expr = evalin(symengine, ['Simplify(' prev ')']);
expr = char(expr); % Convert from symbolic type to string

%Swap symbols back
expr = swap4Simulink(expr);
% newExpression = strrep(newExpression, '=', '=='); % is this needed for newer versions for some reason?
end

function expr = swap4Symengine(expr)

if ~isLsNewerVer()
    expression = strrep(expression, '~=', '<>'); % This line must go before unary negation because otherwise the block could do
    expression = strrep(expression, '~', ' not ');
    expression = strrep(expression, '==', '=');
    expression = strrep(expression, '&', ' and ');
    expression = strrep(expression, '|', ' or ');
end
end

function expr = swap4Simulink(expr)

if ~isLsNewerVer()
    newExpression = strrep(newExpression, 'or', '|');
    newExpression = strrep(newExpression, 'and', '&');
    newExpression = strrep(newExpression, '=', '==');
    newExpression = strrep(newExpression, 'not', '~');
    newExpression = strrep(newExpression, '<>', '~=');
end
end