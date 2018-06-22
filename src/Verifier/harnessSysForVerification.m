function harnessSysForVerification(model)
    % Harness a model to prepare for verification.
    %
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
    
end

function [unconnectedInputPorts, unconnectedOutputPorts] = ...
        findUnconnectedPorts(sys)
    
    ports = find_system(sys, ...
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
    % TODO
end

function bool = isUnconnected(port)
    % TODO
end

function blocks = find_system_BlockType(sys, bType)
    blocks = find_system(sys, ...
        'LookUnderMasks','All', ...
        'IncludeCommented','off', ...
        'Variants','AllVariants', ...
        'BlockType', bType);
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

function createCorrespondingBlock(block, correspondingType)
    % TODO
end