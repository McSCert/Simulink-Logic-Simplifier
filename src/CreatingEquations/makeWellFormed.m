function str = makeWellFormed(str)
% MAKEWELLFORMED Edits an expression to be formatted as needed for the Logic
% Simplifier Tool.
%
%   Inputs:
%       str     Original expression.
%
%   Outputs:
%       str     "Well formed" expression.
%

    str = regexprep(str, '([^&|~><=()]+)', '($1)');

    str = regexprep(str, '(\([^&|~><=()]+\)[><=]+\([^&|~><=()]+\))', '($1)');

    str = regexprep(str, '(\([^&|~><=()]+\)~=\([^&|~><=()]+\))', '($1)');

    indicesToRep = regexp(str, '\([^&|~><=()]+\)==\(TRUE\)');
    tokensToRep = regexp(str, '\([^&|~><=()]+\)==\(TRUE\)', 'match');
    for i=1:length(indicesToRep)
        replacementToken = tokensToRep{i};
        replacementToken = replacementToken(1:end-8);
        str = strrep(str, tokensToRep{i}, replacementToken);
    end

    indicesToRep = regexp(str, '\([^&|~><=()]+\)~=\(TRUE\)');
    tokensToRep = regexp(str, '\([^&|~><=()]+\)~=\(TRUE\)', 'match');
    for i=1:length(indicesToRep)
        replacementToken = tokensToRep{i};
        replacementToken = replacementToken(1:end-8);
        str = strrep(str, tokensToRep{i}, ['(~' replacementToken ')']);
    end

    indicesToRep = regexp(str, '\([^&|~><=()]+\)~=\(FALSE\)');
    tokensToRep = regexp(str, '\([^&|~><=()]+\)~=\(FALSE\)', 'match');
    for i=1:length(indicesToRep)
        replacementToken = tokensToRep{i};
        replacementToken = replacementToken(1:end-9);
        str = strrep(str, tokensToRep{i}, replacementToken);
    end

    indicesToRep = regexp(str, '\([^&|~><=()]+\)==\(FALSE\)');
    tokensToRep = regexp(str, '\([^&|~><=()]+\)==\(FALSE\)', 'match');
    for i=1:length(indicesToRep)
        replacementToken = tokensToRep{i};
        replacementToken = replacementToken(1:end-9);
        str = strrep(str, tokensToRep{i}, ['(~' replacementToken ')']);
    end

    % Bracket around unary operators
    numIndices = length(regexp(str, '~[^=]'));
    for i = 1:numIndices
        indices = regexp(str, '~[^=]');
        operator = regexp(str(indices(i):end), '^~', 'match');
        operator = operator{1};

        %right expression
        index = indices(i) + 2;
        count = 1;
        while count > 0
            ch = str(index);
            switch ch
                case '('
                    count = count + 1;
                    index = index + 1;
                case ')'
                    count = count - 1;
                    index = index + 1;
                otherwise
                    index = index + 1;
            end
        end
        rightmost = index - 1;
        rightOperand = str(indices(i)+1:rightmost);

        stringToSubstitute = ['(' operator rightOperand ')'];

        try
            leftRemainder = str(1:indices(i)-1);
        catch
            leftRemainder = '';
        end

        try
            rightRemainder = str(rightmost+1:end);
        catch
            rightRemainder = '';
        end

        str = [leftRemainder stringToSubstitute rightRemainder];
    end

    % Bracket around binary operators
    numIndices = length(regexp(str, '[&|]+'));
    for i = 1:numIndices
        indices = regexp(str, '[&|]+');
        operator = regexp(str(indices(i):end), '^[&|]+', 'match');
        operator = operator{1};

        %left expression
        index = indices(i) - 2;
        count = 1;
        while count > 0
            ch = str(index);
            switch ch
                case '('
                    count = count - 1;
                    index = index - 1;
                case ')'
                    count = count + 1;
                    index = index - 1;
                otherwise
                    index = index - 1;
            end
        end
        leftmost = index+1;
        leftOperand = str(leftmost:indices(i)-1);

        % Right expression
        index = indices(i) + 2;
        count = 1;
        while count > 0
            ch = str(index);
            switch ch
                case '('
                    count = count + 1;
                    index = index + 1;
                case ')'
                    count = count - 1;
                    index = index + 1;
                otherwise
                    index = index + 1;
            end
        end
        rightmost = index - 1;
        rightOperand = str(indices(i)+1:rightmost);

        stringToSubstitute = ['(' leftOperand operator rightOperand ')'];

        try
            leftRemainder = str(1:leftmost-1);
        catch
            leftRemainder = '';
        end

        try
            rightRemainder = str(rightmost+1:end);
        catch
            rightRemainder = '';
        end

        str = [leftRemainder stringToSubstitute rightRemainder];
    end
end