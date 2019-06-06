function duplicates = RemoveSimulinkDuplicates(blocks, varargin)
% REMOVESIMULINKDUPLICATES For blocks within a common parent system, if a block
%   was copied when its outputs could have been branched, then automatically
%   switch to branching instead.
%   By default the duplicate blocks will be deleted.
%   Only counts things as duplicates if they have at least one input port
%   (e.g. two From blocks where only one is necessary will be untouched).
%   May not handle certain cases with feedback.
%
%   Inputs:
%       blocks      Cell array or vector of Simulink blocks with a common
%                   parent system.
%       varargin	Parameter-Value pairs as detailed below.
%
%   Parameter-Value pairs:
%       Parameter: 'DeleteDuplicateBlocks'
%       Value:  'on' - (Default) Delete blocks and lines that are
%                   duplicates of another block.
%               'off' - Deletes lines connecting to blocks that are
%                   duplicates of another block.
%
%   Output:
%       duplicates  Vector of block handles that were marked as duplicates
%                   to delete or that were deleted because they were a
%                   duplicate.

    % Handle parameter-value pairs
    DeleteDuplicateBlocks = 'on';
    assert(mod(length(varargin),2) == 0, 'Even number of varargin arguments expected.')
    for i = 1:2:length(varargin)
        param = lower(varargin{i});
        value = lower(varargin{i+1});

        switch param
            case lower('DeleteDuplicateBlocks')
                assert(any(strcmpi(value,{'on','off'})), ...
                    ['Unexpected value for ' param ' parameter.'])
                DeleteDuplicateBlocks = value;
            otherwise
                error('Invalid parameter.')
        end
    end

    % TODO - Allow option to remove duplicate constants, froms, and reads

    blocks = inputToNumeric(blocks);

    %%
    duplicates = [];
    while ~isempty(blocks)
        %%
        % Get the current block
        block = blocks(1); % Delete from list at end of loop to ensure this is always different

        %% Remove duplicates of current block
        [deletedBlocks, retryBlocks] = removeDuplicates(block, DeleteDuplicateBlocks);
        % remove deleted blocks from the loop
        tmpBlocks1 = blocks;
        tmpBlocks2 = setdiff(tmpBlocks1,deletedBlocks);
        tmpBlocks3 = union(retryBlocks, tmpBlocks2);

        %%
        % remove the current block so as to not repeat it and to help
        % ensure termination
        blocks = setdiff(tmpBlocks3, block);

        %%
        duplicates = [duplicates, deletedBlocks]; % duplicates is a complete list of the deletedBlocks returned by removeDuplicates

        %%
        % Note: we know this will terminate because on a given iteration
        % the blocks variable either decreased in size or at least one
        % block was deleted (or just had its lines removed) and can never
        % be added back to the blocks variable again.
    end
end

