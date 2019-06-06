function [opType, type] = getConnectiveBlock(connective)
% GETCONNECTIVEDBLOCK Get information for the connective block representing the
% given connective.
%
%   Inputs:
%       connective  Char array representing an operator. Supported operators
%                   are: {'&', '|', '~=', '<', '>', '==', '>=', '<=', '~', '-'}.
%                   The operators represent the usual ones in MATLAB.
%
%   Outputs:
%       opType      Char array representing the Operator parameter used in the
%                   corresponding Simulink block to do the equivalent
%                   functionality as the given connective.
%       type        0, 1, or 2 indicating how the connective needs to be
%                   handled.
%

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