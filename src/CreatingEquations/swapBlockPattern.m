function swapBlockPattern(sys, extraSupport)
% SWAPBLOCKPATTERN Swap Simulink blocks fitting a certain pattern for a
% simpler pattern. For example, logical AND and OR blocks can be connected
% in such a way that is equivalent to a Switch block thus this connection
% pattern will be recognized and the blocks will be replaced with a Switch.
%
%   Input:
%       sys     Simulink system to make the swaps in.
%       extraSupport    A function which is checked to provide support for
%                       extra block types. Pass @defaultExtraSupport if you
%                       don't know what this is (requires
%                       defaultExtraSupport.m to exist).
%
%   Output:
%       N/A

% % TODO
% %% Swap Constant -> Unary Minus -> X for -1*Constant -> X
% %   i.e. Constant followed by Unary Minus block will be replaced with a
% %       single constant.
% 
% unMinus = find_system(sys, 'BlockType', 'UnaryMinus');
% for i = 1:length(unMinus)
%     ph = getSrcPorts(unMinus{i});
%     assert(length(ph)==1, 'Error: UnaryMinus block expected to have a single source.')
%     parent = get_param(ph, 'Parent');
%     if strcmp(get_param(parent, 'BlockType'), 'Constant')
%         outType = get_param(parent, 'OutDataTypeStr');
%         
% %         TODO
%         if strcmp(outType, 'boolean')
%             val = logical(get_param(parent, 'Value'));
%         else
%             val = get_param(parent, 'Value');
%         end
%     else
%         No swapping
%     end
% end

%% Swap (X AND Y) OR (~X AND Z) for Switch(Y,X,Z)
%   Where X must be a condition of a form compatible with switch blocks.
%   The 'Switch(Y,X,Z)' notation is used roughly to indicate which input
%       each signal acts as to the Switch block.
orBlock = find_system(sys, 'BlockType', 'Logic', 'Operator', 'OR');
for z = 1:length(orBlock)
    try
        get_param(orBlock{z}, 'Name');
        %making sure orBlock{z} still exists
    catch
        continue
    end
    
    ph = getSrcPorts(orBlock{z});
    
    lhsTable = BiMap('double','char');
    
    sysBlocks = find_system(sys, 'SearchDepth', '1');
    sysBlocks = sysBlocks(2:end); % Remove sys
    
    andBlocks = {};
    for i = 1:length(ph)
        parent = get_param(ph(i), 'Parent');
        if strcmp(get_param(parent, 'BlockType'), 'Logic') ...
                && strcmp(get_param(parent, 'Operator'), 'AND')
            andIn = get_param(parent, 'PortHandles');
            andIn = andIn.Inport;
            if length(andIn) <= 2 % TODO: temp condition to remove
                andBlocks{end+1} = parent;
            end
        end
    end
    andBlocks = unique(andBlocks);
    
    % Get equations for the AND blocks
    % subsystem_rule is passed as 'blackbox' because we don't want to
    %   look under subsystems to determine if the inputs satisfy a
    %   switch block.
    equs = getEqusForBlocks(sys, setdiff(sysBlocks, andBlocks), sysBlocks, lhsTable, 'blackbox', extraSupport);
    subEqus = substituteEqus(equs, andBlocks, lhsTable, 'blackbox'); % Substitute equations
    
    andEqus = cell(1,length(andBlocks));
    for i = 1:length(subEqus)
        [lhs, rhs] = getEquationLhsRhs(subEqus{i});
        if strcmp('port', get_param(lhsTable.lookdown(lhs), 'Type')) ...
                && strcmp('inport', get_param(lhsTable.lookdown(lhs), 'PortType')) ...
                && any(strcmp(get_param(lhsTable.lookdown(lhs), 'Parent'), andBlocks))
            
            andi = find(strcmp(get_param(lhsTable.lookdown(lhs), 'Parent'), andBlocks),1);
            andEqus{andi}{end+1} = subEqus{i};
        end
    end
    idx = -1;
    for i = 1:length(andEqus) % for each AND
        for j = 1:length(andEqus{i}) % for each input
            for k = i+1:length(andEqus) 
                idx = findExprComplement(andEqus{i}{j}, andEqus{k});
                if idx ~= -1
                    % Add switch
                    switchBlk = add_block(['built-in/' 'Switch'], getGenBlockName(sys, 'Switch'), 'MAKENAMEUNIQUE','ON', 'Criteria','u2 ~= 0');
                    switchIns = getPorts(switchBlk, 'Inport');
                    
                    % First switch input 
                    equ = andEqus{i}{(j==1)+1};
                    [lhs, ~] = getEquationLhsRhs(equ);
                    andIn1 = lhsTable.lookdown(lhs);
                    switchSrc1 = getSrcPorts(andIn1);
                    delete_line(sys, switchSrc1, andIn1)
                    connectPorts(sys, switchSrc1, switchIns(1));
                    % Second switch input
                    equ = andEqus{i}{j};
                    [lhs, ~] = getEquationLhsRhs(equ);
                    andIn2 = lhsTable.lookdown(lhs);
                    switchSrc2 = getSrcPorts(andIn2);
                    delete_line(sys, switchSrc2, andIn2)
                    connectPorts(sys, switchSrc2, switchIns(2));
                    % Third switch input
                    equ = andEqus{k}{(idx==1)+1};
                    [lhs, ~] = getEquationLhsRhs(equ);
                    andIn3 = lhsTable.lookdown(lhs);
                    switchSrc3 = getSrcPorts(andIn3);
                    delete_line(sys, switchSrc3, andIn3)
                    connectPorts(sys, switchSrc3, switchIns(3));
                    
                    % Delete old logic and extra blocks
                    orDsts = getDsts(orBlock{z}, ...
                            'IncludeImplicit', 'off', 'ExitSubsystems', 'off', ...
                            'EnterSubsystems', 'off', 'Method', 'RecurseUntilTypes', ...
                            'RecurseUntilTypes', {'Inport'}); % Will need this later
                    deleteBlockChain(orBlock{z});
                    
                    % Connect switch outport
                    switchOut = getPorts(switchBlk,'Outport');
                    for m = 1:length(orDsts)
                        connectPorts(sys, switchOut, orDsts(m));
                    end
                    break
                end
            end
            if idx ~= -1
                break
            end
        end
        if idx ~= -1
            break
        end
    end
    
%     if length(ph) == 2
%         parent = get_param(ph, 'Parent');
%         outType = get_param(parent, 'OutDataTypeStr');
%         
%         if strcmp(outType, 'boolean')
%             val = logical(get_param(parent, 'Value'));
%         else
%             val = get_param(parent, 'Value');
%         end
%     else
%         Do nothing. This situation can still be reduced though (TODO).
%     end
end
end

function index = findExprComplement(equ, equs)
    % FINDEXPRCOMPLEMENT Finds the index of the complement of a given
    %   expression (i.e. equation rhs) within a list of equations. If there
    %   is no complement, a value of -1 is returned.
    
    index = -1; % Assume nothing will be found
    
    [~, rhs1] = getEquationLhsRhs(equ);
    
    for i = 1:length(equs)
        [~, rhs2] = getEquationLhsRhs(equs{i});
        negCmp = simplifyExpression(['(' rhs1 ') == ~(' rhs2 ')']);
        if any(strcmp(negCmp, {'true','TRUE'}))
            index = i;
            break
        end
    end
end