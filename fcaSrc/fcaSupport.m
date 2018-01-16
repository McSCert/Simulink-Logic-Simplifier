function [isSupported, newExpressions] = fcaSupport(sys, h, hID, blx, table, rule, extraSupport)
% FCASUPPORT Provides additional support for blocks used at FCA.
%   Custom blocks used at FCA may perform basic logical operations which
%   can be represented and simplified by the logic simplifier, these blocks
%   can only be handled on a case by case basis; this function addresses
%   those cases. The purpose of this function is to separate code which
%   relates specifically to FCA out of the main program because the Logic
%   Simplifier is not strictly for use at FCA.
%
%   Inputs:
%       h   Handle of a block or port to make an expression for.
%
%       Other inputs come from and are simply returned to getExprs (so they
%       shouldn't be worried about).
%
%   Outputs:
%       isSupported     Logical true if the block associated with h is
%                       supported through this function else false.
%       newExpressions  Cell array of expressions that define h.
%

isSupported = true; % This will change to false if the block/mask type isn't 
                    % identified in the switch cases.

% Get block
blk = getBlock(h);

isMask = strcmp(get_param(blk, 'Mask'), 'on');

% We only enter both if statements if it was a mask, but the mask type was 
% empty.
if isMask
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
            
            % Get source expressions
            [srcExprs1, srcID1] = getExprs(sys, srcHandles(1), blx, table, rule, extraSupport);
            [srcExprs2, srcID2] = getExprs(sys, srcHandles(2), blx, table, rule, extraSupport);
            [srcExprs3, srcID3] = getExprs(sys, srcHandles(3), blx, table, rule, extraSupport);

            % Record source expressions
            mult_add_available = false; % This can be made true/removed once * and + are accepted
            if mult_add_available
                expr = [hID ' = ' '(((' srcID1 ')*(' srcID2 '))+(~(' srcID1 ')*(' srcID3 ')))']; % This block/port's expression with respect to its 1st source
            else
                expr = [hID ' = ' '(((' srcID1 ')&(' srcID2 '))|(~(' srcID1 ')&(' srcID3 ')))']; % srcID2 and 3 may not be logical so this doesn't work
            end
            newExpressions = [{expr}, srcExprs1, srcExprs2, srcExprs3]; % Expressions involved in this block's expressions
%         case 'Set' 
%             % Set is a pass through so it's expression is essentially just
%             % 'x = y'. This can be modified to be blackbox by simply
%             % commenting out the case.
%             
%             % Get the source port of the blk (i.e. inport)
%             ph = get_param(blk, 'PortHandles');
%             srcHandles = ph.Inport;
%             
%             assert(length(srcHandles) == 1) % Set passes only one input
%             
%             % Get the expression for the source
%             [srcExpressions, srcID] = getExprs(sys, srcHandles, blx, table, rule, extraSupport);
%             
%             expression = [hID ' = ' srcID];
%             newExpressions = [{expression}, srcExpressions];
        otherwise
            isSupported = false;
            newExpressions = {};
    end
end
if ~isMask || strcmp(mType, '')
    bType = get_param(blk, 'BlockType');
    
    switch bType
        case 'Constant'
            value = get_param(blk, 'Value');
            
            valIsNan = isnan(str2double(value));
            valIsTorF = any(strcmp(get_param(blk,'Value'), {'true','false'}));
            
            if valIsNan && any(strcmp(value, {'CbTrue', 'CbFalse'})) % Using FCA notation for true/false
                value = lower(value(3:end)); % E.g. 'CbTrue' -> 'true'
                expression = [hID ' = ' value];
            elseif valIsNan && valIsTorF % Normal constant true/false
                expression = [hID ' = ' value];
            elseif valIsNan % Something unknown, potentially a calibration
                expression = [hID ' =? '];
            else % Normal constant
                expression = [hID ' = ' value];
            end
            
            newExpressions = {expression};
        otherwise
            isSupported = false;
            newExpressions = {};
    end
end

end