function b = isImplied(aRy,aRx,xRy)
% ISIMPLIED Check if (A R1 y) is implied by (A R2 x) & (x R3 y) where R1, R2, R3
%   are the inputs.
%
%   Inputs:
%       aRy     Char array. One of: {'<','<=','>','>=','==','~='}.
%       aRx     Char array. One of: {'<','<=','>','>=','==','~='}.
%       xRy     Char array. One of: {'<','==','>'}.
%
%   Outputs:
%       b       True when A aRx x & x xRy y ==> A aRy y
%
% Notes: Be careful to ensure operators are given with the right orientation.
%   E.g. Make sure that x xRy y holds rather than y xRy x.
%
    
    b = any(strcmp(aRy,implications(aRx,xRy)));
end
function imps = implications(aRx, xRy)
% IMPLICATIONS Find operators, op, satisfying: A aRx x & x xRy y ==> A op y
%
%   Inputs:
%       aRx     Char array. One of: {'<','<=','>','>=','==','~='}.
%       xRy     Char array. One of: {'<','==','>'}.
%
%   Outputs:
%       imps    Cell array of operators.
%
    
    % First find the strongest implication
    switch aRx
        case '<'
            switch xRy
                case {'<', '=='}
                    imp = '<';
                case '>'
                    imp = ''; % No implication to make
                otherwise
                    error(['Unexpected operator: ' op])
            end
        case '<='
            switch xRy
                case '<'
                    imp = '<';
                case '=='
                    imp = '<=';
                case '>'
                    imp = '';
                otherwise
                    error(['Unexpected operator: ' op])
            end
        case '>'
            switch xRy
                case '<'
                    imp = '';
                case {'==', '>'}
                    imp = '>';
                otherwise
                    error(['Unexpected operator: ' op])
            end
        case '>='
            switch xRy
                case '<'
                    imp = '';
                case '=='
                    imp = '>=';
                case '>'
                    imp = '>';
                otherwise
                    error(['Unexpected operator: ' op])
            end
        case '=='
            switch xRy
                case '<'
                    imp = '<';
                case '=='
                    imp = '==';
                case '>'
                    imp = '>';
                otherwise
                    error(['Unexpected operator: ' op])
            end
        case '~='
            switch xRy
                case {'<', '>'}
                    imp = '';
                case '=='
                    imp = '~=';
                otherwise
                    error(['Unexpected operator: ' op])
            end
        otherwise
            error(['Unexpected operator: ' op])
    end
    
    % Find weaker implications
    switch imp
        case '<'
            imps = {'<','<=','~='};
        case '<='
            imps = {'<='};
        case '>'
            imps = {'>','>=','~='};
        case '>='
            imps = {'>='};
        case '=='
            imps = {'==','<=','>='};
        case '~='
            imps = {'~='};
        case ''
            imps = {};
        otherwise
            error(['Unexpected operator: ' imp])
    end
end