function [deletedBlocks, retryBlocks] = removeDuplicates(block, DeleteDuplicateBlocks)
    %
    % Inputs:
    %   block   A Simulink block handle.
    %
    % Output:
    %   deletedBlocks   Vector of deleted block handles (or blocks that
    %                   would be deleted if DeleteDuplicateBlocks is 'on').

    %%
    % for all input ports
    inputs = getPorts(block, 'In');
    candidates = cell(1,length(inputs)); % will have a vector of candidate duplicate blocks for each input
    for i = 1:length(inputs)
        % get a list of blocks with matching signal that also match the
        % current block type and corresponding parameters
        % handle this conservatively

        candidates{i} = matchingSignalBlocks(inputs(i));
    end

    %%
    % get a list of blocks common to all inputs
    if isempty(candidates)
        % No candidates, so nothing common
        common_blocks = block;
    else
        % Get vector of candidate duplicate blocks common to all inputs
        assert(isa(candidates{1}, 'double'))
        common_blocks = candidates{1};
        for i = 2:length(candidates)
            assert(isa(candidates{i}, 'double'))
            candidates_i = candidates{i};
            common_blocks = intersect(common_blocks, candidates_i);
        end
    end
    assert(any(block == common_blocks), 'Something went wrong.')

    %%
    % for all common blocks other than the current block
    %   replace duplicate with branch
    common_blocks2 = common_blocks(block ~= common_blocks); % common_blocks2 excludes block
    deletedBlocks = [];
    retryBlocks = [];
    for i = 1:length(common_blocks2)
        current_commmon_block = common_blocks2(i);

        %% map outport # to a list of destination ports
        opNum2dstPorts = mapOPortNum2dstPorts(current_commmon_block);

        %% get outports that are sources to the current common block
        src_oports = getSrcs(current_commmon_block, 'IncludeImplicit', 'off', ...
            'ExitSubsystems', 'off', 'EnterSubsystems', 'off', ...
            'Method', 'RecurseUntilTypes', 'RecurseUntilTypes', {'outport'});

        %% delete lines connected to the current common block
        delete_block_lines(current_commmon_block);

        %% delete current common block (depending on DeleteDuplicateBlocks)
        switch DeleteDuplicateBlocks
            case 'on'
                deletedBlocks(end+1) = current_commmon_block;
                delete_block(current_commmon_block);
            case 'off'
                deletedBlocks(end+1) = current_commmon_block; % This block can be considered deleted
            otherwise
                error('Unexpected parameter value.')
        end

        %%
        % for each identified outport that is a source
        % check if the block is unused now that the line was deleted
        switch DeleteDuplicateBlocks
            case 'on'
                deletedBlocks = [deletedBlocks, deleteUnusedSource(src_oports)]; % Must call after deleting lines
            case 'off'
                % Skip
            otherwise
                error('Unexpected parameter value.')
        end

        %%
        % for each mapped outport #
        % connect current outport # of current block to the mapped
        % destination ports
        duplicateSignals(block, opNum2dstPorts);

        %%
        % get blocks with new branches since these may be identified as
        % duplicates now
        for k = 1:length(opNum2dstPorts)
            for j = 1:length(opNum2dstPorts{k})
                retryBlocks(end+1) = get_param(get_param(opNum2dstPorts{k}(j), 'Parent'), 'Handle');
            end
        end
    end
end

function duplicateSignals(block, opNum2dstPorts)
% for each mapped outport #
% connect current outport # of current block to the mapped
% destination ports
%
% Input:
%   block           Simulink block handle or fullname. This should have
%                   the same number of outports as opNum2dstPorts has
%                   cells.
%   opNum2dstPorts  Cell array of vectors of destination input ports.
%                   1st element corresponds with the destinations of
%                   the 1st outport of the given block, 2nd corresponds
%                   to the 2nd, etc.

    block = get_param(block, 'Handle');
    sys = getParentSystem(block);
    oports = getPorts(block, 'Out');
    assert(length(oports) == length(opNum2dstPorts), ...
        ['1st argument is a block that is expected to have the same ', ...
        'number of outports as the number of cells in the 2nd argument.'])

    for i = 1:length(opNum2dstPorts)
        for j = 1:length(opNum2dstPorts{i})
            assert(sys == getParentSystem(opNum2dstPorts{i}(j)), ...
                ['Something went wrong. Probably bad input to ' current_function('-full')])
            connectPorts(sys, oports(i), opNum2dstPorts{i}(j));
        end
    end
end

function deletedBlocks = deleteUnusedSource(src_oports)
    % delete blocks which don't use any of the given ports

    deletedBlocks = [];
    for i = 1:length(src_oports)
        % if current outport is unused,
        %   then assert it is the only outport on its block
        %   and delete that block
        if get_param(src_oports(i),'line') == -1 % port has no line
            block = get_param(get_param(src_oports(i), 'Parent'), 'Handle');
            block_oports = getPorts(block, 'Out');
            assert(length(block_oports) == 1, 'Something went wrong.') % We should only end up calling this function if this would hold
            delete_block(block)
            deletedBlocks(end+1) = block;
        end
    end
