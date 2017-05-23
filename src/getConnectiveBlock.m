function [opType, type] = getConnectiveBlock(connective)
%Gets information for the connective block representing the connective

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
            type = 0;
            opType = 'NOT';
    end
end

