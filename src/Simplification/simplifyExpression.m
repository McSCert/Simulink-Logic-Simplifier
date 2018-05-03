function expr = simplifyExpression(expr)
    % SIMPLIFYEXPRESSION Simplifies a given expression.
    %   Notes: 'simple' is ill defined so results may not be strictly
    %           'simpler'.
    %           Expression must be of an appropriate form (TODO: define
    %           this form).
    %
    %   Inputs:
    %       expr    A string representing an expression. E.g. A symbolic
    %               expression in MATLAB will work if given as a string.
    %               Cell array of elements of the above format will also
    %               work.
    %
    %   Outputs:
    %       expr    A simplified form of the original expression. If the
    %               input was a cell array, output will be a cell array of
    %               the simplified forms.
    
    % Examples/Tests:
%     simplifyExpression('~(A <= 1)')
%     exprs = {'3', 'x', ...
%         'true', 'TRUE', 'false', 'FALSE', ...
%         'true == 1', '1 ~= false', 'false ~= false', ...
%         'true == TRUE', 'true == FALSE', ...
%         'A&false', 'true&A', 'A|false', 'true|A', ...
%         'A&~A', 'A|~A', ...
%         'A&A', 'A|A', ...
%         '~~A', ...
%         '(A&~A) ~= (A&false)', ...
%         '0<=~false', '(X<Y) == 1', ...
%         '(X<Y) == TRUE', 'false < 1', ...
%         'A == true', 'A ~= true', 'A == false', 'A ~= false', ...
%         '~A == A', 'A <= A', '~A <= A', 'A < A', ...
%         '(A <= B) & (A > B)', '~(A <= B) & (A > B)', ...
%         '(A < 1) & (A < 2)', '(A < 1) | (A < 2)',...
%         '~(A <= 1)' };
%     newExprs = simplifyExpression(exprs);
%     for i = 1:length(exprs)
%         disp([exprs{i} ' --> ' newExprs{i}])
%     end
    
    if iscell(expr)
        % If input is a cell array, instead of char array then simplify
        % each cell.
        for i = 1:length(expr)
            expr{i} = simplifyExpression(expr{i});
        end
    else
        
        %% Modify the form of expr for the actual simplification
        
        % TODO - get rid of this
        % When does this trigger? should the input ever have this?
        %	Consider different versions of MATLAB (esp. 2011b)
        assert(isempty(strfind(expr, '<>')), 'Assertion triggered for debugging')
        
        % Swap operators for MATLAB equivalents
        expr = strrep(expr,'<>','~=');
        
        % Evaluate parts that MATLAB can already evaluate
        truePat = identifierPattern('true|TRUE'); % final output uses TRUE
        falsePat = identifierPattern('false|FALSE'); % final output uses FALSE
        expr = regexprep(expr, truePat, '1'); % Replace TRUE/FALSE with 1/0 so that MATLAB can evaluate them
        expr = regexprep(expr, falsePat, '0');
        expr = evaluateConstOps(expr);
        
        % Add brackets to remove potential ambiguity
        expr = bracketForPrecedence(expr, true);
        expr = removeSpareBrackets(expr); % Removing brackets for easier debugging
        
        % Swap logical 1/0 for TRUE/FALSE (determine if 1/0 is logical from context)
        % This is done because symengine will assume 1/0 are numerical
        expr = makeBoolsTorF(expr,'lower');
        
        %% Perform the simplification
        expr = lsSimplify(expr);
        
        %% Do final bracketing so that precedence does not need to be considered
        % in other functions
        expr = bracketForPrecedence(expr, true);
        expr = removeSpareBrackets(expr); % Cleaning up excess brackets
    end
end

