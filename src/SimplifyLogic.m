function [newEqu, oldEqu] = SimplifyLogic(blocks, varargin)
    % SIMPLIFYLOGIC A function that takes a set of logic blocks and simplifies
    %   them. Results are saved in a new model in a folder called
    %   'Logic_Simplifier_Results'.
    %
    %   Input:
    %       blocks      Cell array of blocks (indicated by fullname). All blocks
    %                   should be in the same system/subsystem. Input blocks should
    %                   be the outputs of the simplification (i.e. if the only only
    %                   block is an outport, it will simplify the blocks that
    %                   impact it).
    %       varargin{1} Bool indicating whether or not to verify the results.
    %                   Verifying involves creating an additional model within the
    %                   'Logic_Simplifier_Results' folder.
    %
    %   Outputs:
    %       oldEqu      Cell array of equations found for the blocks as
    %                   given.
    %       newEqu      Cell array of equations found for the blocks after
    %                   the simplification process.
    
    % Constants:
    DELETE_UNUSED = getLogicSimplifierConfig('delete_unused', 'off'); % Indicates whether or not to delete blocks which are unused in the final model
    SUBSYSTEM_RULE = getLogicSimplifierConfig('subsystem_rule', 'blackbox'); % Indicates how to address subsystems in the simplification process
    EXTRA_SUPPORT_FUNCTION = getLogicSimplifierConfig('extra_support_function', '');
    GENERATE_MODE = getLogicSimplifierConfig('generate_mode', 'All'); % Indicates mode of generation (generate everything or only selected things)
    BLOCKS_TO_SIMPLIFY = getLogicSimplifierConfig('blocks_to_simplify', 'selected'); % Indicates which set of blocks to simplify
    
    if nargin == 1
        verify = false;
    elseif nargin == 2
        verify = varargin{1};
    else
        error(['Error in ' mfilename ', 1 or 2 input arguments expected.']);
    end
    
    assert(~isempty(blocks), ['Error in ' mfilename ', 1st argument cannot be empty.'])
    
    parent = get_param(blocks{1}, 'parent'); % Get name of system the blocks are in
    origModel = bdroot(blocks{1});
    
    if ~(strcmp(get_param(origModel, 'UnderspecifiedInitializationDetection'), 'Classic'))
        disp(['Warning: The ' mfilename ' function may result in unexpected results if the ''UnderspecifiedInitializationDetection'' model parameter is not set to ''Classic'', please check the results carefully.'])
    end
    
    % Create model for the simplification
    parentName = get_param(parent, 'Name');
    logicSysSuffix = '_newLogic';
    logicSysName = [parentName logicSysSuffix];
    try
        logicSys = new_system_makenameunique(logicSysName);
    catch ME
        if any(strcmp(ME.identifier, ...
                {'Simulink:LoadSave:InvalidBlockDiagramName', ...
                'Simulink:LoadSave:NameTooLong'}))
            % Name invalid so use some default
            logicSysName = ['DefaultModel' logicSysSuffix];
            logicSys = new_system_makenameunique(logicSysName);
        else
            rethrow(ME)
        end
    end
    clear logicSysName % Use logicSys
    open_system(logicSys)
    setModelParams(logicSys, origModel)
    
    % Perform the simplification and generate the simplification in logicSys
    simplificationInput = {logicSys, blocks, 'subsystem_rule', SUBSYSTEM_RULE, ...
        'generate_mode', GENERATE_MODE, 'blocks_to_simplify', BLOCKS_TO_SIMPLIFY};
    if ~strcmp('', EXTRA_SUPPORT_FUNCTION)
        simplificationInput = [simplificationInput, {'extra_support_function'}, {EXTRA_SUPPORT_FUNCTION}];
    end
    [newEqu, oldEqu] = doSimplification(simplificationInput{:});
    
