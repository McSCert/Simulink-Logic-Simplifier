function [opType, type] = getConnectiveBlock(connective)
% GETCONNECTIVEDBLOCK Get information for the connective block representing the connective.

% type = 2 -> unary
% type = 1 -> relational
% type = 0 -> logical

    switch connective
        case '&'
            type = 0;
            opType = 'AND';
        case '|'
            type = 0;
            opType = 'OR';
        case {'~=', '<', '>', '==', '>=', '<='}
            opType = connective;
            type = 1;
        case '~'
            type = 2;
            opType = 'NOT';
        case '-'
            type = 2;
            opType = 'UnaryMinus';
        otherwise
            if any(strcmp(connective, getConnectiveChars()))
                error(['Error: Support for operator is missing from ' mfilename '.'])
            else
                error('Error: Unsupported operator detected.')
            end
    end
end