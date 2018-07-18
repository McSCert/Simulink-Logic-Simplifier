function harnessSysForVerification(model)
% HARNESSSYSFORVERIFICATION Harness a model to prepare it for verification.
%
%   Inputs:
%       model   Simulink model to prepare for verification.

    % Harnessed system shall have no unconnected ports.
    % Harnessed system shall have no Gotos without a From or vice versa.
    % Likewise for Data Store Reads and Writes
    %
    % This function will connect ports to Inport/Outport blocks and
    % Gotos/Froms/Data Store Reads/Data Store Writes/Data Store Memories
    % will be created as necessary.

    % Find all Froms
    % For each From, find its Goto
    % If a From has no Goto, then create a corresponding local Goto in the
    % same system

    % Find all Gotos
    % For each Goto, find its Froms
    % If a Goto has no From, then create a corresponding From in the same
    % system

    % Find all Data Store Writes
    % For each Write, find its Memory and its Reads
    % If a Write has no Memory, then create a corresponding Memory in the
    % same system
    % If a Write has no Read, then create a corresponding Read in the
    % same system

    % Find all Data Store Reads
    % For each Read, find its Memory and its Writes
    % If a Read has no Memory, then create a corresponding Memory in the
    % same system
    % If a Read has no Write, then create a corresponding Write in the same
    % system

    bTypes = {'From','Goto','DataStoreWrite','DataStoreRead'};
    correspondingTypes = {{'Goto'},{'From'},{'DataStoreRead','DataStoreMemory'},{'DataStoreWrite','DataStoreMemory'}};
    for i = 1:length(bTypes)
        bType = bTypes{i};
        blocks = find_system_BlockType(model, bType);
        for j = 1:length(blocks)
            block = blocks{j};
            for k = 1:length(correspondingTypes{i})
                correspondingType = correspondingTypes{i}{k};
                correspondingBlocks = findCorrespondingBlocks(block, correspondingType);
                if isempty(correspondingBlocks)
                    createCorrespondingBlock(get_param(block, 'Parent'), block, correspondingType);
                end
            end
        end
    end

    % Find all ports at any system depth
    % Find which of those ports are unconnected
    % Delete any lines of ports which are unconnected
    % While there are unconnected ports
    %   For each unconnected port
    %       If the port is a block input, then create an Inport and connect
    %       it to the port.
    %       If the port is a block output, then create an Outport and connect
    %       it to the port.
    %   Find all unconnected ports at any system depth
    [unconnectedInputPorts, unconnectedOutputPorts] = findUnconnectedPorts(model);
    deletePortLines(union(unconnectedInputPorts, unconnectedOutputPorts))
    while ~isempty(union(unconnectedInputPorts, unconnectedOutputPorts))
        for i = 1:length(unconnectedInputPorts)
            port = unconnectedInputPorts(i);
            createAndConnectInOutportBlock(port, 'Inport');
        end
        for i = 1:length(unconnectedOutputPorts)
            port = unconnectedOutputPorts(i);
            createAndConnectInOutportBlock(port, 'Outport');
        end
        [unconnectedInputPorts, unconnectedOutputPorts] = findUnconnectedPorts(model);
    end
end

function [unconnectedInputPorts, unconnectedOutputPorts] = findUnconnectedPorts(sys)

    ports = find_system(sys, ...
        'FindAll','on', ...
        'LookUnderMasks','All', ...
        'IncludeCommented','off', ...
        'Variants','AllVariants', ...
        'Type', 'port');

    unconnectedInputPorts = zeros(1,length(ports));
    unconnectedOutputPorts = zeros(1,length(ports));
    for i = 1:length(ports)
        if isUnconnected(ports(i))
            if strcmp(get_param(ports(i), 'PortType'), 'outport')
                unconnectedOutputPorts(i) = ports(i);
            else
                unconnectedInputPorts(i) = ports(i);
            end
        end
    end
    unconnectedInputPorts = unconnectedInputPorts(find(unconnectedInputPorts));
    unconnectedOutputPorts = unconnectedOutputPorts(find(unconnectedOutputPorts));
end

function deletePortLines(ports)
    for i = 1:length(ports)
        port = ports(i);
        lh = get_param(port, 'Line');
        if lh ~= -1
            delete_line(lh)
        end
    end
end

function bool = isUnconnected(port)
    if strcmp(get_param(port, 'PortType'), 'outport')
        srcdstPortHandle = 'DstPortHandle';
    else
        srcdstPortHandle = 'SrcPortHandle';
    end

    lh = get_param(port, 'Line');
    if lh == -1
        bool = true;
    else
        ph = get_param(lh, srcdstPortHandle);
        if all(ph == -1)
            bool = true;
        else
            bool = false;
        end
    end
end

function blocks = find_system_BlockType(sys, bType)
    blocks = find_system(sys, ...
        'LookUnderMasks','All', ...
        'IncludeCommented','off', ...
        'Variants','AllVariants', ...
        'BlockType', bType);
    blocks = inputToCell(blocks);
end

function correspondingBlocks = findCorrespondingBlocks(block, correspondingType)
    bType = get_param(block, 'BlockType');
    switch correspondingType
        case 'From'
            assert(any(strcmp(bType,{'Goto', 'From', 'GotoTagVisibility'})))
            correspondingBlocks = findFromsInScope(block);
        case 'Goto'
            assert(any(strcmp(bType,{'From', 'GotoTagVisibility'})))
            correspondingBlocks = findGotosInScope(block);
        case 'GotoTagVisibility'
            assert(any(strcmp(bType,{'Goto', 'From'})))
            correspondingBlocks = findVisibilityTag(block);
        case 'DataStoreWrite'
            assert(any(strcmp(bType,{'DataStoreWrite', 'DataStoreRead', 'DataStoreMemory'})))
            correspondingBlocks = findReadsInScope(block);
        case 'DataStoreRead'
            assert(any(strcmp(bType,{'DataStoreWrite', 'DataStoreRead', 'DataStoreMemory'})))
            correspondingBlocks = findWritesInScope(block);
        case 'DataStoreMemory'
            assert(any(strcmp(bType,{'DataStoreWrite', 'DataStoreRead'})))
            correspondingBlocks = findDataStoreMemory(block);
        otherwise
            error('Unexpected block type.')
    end
end

function handle = createCorrespondingBlock(sys, block, correspondingType)
    switch correspondingType
        case {'DataStoreWrite', 'DataStoreRead', 'DataStoreMemory'}
            param_vals = {'DataStoreName', get_param(block, 'DataStoreName')};
        case {'Goto', 'From', 'GotoTagVisibility'}
            param_vals = {'GotoTag', get_param(block, 'GotoTag')};
        otherwise
            param_vals = {};
    end
    handle = add_block(['built-in/' correspondingType], ...
        [sys, '/Verify_Harness_' correspondingType], ...
        'MakeNameUnique', 'On', ...
        param_vals{:});
end

function handle = createAndConnectInOutportBlock(port, bType)
    assert(any(strcmp(bType,{'Inport','Outport'})))
    sys = get_param(get_param(port, 'Parent'), 'Parent');
    handle = createCorrespondingBlock(sys, '', bType);
    ports = getPorts(handle, 'All');
    assert(length(ports) == 1)
    connectPorts(sys, port, ports(1));
end