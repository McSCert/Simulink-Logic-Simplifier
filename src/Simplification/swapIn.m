function expr = swapIn(expr)
% SWAPIN Swap out 'in {...}' from expression to use '==' and '|' operators:
%   While we find 'in {...}',
%   Pattern is Case 1: 'X in {...} ...' or Case 2: '... ( Case 1 ) ...'
%   Replace Case 1 with: '((X == (...)) | (X == (...)) | ...) ...'
%   For Case 2 replace the contained instance of Case 1 as described above.
%
%   Inputs:
%       expr    Char array representation of an expression returned by one of
%               MATLAB's simplify functions. Other similar representations would
%               also work.
%
%   Outputs:
%       expr    Equivalent expression that does not use the 'in {...}' syntax.
%
    
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