end

function opNum2dstPorts = mapOPortNum2dstPorts(block)
% Map all outports of a block to destination input ports by outport #.
%
% Input:
%   block   Simulink block handle or fullname.
%
% Output:
%   opNum2dstPorts  Cell array of vectors of destination input ports.
%                   1st element corresponds with the destinations of
%                   the 1st outport of the given block, 2nd corresponds
%                   to the 2nd, etc.

    block = get_param(block, 'Handle');

    oports = getPorts(block, 'Out');
    opNum2dstPorts = cell(1,length(oports));
    for i = 1:length(oports)
        opNum2dstPorts{i} = getDsts(oports(i), 'IncludeImplicit', 'off', ...
            'ExitSubsystems', 'off', 'EnterSubsystems', 'off', ...
            'Method', 'RecurseUntilTypes', 'RecurseUntilTypes', {'ins'});
    end
end

function matchBlocks = matchingSignalBlocks(iport)
% get a list of blocks with matching signal that also match the
% current block type and corresponding parameters
% handle this conservatively
%
% Input:
%   iport   Handle of an input port.
%
% Output:
%   matchBlocks     Vector of blocks that "match"

    %%
    signalSrc = getSrcs(iport, 'IncludeImplicit', 'off', ...
        'ExitSubsystems', 'off', 'EnterSubsystems', 'off', ...
        'Method', 'RecurseUntilTypes', 'RecurseUntilTypes', {'outport'});
    if isempty(signalSrc)
        % Allow current block as a matchBlock and exit early since line
        % unused
        matchBlocks = get_param(get_param(iport, 'Parent'), 'Handle');
        return % return early if input port is unused
    end
    assert(length(signalSrc) == 1)

    %%
    signal_block = get_param(get_param(signalSrc, 'Parent'), 'Handle');
    sig_bType = get_param(signal_block, 'BlockType');
    switch sig_bType
        case 'From'
            gotoTag = get_param(signal_block, 'gotoTag');

            match_sig_bType = find_system(getParentSystem(signal_block), 'SearchDepth', 1, ...
                'FindAll', 'on', 'Type', 'block', 'BlockType', sig_bType, ...
                'GotoTag', gotoTag);
            assert(any(signal_block == match_sig_bType))

            ins = [];
            for i = 1:length(match_sig_bType)
                ins = [ins, getDsts(match_sig_bType(i), 'IncludeImplicit', 'off', ...
                    'ExitSubsystems', 'off', 'EnterSubsystems', 'off', ...
                    'Method', 'RecurseUntilTypes', 'RecurseUntilTypes', {'ins'})];
            end
        case 'DataStoreRead'
            sampleTime = get_param(signal_block, 'SampleTime');
            dataStoreName = get_param(signal_block, 'DataStoreName');

            match_sig_bType = find_system(getParentSystem(signal_block), 'SearchDepth', 1, ...
                'FindAll', 'on', 'Type', 'block', 'BlockType', sig_bType, ...
                'DataStoreName', dataStoreName, 'SampleTime', sampleTime);
            assert(any(signal_block == match_sig_bType))

            ins = [];
            for i = 1:length(match_sig_bType)
                ins = [ins, getDsts(match_sig_bType(i), 'IncludeImplicit', 'off', ...
                    'ExitSubsystems', 'off', 'EnterSubsystems', 'off', ...
                    'Method', 'RecurseUntilTypes', 'RecurseUntilTypes', {'ins'})];
            end
        case 'Constant'
            value = get_param(signal_block, 'Value');
            outDataTypeStr = get_param(signal_block, 'OutDataTypeStr');
            sampleTime = get_param(signal_block, 'SampleTime');

            match_sig_bType = find_system(getParentSystem(signal_block), 'SearchDepth', 1, ...
                'FindAll', 'on', 'Type', 'block', 'BlockType', sig_bType, ...
                'Value', value, 'OutDataTypeStr', outDataTypeStr, 'SampleTime', sampleTime);
            assert(any(signal_block == match_sig_bType))

            ins = [];
            for i = 1:length(match_sig_bType)
                ins = [ins, getDsts(match_sig_bType(i), 'IncludeImplicit', 'off', ...
                    'ExitSubsystems', 'off', 'EnterSubsystems', 'off', ...
                    'Method', 'RecurseUntilTypes', 'RecurseUntilTypes', {'ins'})];
            end
        otherwise
            ins = getDsts(signalSrc, 'IncludeImplicit', 'off', ...
                'ExitSubsystems', 'off', 'EnterSubsystems', 'off', ...
                'Method', 'RecurseUntilTypes', 'RecurseUntilTypes', {'ins'});
    end

    %%
    block = get_param(get_param(iport, 'Parent'), 'Handle');
    bType = get_param(block, 'BlockType');
    % Check if ins are on a block and port number that 'matches' with iport
    ipNum = get_param(iport, 'PortNumber');
    matchBlocks = [];
    for i = 1:length(ins)
        in = ins(i);
        in_block = get_param(get_param(in, 'Parent'), 'Handle');
        in_bType = get_param(in_block, 'BlockType');
        if strcmp(bType, in_bType)
            AssocMode = 'all'; % In the future this value should be given as input to this function
            if (strcmp(bType, 'Logic') && any(strcmp(AssocMode, {'all', 'logic'}))) ...
                    || (strcmp(bType, 'RelationalOperator') ...
                        && any(strcmp(get_param(in_block, 'Operator'), {'==', '~='})) ...
                        && any(strcmp(AssocMode, {'all', 'logic'}))) ...
                    || (any(strcmp(bType, {'Product', 'Sum'})) && strcmp(AssocMode, 'all'))
                % Associative
                if paramsMatch(block, in_block)
                    matchBlocks(end+1) = in_block;
                end
            elseif false
                % TODO - Consider < and > (some of these cases we want inports ordered opposite)
                if paramsMatch(block, in_block) ...
                        && ipNum ~= get_param(in, 'PortNumber')
                    matchBlocks(end+1) = in_block;
                end
            else
                % Not associative
                if paramsMatch(block, in_block) ...
                        && ipNum == get_param(in, 'PortNumber')
                    matchBlocks(end+1) = in_block;
                end
            end
        end
    end