function newExpr = lsSimplify(expr)
    [~, ids] = getIdentifiers(expr);
    idMap = containers.Map(); % idMap maps from identifiers to expressions they represent
    initMappings = cell(1,length(ids)); initMappings(:) = {''};
    % Add ids to idMap with empty values to indicate that an id doesn't represent anything
    addCells2Map(idMap,ids,initMappings);
    
    % Simplify and when new ids are added to idMap, also add the simplified
    % expression they represent.
    newExpr = lsSimplifyAux(expr, idMap);
    
    % Swap ids in idMap for the expression they represent
    for i = 1:length(idMap.keys)
        key = idMap.keys; key = key{i}; % key = ith key
        value = idMap(key);
        if ~strcmp(value, '')
            newExpr = regexprep(newExpr, ['(?<=(^|\W))' key '(?=(\W|$))'], ['(' value ')']); % match identifier when the character before and after isn't valid in an identifier
        end
    end
end

function newExpr = lsSimplifyAux(expr, idMap)
    
    assert(isempty(regexp(expr,'\s', 'once')))
    
    % Notes of things to account for:
    % (X>Y) == ((X~=Y) & (~(Y>X))) or equivalently ((X>Y)&(Y>X))==False
    % (X<2)&(1>X) -> X<1
    
    %% TODO try reimplementing this by starting with these:
    %subexprs = findNextSubexpressions(expr);
    %[startIdx, endIdx] = findLastOp(expr, 'alt');
    
    if strcmp(expr(1), '(') && findMatchingParen(expr, 1) == length(expr)
        % expr is of form "(subexpr)", so run lsSimplify(subexpr)
        newExpr = lsSimplifyAux(expr(2:end-1), idMap);
    else
        [startIdx, endIdx] = findLastOp(expr);
        if startIdx == 0
            % no simplification to be done
            newExpr = expr;
        else
            op = expr(startIdx:endIdx);
            if strcmp(op,'~')
                % expr is of form "~subexpr"
                % (due to precedence ~ will otherwise not be the last op)
                %   mSimplify(~lsSimplify(subexpr))
                subexpr = lsSimplifyAux(expr(2:end), idMap);
                newExpr = mSimplify(['~(' subexpr ')']);
            else
                % expr is of form "subexpr1 op subexpr2"
                % if op is relational {<,>,<=,>=,==,~=}:
                %   relSimplify(lsSimplify(subexpr1) op lsSimplify(subexpr2))
                % else op is not relational {&,|}:
                %   mSimplify(lsSimplify(subexpr1) op lsSimplify(subexpr2))
                
                rhsIdx = endIdx + 1; % Index where the right-hand side subexpression starts
                lhs = lsSimplifyAux(expr(1:startIdx-1), idMap); % Might be more efficient to do this in the simplification functions in case these don't need to be computed
                rhs = lsSimplifyAux(expr(rhsIdx:end), idMap);
                if any(strcmp(op,{'>','>=','<','<=','==','~='}))
                    newExpr = relSimplify(lhs, op, rhs, idMap);
                else
                    newExpr = mSimplify([lhs op rhs]);
                end
            end
        end
    end
    
    % Replace TRUE/FALSE with true/false for recursive iterations where mSimplify may be used
    upperTruePat = identifierPattern('TRUE');
    upperFalsePat = identifierPattern('FALSE');
    newExpr = regexprep(newExpr, upperTruePat, 'true');
    newExpr = regexprep(newExpr, upperFalsePat, 'false');
    
    % % Let MATLAB simplify the expression as a condition
    % prev = expr; % Can use this to check equivalence between steps
    % expr = evalin(symengine, ['simplify(' prev ', condition)']);
    % expr = char(expr); % Convert from symbolic type to string
    % % Note the above converts 'X == 1 | X == 2' to 'X in {1, 2}'
    
    % Let MATLAB simplify the expression as a logical expression
    %prev = expr; % Can use this to check equivalence between steps
    %expr = evalin(symengine, ['simplify(' prev ', logic)']);
    %expr = char(expr); % Convert from symbolic type to string
    
    % %Let MATLAB simplify the expression using a different function
    % prev = expr; % Can use this to check equivalence between steps
    % expr = evalin(symengine, ['Simplify(' prev ')']);
    % expr = char(expr); % Convert from symbolic type to string
end

