function expr = simplifyExpression(expr)
% SIMPLIFYEXPRESSION Takes an expression extracted from a Simulink system
%   and attempts to simplify it (though what is 'simple' is not too well
%   defined).
%
%   Inputs:
%       expr    An expression extracted from a Simulink system. Should be
%               similar to a logical expression in MATLAB.
%
%   Outputs:
%       expr    A simplified form of the original expression.

%% TODO - test expr == '3' or some other number

% Swap operators for MATLAB equivalents
expr = strrep(expr,'<>','~=');

% Evaluate parts that MATLAB can already evaluate
truePat = identifierPattern('TRUE');
falsePat = identifierPattern('FALSE');
expr = regexprep(expr, truePat, '1'); % Replace TRUE/FALSE with 1/0 so that MATLAB can evaluate them
expr = regexprep(expr, falsePat, '0');
expr = evaluateConstOps(expr);

% Add brackets to remove potential ambiguity
expr = bracketForPrecedence(expr, true);

% Swap logical 1/0 for TRUE/FALSE (determine if 1/0 is logical from context)
% This is done because symengine will assume 1/0 are numerical
expr = makeBoolsTorF(expr,'upper');

% Swap out MATLAB symbols for ones that symengine uses
expr = swap4Symengine(expr);

% Let MATLAB simplify the expression as a condition
prev = expr; % Can use this to check equivalence between steps
expr = evalin(symengine, ['simplify(' prev ', condition)']);
expr = char(expr); % Convert from symbolic type to string
% Note the above converts 'X == 1 | X == 2' to 'X in {1, 2}' <- at the moment
% this causes errors

% Let MATLAB simplify the expression as a logical expression
%prev = expr; % Can use this to check equivalence between steps
%expr = evalin(symengine, ['simplify(' prev ', logic)']);
%expr = char(expr); % Convert from symbolic type to string

%Let MATLAB simplify the expression using a different function
prev = expr; % Can use this to check equivalence between steps
expr = evalin(symengine, ['Simplify(' prev ')']);
expr = char(expr); % Convert from symbolic type to string

%Swap symbols back
expr = swap4Simulink(expr);
% newExpression = strrep(newExpression, '=', '=='); % is this needed for newer versions for some reason?

% Swap out special MuPAD operations
% References:
% https://www.mathworks.com/help/symbolic/operators-1.html
% https://www.mathworks.com/help/matlab/matlab_prog/operator-precedence.html
% https://www.mathworks.com/help/symbolic/mupad_ref/in.html

% Swap out 'in {...}':
expr = swapIn(expr);
end

function expr = swap4Symengine(expr)

if ~isLsNewerVer()
    expr = strrep(expr, '~=', '<>'); % This line must go before unary negation because otherwise the block could do
    expr = strrep(expr, '~', ' not ');
    expr = strrep(expr, '==', '=');
    expr = strrep(expr, '&', ' and ');
    expr = strrep(expr, '|', ' or ');
end
end

function expr = swap4Simulink(expr)

if ~isLsNewerVer()
    expr = strrep(expr, ' or ', '|');
    expr = strrep(expr, ' and ', '&');
    expr = strrep(expr, '=', '==');
    expr = strrep(expr, ' not ', '~');
    expr = strrep(expr, '<>', '~=');
end
end

function expr = swapIn(expr)
% Swap out 'in {...}':
% While we find 'in {...}', 
% Pattern is Case 1: 'X in {...} ...' or Case 2: '... ( Case 1 ) ...'
% Replace Case 1 with: '((X == (...)) | (X == (...)) | ...) ...'

inPat = '(in)[\s]*{([^}]*)}';
while ~isempty(regexp(expr, '(in)[\s]*{([^}]*)}', 'once'))
    te = regexp(expr, inPat, 'tokenExtents', 'once');
    index = findUnclosedBracket(expr(1:te(1,1)-1));
    inSet = strsplit(expr(te(2,1):te(2,2)), ',\s*|,', 'DelimiterType', 'RegularExpression');
    X = expr(index+1:te(1,1)-1);
    
    replaceTxt = ['(((' X ') == (' inSet{1} '))']; % note 1 bracket unclosed
    for j = 2:length(inSet)
        replaceTxt = [replaceTxt ' | ((' X ') == (' inSet{j} '))'];
    end
    replaceTxt = [replaceTxt ')'];
    
    expr = [expr(1:index) replaceTxt expr(te(2,2)+2:end)]; % +2 to go to next char and skip the '}'
end

    function idx = findUnclosedBracket(str)
        % Find the index of the rightmost unclosed open bracket, '('
        % Return idx == 0 if there is no unclosed '('
        count = 0; % Running count of found close brackets, ')'
        for i = length(str):-1:1
            if strcmp(str(i),'(')
                if count == 0
                    idx = i;
                    return
                else
                    count = count - 1;
                end
            elseif strcmp(str(i),')')
                count = count + 1;
            end
        end
        assert(~exist('idx', 'var'), 'Something went wrong.') % This function should end when idx is set
        idx = 0;
    end
end