%     % Delete (or don't delete) unused
%     if strcmp(DELETE_UNUSED,'on')
%         % Delete blocks in the top-level system that don't contribute to output
%         topsysBlocks = find_system(logicSys,'FindAll','on','SearchDepth',1,'type','block'); % Doesn't delete blocks within SubSystems
%         deleteIfNoOut(topsysBlocks, true);
%     elseif strcmp(DELETE_UNUSED,'off')
%         % Do nothing
%     else
%         error(['Error in ' mfilename ', DELETE_UNUSED should be ''on'' or ''off''.']);
%     end
%     
%     %Fix the layout
%     automatic_layout(getfullname(logicSys))
    
    %Zoom on new system
    set_param(getfullname(logicSys), 'Zoomfactor', '100');
    
%     if ~strcmp(SUBSYSTEM_RULE, 'blackbox')
%         % Do layout and zoom on SubSystems as well
%         subsystems = find_system(logicSys, 'BlockType', 'SubSystem', 'Mask', 'off');
%         for i = 1:length(subsystems)
%             automatic_layout(getfullname(subsystems(i)));
%             set_param(getfullname(subsystems(i)), 'Zoomfactor', '100');
%         end
%     end
    
    % Save the resulting model - DO NOT MODIFY IT BELOW THIS
    startDir = pwd;
    resultsDir = 'Logic_Simplifier_Results';
    mkdir(resultsDir) % Where we'll save results
    fullResultsDir = [pwd, '/', resultsDir];
    addpath(resultsDir) % So that the saved model(s) is(are) still on the path
    saveGeneratedSystem(logicSys, startDir, resultsDir)
    
    % Handle verification if needed
    if verify
        % Create a copy of the original system (excluding blocks not
        % being generated) and give that a harness.
        % Create a copy of the simplified model and give that a harness.
        
        %% Create copy of the original
        if strcmp(origModel,parent)
            copySys = copyModel(fullResultsDir, origModel, 'orig_with_harness');
        else
            copySys = copySystem(parent, origModel, 'orig_with_harness');
        end
        
        % From the copy, delete blocks that weren't meant to be generated
        % by the simplification
        assert(all(strcmp(get_param(blocks{1}, 'Parent'), get_param(blocks,'Parent'))), ['Error in ' mfilename ', all blocks must be in the same system.'])
        startSys = get_param(blocks{1}, 'Parent');
        topSysBlocks = find_system(startSys, 'SearchDepth', '1');
        topSysBlocks = topSysBlocks(2:end); % Remove startSys
        if strcmpi(GENERATE_MODE, 'simplifiedonly')
            if strcmp(BLOCKS_TO_SIMPLIFY, 'selected')
                unsimplifiedBlocks = setdiff(topSysBlocks,blocks);
                unsimplifiedBlocksHdls = get_param(unsimplifiedBlocks,'Handle');
            elseif strcmp(BLOCKS_TO_SIMPLIFY, 'unselected')
                unsimplifiedBlocks = blocks;
                unsimplifiedBlocksHdls = get_param(unsimplifiedBlocks,'Handle');
            else
                error('Error, invalid blocks_to_simplify')
            end
            for i = 1:length(unsimplifiedBlocksHdls)
                % For all blocks that weren't selected at top-level
                
                % Search for a corresponding block in the copied system
                name = get_param(unsimplifiedBlocks{i}, 'Name');
                copiedBlock = find_system(copySys, 'SearchDepth', 1, 'Type', 'Block', 'Name', name);
                assert(length(copiedBlock) == 1)
                
                % Delete block and its lines
                delete_block_lines(copiedBlock(1))
                delete_block(copiedBlock(1))
            end
        elseif ~strcmpi(GENERATE_MODE, 'All')
            error('Unexpected parameter value.')
        end
        
        % Harness the copy
        harnessSysForVerification(copySys)
        
        % Save harness
        saveGeneratedSystem(copySys, startDir, resultsDir)
        
        %% Create a copy of the simplified system
        vhLogicSys = copyModel(fullResultsDir, logicSys, 'with_harness'); % vh - verification harness
        
        % Harness the copy
        harnessSysForVerification(vhLogicSys)
        
        % Save harness
        saveGeneratedSystem(vhLogicSys, startDir, resultsDir)

        % Call verification function on logicSys and copySys
        verify_model = [get_param(parent, 'Name') '_verify'];
        if ~isvarname(verify_model)
            % Name invalid so use some default
            verify_model = ['DefaultModel' '_verify'];
        end
        makeVerificationModel(verify_model, getfullname(copySys), getfullname(vhLogicSys), [startDir '/' resultsDir]);
    end
end

function copyMdl = copyModel(dir, model, suffix)
    % Copy file
    modelName = getfullname(model);
    origFile = get_param(model, 'FileName');
    
    copyMdl = [modelName '_' suffix];
    
    period_idx = regexp(origFile, '[.]');
    filetype = origFile(period_idx(end):end);
    
    newFile = [dir, '/', copyMdl, filetype];
    
    % Copy file
    % Note an existing file named the same as newFile will be overwritten.
    % This should be fine as the folder should be one made specifically for
    % logic simplifier results.
    % Can use exist(newFile,'file') == 4 to check if the file already
    % exists.
    copyfile(origFile, newFile);
    
    open_system(copyMdl)
    setModelParams(copyMdl, model)
end

function copySys = copySystem(sys, origModel, suffix)
    copySysName = [get_param(sys, 'Name') '_' suffix];
    if ~isvarname(copySysName)
        % Name invalid so use some default
        copySysName = ['DefaultModel' '_' suffix];
    end    
    copySys = new_system_makenameunique(copySysName, 'Model', get_param(sys, 'Handle'));
    
    open_system(copySys)
    setModelParams(copySys, origModel)
end

function copySys = copySystem_old(sys, origModel, suffix)
    % Keeping old function in case unexpected bugs are found in the new one
    % that are addressed here
    copySysName = [get_param(sys, 'Name') '_' suffix];
    try
        copySys = new_system_makenameunique(copySysName, 'Model', get_param(sys, 'Handle'));
    catch ME
        if any(strcmp(ME.identifier, ...
                {'Simulink:LoadSave:InvalidBlockDiagramName', ...
                'Simulink:LoadSave:NameTooLong'}))
            % Name invalid so use some default
            copySysName = ['DefaultModel' '_' suffix];
            copySys = new_system_makenameunique(copySysName, 'Model', get_param(sys, 'Handle'));
        else
            rethrow(ME)
        end
    end
    open_system(copySys)
    setModelParams(copySys, origModel)
end

function automatic_layout(sys)
    try
        AutoLayoutSys(sys);
    catch ME
        warning(['Error occurred in AutoLayout. ' ...
            mfilename ' continuing without automatic layout at ' sys ...
            '. The error message follows:' char(10) getReport(ME)])
    end
end

function setModelParams(newSys, origModel)
    set_param(newSys, 'Solver', get_param(origModel, 'Solver'));
    set_param(newSys, 'SolverType', 'Fixed-step'); % Must be fixed-step for compatibility
    set_param(newSys, 'ProdHWDeviceType', get_param(origModel, 'ProdHWDeviceType'));
    set_param(newSys, 'UnderspecifiedInitializationDetection', get_param(origModel, 'UnderspecifiedInitializationDetection'));
end

function groundAndTerminatePorts(logicSys, SUBSYSTEM_RULE)
    % Ground and terminate unconnected ports
    if ~strcmp(SUBSYSTEM_RULE, 'blackbox')
        ports = find_system(logicSys,'FindAll','on','type','port');
    else
        ports = find_system(logicSys, 'SearchDepth', 1, 'FindAll','on','type','port');
    end
    fulfillPorts(ports); % Ground and terminate
end

function saveGeneratedSystem(sys, startDir, resultsDir)
    try
        cd([startDir '/' resultsDir])
        save_system(sys)
        cd(startDir)
    catch ME
        cd(startDir)
        rethrow(ME)
    end
end