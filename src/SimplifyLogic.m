function [newExpr, oldExpr] = SimplifyLogic(blocks, varargin)
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
%       oldExpr     Cell array of expressions found for the blocks as
%                   given.
%       newExpr     Cell array of expressions found for the blocks after
%                   the simplification process.

% Constants:
DELETE_UNUSED = getLogicSimplifierConfig('delete_unused', 'off'); % Indicates whether or not to delete blocks which are unused in the final model
SUBSYSTEM_RULE = getLogicSimplifierConfig('subsystem_rule', 'blackbox'); % Indicates how to address subsystems in the simplification process
% Non-config constant:
REPLACE_EXISTING_MODEL = 'on'; % When creating the model for the simplification, it will replace a file with the same name if 'on' otherwise it will error

if nargin == 1
    verify = false;
elseif nargin == 2
    verify = varargin{1};
else
    error(['Error in ' mfilename ', 1 or 2 input arguments expected.']);
end

parent = get_param(blocks{1}, 'parent'); % Get name of system the blocks are in
origModel = bdroot(blocks{1});

%['The ' mfilename ' function only currently supports the ''UnderspecifiedInitializationDetection'' model parameter being set to ''Classic''.']);
if ~(strcmp(get_param(origModel, 'UnderspecifiedInitializationDetection'), 'Classic'))
    disp(['Warning: The ' mfilename ' function may result in unexpected results if the ''UnderspecifiedInitializationDetection'' model parameter is not set to ''Classic'', please check the results carefully.'])
end


% Create a new system for the simplification
parentName = get_param(parent, 'Name');
logicSys = [parentName '_newLogic'];
try
    if strcmp(REPLACE_EXISTING_MODEL, 'off')
        logicSys = new_system(logicSys);
    elseif strcmp(REPLACE_EXISTING_MODEL, 'on')
        saveFlag = 0; % i.e. don't save
        close_system(logicSys, saveFlag);
        logicSys = new_system(logicSys);
    else
        error(['Error in ' mfilename ', REPLACE_EXISTING_MODEL should be ''on'' or ''off''.']);
    end
catch ME
    if ~strcmp(ME.identifier, 'Simulink:LoadSave:InvalidBlockDiagramName')
        % Name invalid so use some default
        logicSys = 'Default_SimplifiedSys';
        if strcmp(REPLACE_EXISTING_MODEL, 'off')
            logicSys = new_system(logicSys);
        elseif strcmp(REPLACE_EXISTING_MODEL, 'on')
            saveFlag = 0; % i.e. don't save
            close_system(logicSys, saveFlag);
            logicSys = new_system(logicSys);
        else
            error(['Error in ' mfilename ', REPLACE_EXISTING_MODEL should be ''on'' or ''off''.']);
        end
    else
        rethrow(ME)
    end
end
open_system(logicSys)
set_param(logicSys, 'Solver', get_param(origModel, 'Solver'));
set_param(logicSys, 'SolverType', get_param(origModel, 'SolverType'));
set_param(logicSys, 'ProdHWDeviceType', get_param(origModel, 'ProdHWDeviceType'));
set_param(logicSys, 'UnderspecifiedInitializationDetection', get_param(origModel, 'UnderspecifiedInitializationDetection'));

% Perform the simplification and generate the simplification in logicSys
[newExpr, oldExpr] = doSimplification(logicSys, blocks);


if strcmp(DELETE_UNUSED,'on')
    % Delete blocks in the top-level system that don't contribute to output
    blocks = find_system(logicSys,'FindAll','on','SearchDepth',1,'type','block'); % Doesn't delete blocks within SubSystems
    deleteIfNoOut(blocks, true);
elseif strcmp(DELETE_UNUSED,'off')
    % Do nothing
else
    error(['Error in ' mfilename ', DELETE_UNUSED should be ''on'' or ''off''.']);
end
% Fulfill unconnected ports with terminators and grounds.
if ~strcmp(SUBSYSTEM_RULE, 'blackbox')
    ports = find_system(logicSys,'FindAll','on','type','port');
else
    ports = find_system(logicSys, 'SearchDepth', 1, 'FindAll','on','type','port');
end
fulfillPorts(ports);


%Fix the layout
AutoLayout(getfullname(logicSys));

%Zoom on new system
set_param(getfullname(logicSys), 'Zoomfactor', '100');

if ~strcmp(SUBSYSTEM_RULE, 'blackbox')
    % Do layout and zoom on SubSystems as well
    subsystems = find_system(logicSys, 'BlockType', 'SubSystem', 'Mask', 'off');
    for i = 1:length(subsystems)
        AutoLayout(getfullname(subsystems(i)));
        set_param(getfullname(subsystems(i)), 'Zoomfactor', '100');
    end
end

% Save the resulting model
startDir = pwd;
resultsDir = 'Logic_Simplifier_Results';
mkdir(resultsDir) % Where we'll save results
cd([startDir '/' resultsDir])
save_system(logicSys)
cd(startDir)

if verify
    if strcmp(parent, bdroot(parent)) % parent is the whole model
        %% TODO - Call verification function on logicSys and parent
    else
        % Extract subsystem to new model

        copySys = parentName;
        try
            if strcmp(REPLACE_EXISTING_MODEL, 'off')
                copySys = new_system(copySys, 'Model', parent);
            elseif strcmp(REPLACE_EXISTING_MODEL, 'on')
                saveFlag = 0; % i.e. don't save
                close_system(copySys, saveFlag);
                copySys = new_system(copySys, 'Model', parent);
            else
                error(['Error in ' mfilename ', REPLACE_EXISTING_MODEL should be ''on'' or ''off''.']);
            end
        catch ME
            if ~strcmp(ME.identifier, 'Simulink:LoadSave:InvalidBlockDiagramName')
                % Name invalid so use some default
                copySys = 'Deafult_CopiedSys';
                if strcmp(REPLACE_EXISTING_MODEL, 'off')
                    copySys = new_system(copySys, 'Model', parent);
                elseif strcmp(REPLACE_EXISTING_MODEL, 'on')
                    saveFlag = 0; % i.e. don't save
                    close_system(copySys, saveFlag);
                    copySys = new_system(copySys, 'Model', parent);
                else
                    error(['Error in ' mfilename ', REPLACE_EXISTING_MODEL should be ''on'' or ''off''.']);
                end
            else
                rethrow(ME)
            end
        end
        open_system(copySys)

        set_param(copySys, 'Solver', get_param(origModel, 'Solver'));
        set_param(copySys, 'SolverType', get_param(origModel, 'SolverType'));
        set_param(copySys, 'ProdHWDeviceType', get_param(origModel, 'ProdHWDeviceType'));
        set_param(copySys, 'UnderspecifiedInitializationDetection', get_param(origModel, 'UnderspecifiedInitializationDetection'));
        
        cd([startDir '/' resultsDir])
        save_system(copySys)
        cd(startDir)

        %% TODO - Call verification function on logicSys and copySys
    end
end

end