end

function bool = paramsMatch(block1, block2)
% PARAMSMATCH
%
%   Inputs:
%       block1
%       block2 
%
%   Outputs:
%       bool    True if parameters of the 2 blocks match sufficiently that one can
%               represent the internal logic of both.

    block1 = get_param(block1, 'Handle');
    block2 = get_param(block2, 'Handle');

    bType = get_param(block1, 'BlockType');
    switch bType
        % TODO - Add more cases and make sure the sets of parameters are correct
        case 'Logic'
            str_params = {'BlockType', 'Operator', 'OutDataTypeStr', 'Inputs'};
            bool = strcmp_params(block1, block2, str_params);
        case 'RelationalOperator'
            str_params = {'BlockType', 'Operator', 'OutDataTypeStr', 'RndMeth'};
            bool = strcmp_params(block1, block2, str_params);
        case 'Switch'
            str_params = {'BlockType', 'Criteria', 'Threshold', 'OutDataTypeStr', 'RndMeth'};
            bool = strcmp_params(block1, block2, str_params);
        otherwise
            if block1 == block2
                bool = true;
            else
                bool = false;
            end
    end

    function b = strcmp_params(b1, b2, str_prms)
        for i = 1:length(str_prms)
            if ~strcmp(get_param(b1, str_prms{i}), get_param(b2, str_prms{i}))
                b = false;
                return;
            end
        end
        b = true;
    end
end