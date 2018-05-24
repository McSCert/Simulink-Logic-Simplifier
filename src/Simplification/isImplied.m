function b = isImplied(aRy,aRx,xRy)
    % true when A aRx x & x xRy y ==> A aRy y
    %
    % be careful to ensure operators are given with the right orientation
    % e.g. make sure that x xRy y holds rather than y xRy x
    
    b = any(strcmp(aRy,implications(aRx,xRy)));
end
function imps = implications(aRx, xRy)
    %
    %
    % aRx in {'<','<=','>','>=','==','~='}
    % xRy in {'<','==','>'}
    %
    % A aRx x & x xRy y ==> A __ y
    % This function finds operators that satisfy the blank above and
    % returns them in a cell array imps.
    
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