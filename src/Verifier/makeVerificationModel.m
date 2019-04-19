function verificationModel = makeVerificationModel(address, model1, model2, saveDir)
% MAKEVERIFICATIONMODEL Construct a model (.mdl) which can be used to verify
%   equivalence between two models using Simulink Design Verifier.
%
%   Inputs:
%       address     Verification model name.
%       model1      Fullpath of first model to verify.
%       model2      Fullpath of second model to verify.
%       saveDir     Fullpath of directory to save the constructed model in.
%
%   Outputs:
%       verificationModel   Fullpath of location and name of the constructed
%                           model.
%
%   Example:
%       makeVerificationModel('mdl_verify', 'mdl_original', 'mdl_newDesign', pwd);

    % Check number of arguments
     assert(nargin == 4, 'Wrong number of arguments provided.')

    % Check that SDV is installed
    assert(logical(license('test', 'Simulink_Design_Verifier')), ...
        'Simulink Design Verifier must be installed in order to verify results.');

    % Check address is valid model name
    [~, name, ~] = fileparts(address);
    if ~isvarname(name)
        error(['Verification model name ' name ' is not a valid model name.']);
    end

    % Check files exist and are models
    if ~(exist(model1, 'file') == 4)
        error(['Model ' model1 ' cannot be found.']);
    elseif ~(exist(model2, 'file') == 4)
        error(['Model ' model2 ' cannot be found.']);
    end

    %% Load models
    if ~bdIsLoaded(model1)
        load_system(model1);
    end
    if ~bdIsLoaded(model2)
        load_system(model2);
    end

    %% Check that configuration paramter settings are consistent between the models
    % otherwise SDV will complain
    solver = get_param(model1, 'Solver'); % Save model1 info for later
    solverType = get_param(model1, 'SolverType');
    hwDevice = get_param(model1, 'ProdHWDeviceType');
    underspec = get_param(model1, 'UnderspecifiedInitializationDetection');

    assert(strcmp(solver, get_param(model2, 'Solver')), ...
        'The Solver of both models must be the same. Please ensure this in the Model Configuration Parameters.');
    assert(strcmp(solverType, get_param(model2, 'SolverType')), ...
        'The Solver Type of both models must be the same. Please ensure this in the Model Configuration Parameters.');
    assert(strcmp(hwDevice, get_param(model2, 'ProdHWDeviceType')), ...
        'The Production Device Vendor and Type of both models must be the same. Please ensure this in the Model Configuration Parameters.');
    assert(strcmp(underspec, get_param(model2, 'UnderspecifiedInitializationDetection')), ...
        'The Underspecified Initialization Detection of both models must be the same. Please ensure this in the Model Configuration Parameters.');
    assert(~strcmpi(solverType, 'VariableStepAuto') && ~strcmpi(solverType, 'Variable-step'), ...
        'The Solver Type of both models cannot be Variable-step. Please ensure this in the Model Configuration Parameters.');

    %% Create verification model. Append number if it already exists
    verifyModel = address;
    if exist(verifyModel, 'file') == 4
        n = 1;
        while exist(strcat(verifyModel, num2str(n)), 'file') == 4
            n = n + 1;
        end
        verifyModel = strcat(verifyModel, num2str(n));
    end
    new_system(verifyModel);
    open_system(verifyModel);

    % Set new model configuration parameters settings to be consistent
    set_param(verifyModel, 'Solver', solver);
    set_param(verifyModel, 'SolverType', solverType);
    set_param(verifyModel, 'ProdHWDeviceType', hwDevice);
    set_param(verifyModel, 'UnderspecifiedInitializationDetection', underspec);

    %% --- Add blocks ---
    % Note: Not using the 'built-in' names because it results in strange block sizes

    % Add verification subsystem
    verifySubsystemHandle = add_block('sldvlib/Verification Utilities/Verification Subsystem', ...
        [verifyModel '/Verification Subsystem'], 'Position', [170    28   265   112]);
    Simulink.SubSystem.deleteContents(verifySubsystemHandle); % Delete the default blocks/annotations

    verifySubsystem = get_param(verifySubsystemHandle, 'Name');
    verifySubsystem = [verifyModel '/' verifySubsystem];

    % Add model reference blocks inside verification subsystem
    modelRef1Block  = add_block('simulink/Ports & Subsystems/Model', ...
        [verifySubsystem '/Original Model'], 'ModelNameDialog', model1, 'Position', [230    29   410   101]);
    modelRef2Block  = add_block('simulink/Ports & Subsystems/Model', ...
        [verifySubsystem '/Simplified Model'], 'ModelNameDialog', model2, 'Position', [230   151   410   224]);

    % Resize model reference blocks and move second below the first
    modelRef1Pos = get_param(modelRef1Block, 'Position');
    modelRef2Pos = get_param(modelRef2Block, 'Position');

    newModelRefHeight1 = desiredHeightForPorts(modelRef1Block, 30, 30);
    newModelRefHeight2 = desiredHeightForPorts(modelRef2Block, 30, 30);

    newModelRefWidth1 = getBlockTextWidth(modelRef1Block);
    newModelRefWidth2 = getBlockTextWidth(modelRef1Block);

    modelRef1bottom = modelRef1Pos(2)+newModelRefHeight1;
    bufferYBetweenModelRefs = 30;
    set_param(modelRef1Block, 'Position', ...
        [modelRef1Pos(1), modelRef1Pos(2), modelRef1Pos(1)+newModelRefWidth1, modelRef1bottom]);
    set_param(modelRef2Block, 'Position', ...
        [modelRef2Pos(1), modelRef1bottom+bufferYBetweenModelRefs, modelRef2Pos(1)+newModelRefWidth2, modelRef1bottom+bufferYBetweenModelRefs+newModelRefHeight2]);

    % Get model reference port handles
    modelRef1Handles = get_param(modelRef1Block, 'PortHandles');
    modelRef1InHandles = modelRef1Handles.Inport;
    modelRef1OutHandles = modelRef1Handles.Outport;

    modelRef2Handles = get_param(modelRef2Block, 'PortHandles');
    modelRef2InHandles = modelRef2Handles.Inport;
    modelRef2OutHandles = modelRef2Handles.Outport;

    % Add equality blocks and proof blocks
    numOut1 = length(modelRef1OutHandles);
    numOut2 = length(modelRef2OutHandles);
    if numOut1 >= numOut2
        modelRefMostOuts = modelRef1OutHandles;
        modelRefLeastOuts = modelRef2OutHandles;
        numOutports = numOut1;
    else
        modelRefMostOuts = modelRef2OutHandles;
        modelRefLeastOuts = modelRef1OutHandles;
        numOutports = numOut2;
    end

    equalityBlocks = zeros(1, numOutports);
    proofBlocks = equalityBlocks;
    for i = 1:numOutports
        % Add equality blocks
        newEquality = add_block('simulink/Commonly Used Blocks/Relational Operator', ...
            [verifySubsystem '/Equality' num2str(i)], 'Operator', '==', 'ShowName', 'off');
        equalityBlocks(i) = newEquality;
        % Move equality blocks
        moveToPort(newEquality, modelRefMostOuts(1), 0);
        newEqualityIn1 = get_param(newEquality, 'PortHandles');
        newEqualityIn1 = newEqualityIn1.Inport;
        alignPorts(modelRefMostOuts(i), newEqualityIn1(1)); % Vertically align first inport of equality with the port it is connected to

        % Add proof blocks
        newProof = add_block('sldvlib/Objectives and Constraints/Proof Objective', ...
            [verifySubsystem '/Proof Objective' num2str(i)], 'outEnabled', 'off');
        proofBlocks(i) = newProof;
        % Move proof blocks
        equality1Outport = get_param(newEquality, 'PortHandles');
        equality1Outport = equality1Outport.Outport;
        moveToPort(newProof, equality1Outport(1), 0);
    end

    % Add inports to reference models and connect
    % - Get info on number of ports
    numIn1 = length(modelRef1InHandles);
    numIn2 = length(modelRef2InHandles);
    if numIn1 >= numIn2
        modelRefMostIns = modelRef1InHandles;
        modelRefLeastIns = modelRef2InHandles;
        numInports = numIn1;
    else
        modelRefMostIns = modelRef2InHandles;
        modelRefLeastIns = modelRef1InHandles;
        numInports = numIn2;
    end

    % - Get names so we can match them up
    inportNames1 = repmat({''},size(modelRefMostIns));
    inportNames2 = repmat({''},size(modelRefLeastIns));
    for i = 1:length(modelRefMostIns)
        temp =  subport2inoutblock(modelRefMostIns(i));
        n = strfind(temp, '/');
        n = n(end)+1;
        inportNames1{i} = temp(n:end);
    end
    for i = 1:length(modelRefLeastIns)
        temp =  subport2inoutblock(modelRefLeastIns(i));
        n = strfind(temp, '/');
        n = n(end)+1;
        inportNames2{i} = temp(n:end);
    end

    inportsToConnect = modelRefLeastIns; % Will be removing elements during matching, so need a copy
    for i = 1:numInports
        in = add_block('simulink/Ports & Subsystems/In1', [verifySubsystem '/In' num2str(i)]);
        moveToPort(in, modelRefMostIns(i));

        % Connect first model
        %newLine = connectBlocks(verifySubsystem, in, modelRefMostIns); % Connects to first available inport
        outPort = get_param(in, 'PortHandles');
        outPort = outPort.Outport;
        newLine = connectPorts(verifySubsystem, outPort, modelRefMostIns(i), 'autorouting', 'on');

        % Find matching inport in second model reference and connect
        % Note: Simplified models can have fewer inports
        for j = 1:length(inportsToConnect)
            % If port names are the same
            if strcmp(inportNames1{i}, inportNames2{j})
                try
                    % Connect
                    branchToPort(verifySubsystem, newLine, inportsToConnect(j));
                    inportsToConnect(j) = []; % Remove so we don't check again
                    inportNames2(j) = [];
                    break;
                catch
                    % Skip. Might already be connected
                    break;
                end
            end
        end
    end

    % Add inports at root and connect
    verifySubsystemInHandles = get_param(verifySubsystemHandle, 'PortHandles');
    verifySubsystemInHandles = verifySubsystemInHandles.Inport;

    for i = 1:max(length(modelRef1InHandles), length(modelRef2InHandles))
        in = add_block('simulink/Ports & Subsystems/In1', [verifyModel '/In' num2str(i)]);
        moveToPort(in, verifySubsystemInHandles(i));
        connectBlocks(verifyModel, in, verifySubsystemHandle);
    end

    % Connect equality and proof blocks
    % - Get names so we can match them up
    outportNames1 = repmat({''},size(modelRefMostOuts));
    outportNames2 = repmat({''},size(modelRefLeastOuts));
    for i = 1:length(modelRefMostOuts)
        temp =  subport2inoutblock(modelRefMostOuts(i));
        n = strfind(temp, '/');
        n = n(end)+1;
        outportNames1{i} = temp(n:end);
    end
    for i = 1:length(modelRefLeastOuts)
        temp =  subport2inoutblock(modelRefLeastOuts(i));
        n = strfind(temp, '/');
        n = n(end)+1;
        outportNames2{i} = temp(n:end);
    end

    outportsToConnect = modelRefLeastOuts; % Will be removing elements during matching, so need a copy
    for i = 1:length(equalityBlocks)
        inHandlesEq = get_param(equalityBlocks(i), 'PortHandles');
        inHandlesEq = inHandlesEq.Inport;

        % Connect model reference to equality
        connectPorts(verifySubsystem, modelRefMostOuts(i), inHandlesEq(1));

        % Find matching outport in other model reference and connect
        found = false;
        for j = 1:length(outportsToConnect)
            % If port names are the same
            if strcmp(outportNames1{i}, outportNames2{j})
                found = true;
                try
                    % Connect
                    connectPorts(verifySubsystem, outportsToConnect(j), inHandlesEq(2));
                    outportsToConnect(j) = []; % Remove so we don't check again
                    outportNames2(j) = [];
                    break;
                catch
                    % Skip. Might already be connected
                    break;
                end
            end
        end
        if ~found
            % There isn't a port
            ground = add_block('simulink/Sources/Ground', ...
                [verifySubsystem '/Ground' num2str(i)], 'ShowName', 'off');
            moveToPort(ground, inHandlesEq(2), 1, 15);
            connectBlocks(verifySubsystem, ground, equalityBlocks(i));
        end

        % 2) Equality to proof
        connectBlocks(verifySubsystem, equalityBlocks(i), proofBlocks(i));
    end

    % Save the model and go to its location
    startDir = pwd;
    try
        cd(saveDir)
        save_system([verifyModel '.mdl'])
        cd(startDir)
    catch ME
        cd(startDir)
        rethrow(ME)
    end

    % TODO: Fix this because on Windows '\' is used
    verificationModel = [saveDir '/' verifyModel '.mdl'];

    % Set SDV options and auto-run proving
    % Downside of auto-run is that it will still name a replacement model
    % and any errors aren't really be shown
    % More on options here: https://www.mathworks.com/help/pdf_doc/sldv/sldv_ref.pdf
%     opts = sldvoptions;
%     opts.Mode = 'PropertyProving'; % Perform proof analysis
%     opts.SaveHarnessModel = 'off'; % Don't save harness as model file
%     opts.SaveReport = 'on'; % Save the HTML report
%     opts.DisplayReport = 'on'; % Display the report after completing analysis
%     opts.BlockReplacement = 'off'; % Do not replace unsupported blocks
%     opts.OutputDir = 'VerifySimplification/$ModelName$';
%     [status, files] = sldvrun(verifyModel, opts);
end