function newExpr = relSimplify(lhs, op, rhs, idMap)
    
    % expr = [lhs, op, rhs];
    
    % TODO
    % Try to simply expr better
    % Compare lhs and rhs logically
    % E.g. if lhs = 'X<Y' and rhs = 'Y>X', then we can use a
    % single id to better simplify
    
    eqTrue = @(str) any(strcmp(str,{'true','1'}));
    eqFalse = @(str) any(strcmp(str,{'false','0'}));
    
    if (eqTrue(lhs) && strcmp(op, '==')) ...
            || (eqFalse(lhs) && strcmp(op, '~='))
        newExpr = rhs;
    elseif (eqTrue(rhs) && strcmp(op, '==')) ...
            || (eqFalse(rhs) && strcmp(op, '~='))
        newExpr = lhs;
    elseif (eqTrue(lhs) && strcmp(op, '~=')) ...
            || (eqFalse(lhs) && strcmp(op, '=='))
        newExpr = mSimplify(['~(' rhs ')']);
    elseif (eqTrue(rhs) && strcmp(op, '~=')) ...
            || (eqFalse(rhs) && strcmp(op, '=='))
        newExpr = mSimplify(['~(' lhs ')']);
    elseif (strcmp(lhs, rhs) && strcmp(op, '==')) ...
            newExpr = 'true';
    elseif (strcmp(lhs, rhs) && strcmp(op, '~=')) ...
            newExpr = 'false';
    else
%         [opLeft1, opLeft2] = findLastOp(lhs);
%         [opRight1, opRight2] = findLastOp(rhs);
%         if opLeft1 ~= 0
%             opLeft = lhs(opLeft1:opLeft2);
%             if strcmp(opLeft, '~')
%                 if strcmp(op, '==')
%                     newExpr = % flip the operator
%         elseif opRight1 ~= 0
%
%         else
        
        % if op has not been simplified out, then return with unique id
        % since mSimplify may produce unexpected results for relational
        % operators.
        
        % Get unique identifiers for lhs and rhs
        lhsId = getNewId(idMap.keys);
        idMap(lhsId) = lhs;
        rhsId = getNewId(idMap.keys);
        idMap(rhsId) = rhs;
        
        id = getNewId(idMap.keys);
        idMap(id) = [lhs, op, rhs];
        
        newExpr = id; % id will later be replaced with idMap(id)
    end
end

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
    try
        newExpr = eval(['simplify( ', newExpr, ', ''Steps'', 100 )']);
        newExpr = char(newExpr);
    catch ME
        % We may need to add some conditions to determine whether or not to
        % throw an error. E.g.:
        %   strcmp(ME.identifier, 'MATLAB:UndefinedFunction') && regexp(ME.message, 'Undefined function ''simplify'' for input arguments of type ')
        rethrow(ME);
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

function b = isAtomic(expr)
    % expr is an identifier, a numeric value, or true/TRUE or false/FALSE
    
    % If there is no non-word character, then it is atomic
    b = isempty(regexp(expr,'\W','once'));
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

function expr = swap4Symengine(expr)
    
    if ~isLsNewerVer()
        expr = strrep(expr, '~=', '<>'); % This line must go before the unary negation swap
        expr = strrep(expr, '~', ' not ');
        expr = strrep(expr, '==', '=');
        expr = strrep(expr, '&', ' and ');
        expr = strrep(expr, '|', ' or ');
    end
end

function expr = swap4Simulink(expr)
    
    if ~isLsNewerVer()
        expr = regexprep(expr, '(^|\s) not \s', '~');
        expr = strrep(expr, ' or ', '|'); % Without the spaces 'or' could be part of a variable name
        expr = strrep(expr, ' and ', '&');
        expr = regexprep(expr, '(^|[^<>~=])(=)([^=]|$)', '$1$2$2$3'); % if an = is not in <=, >=, ~=, ==, then replace = with ==
        expr = regexprep(expr, '(^|[^A-Za-z_])not\s', '$1~'); % This replaces not with ~ and makes sure not isn't a part of a variable name
        %     expr = strrep(expr, ' not ', '~');
        expr = strrep(expr, '<>', '~=');
    end
end