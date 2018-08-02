function [isSupported, newEquations] = fcaSupport(sys, h, hID, blx, table, rule, extraSupport)
    % FCASUPPORT Provides additional support for blocks used at FCA.
    %   Custom blocks used at FCA may perform basic logical operations which
    %   can be represented and simplified by the logic simplifier, these blocks
    %   can only be handled on a case by case basis; this function addresses
    %   those cases. The purpose of this function is to separate code which
    %   relates specifically to FCA out of the main program because the Logic
    %   Simplifier is not strictly for use at FCA.
    %
    %   Inputs:
    %       h   Handle of a block or port to make an equation for.
    %
    %       Other inputs come from and are simply returned to getEqus (so they
    %       shouldn't be worried about).
    %
    %   Outputs:
    %       isSupported     Logical true if the block associated with h is
    %                       supported through this function else false.
    %       newEquations    Cell array of equations that define h.
    %
    
    isSupported = true; % This will change to false if the block/mask type isn't
    % identified in the switch cases.
    
    % Get block
    blk = getBlock(h);
    
    isMask = strcmp(get_param(blk, 'Mask'), 'on');
    
    if isMask && ~strcmp(get_param(blk, 'MaskType'), '') % is a mask with nonempty type
        mType = get_param(blk, 'MaskType');
        switch mType
            case 'IfElseif'
                % Note, multiplication and addition are needed to represent this
                % fully, however these are not yet supported by the tool so
                % logical and as well as logical or will be used instead.
                % These operations will satisfy cases with boolean input.
                
                % Get the source ports of the blk (i.e. inports)
                ph = get_param(blk, 'PortHandles');
                srcHandles = ph.Inport;
                
                assert(length(srcHandles) == 3) % IfElseif requires condition, then case, and else case
                
                % Get source equations
                [srcEqus1, srcID1] = getEqus(sys, srcHandles(1), blx, table, rule, extraSupport);
                [srcEqus2, srcID2] = getEqus(sys, srcHandles(2), blx, table, rule, extraSupport);
                [srcEqus3, srcID3] = getEqus(sys, srcHandles(3), blx, table, rule, extraSupport);
                
                % Record source equations
                mult_add_available = false; % This can be made true/removed once * and + are accepted
                if mult_add_available
                    equ = [hID ' = ' '(((' srcID1 ')*(' srcID2 '))+(~(' srcID1 ')*(' srcID3 ')))']; % This block/port's equations with respect to its 1st source
                else
                    equ = [hID ' = ' '(((' srcID1 ')&(' srcID2 '))|(~(' srcID1 ')&(' srcID3 ')))']; % srcID2 and 3 may not be logical so this doesn't work
                end
                newEquations = [{equ}, srcEqus1, srcEqus2, srcEqus3]; % Equations involved in this block's equations
%             case 'Set'
%                 % Set is a pass through so it's equation is essentially just
%                 % 'x = y'. This can be modified to be blackbox by simply
%                 % commenting out the case.
%                 
%                 % Get the source port of the blk (i.e. inport)
%                 ph = get_param(blk, 'PortHandles');
%                 srcHandles = ph.Inport;
%                 
%                 assert(length(srcHandles) == 1) % Set passes only one input
%                 
%                 % Get the equation for the source
%                 [srcEquations, srcID] = getEqus(sys, srcHandles, blx, table, rule, extraSupport);
%                 
%                 equation = [hID ' = ' srcID];
%                 newEquations = [{equation}, srcEquations];
            case 'SwitchUp_Blk'
                % TODO make other symbols work with the simplifier for switch
                % won't work as it requires * and + operators
                
                % Get the source ports of the blk (i.e. inports)
                ph = get_param(blk, 'PortHandles');
                srcHandles = ph.Inport;
                
                assert(length(srcHandles) == 3) % IfElseif requires condition, then case, and else case
                
                % Get source equations
                [srcEqus1, srcID1] = getEqus(sys, srcHandles(1), blx, table, rule, extraSupport);
                [srcEqus2, srcID2] = getEqus(sys, srcHandles(2), blx, table, rule, extraSupport);
                [srcEqus3, srcID3] = getEqus(sys, srcHandles(3), blx, table, rule, extraSupport);
                
                criteria_param = 'u2 ~= 0';
                criteria = strrep(criteria_param, 'u2 ', ['(' srcID2 ')']); % Replace 'u2 '
                
                % Record source equations
                equ = [hID ' = ' '(((' criteria ')&(' srcID1 '))|(~(' criteria ')&(' srcID3 ')))']; % srcID1 and 3 may not be logical so this doesn't work
                newEquations = [{equ}, srcEqus1, srcEqus2, srcEqus3]; % Equations involved in this block's equations
            otherwise
                isSupported = false;
                newEquations = {};
        end
    else
        bType = get_param(blk, 'BlockType');
        
        switch bType
            case 'Constant'
                value = get_param(blk, 'Value');
                valIsNan = isnan(str2double(value));
                valIsTorF = any(strcmp(value, {'true','false'}));
                
                if valIsNan && any(strcmp(value, {'CbTRUE', 'CbFALSE'})) % Using FCA notation for true/false
                    value = lower(value(3:end)); % E.g. 'CbTRUE' -> 'true'
                    equation = [hID ' = ' value];
                elseif valIsNan && valIsTorF % Normal constant true/false
                    equation = [hID ' = ' value];
                elseif valIsNan % Something unknown, potentially a calibration
                    equation = [hID ' =? '];
                else % Normal constant
                    equation = [hID ' = ' value];
                end
                
                newEquations = {equation};
            otherwise
                isSupported = false;
                newEquations = {};
        end
    end
end