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
logicSysName = [parentName '_newLogic'];
try
    logicSys = new_system_makenameunique(logicSysName);
catch ME
    if strcmp(ME.identifier, 'Simulink:LoadSave:InvalidBlockDiagramName')
        % Name invalid so use some default
        logicSysName = ['DefaultModel' '_newLogic'];
        logicSys = new_system_makenameunique(logicSysName);
    else
        rethrow(ME)
    end
end
clear logicSysName % Use logicSys
open_system(logicSys)
set_param(logicSys, 'Solver', get_param(origModel, 'Solver'));
set_param(logicSys, 'SolverType', get_param(origModel, 'SolverType'));
set_param(logicSys, 'ProdHWDeviceType', get_param(origModel, 'ProdHWDeviceType'));
set_param(logicSys, 'UnderspecifiedInitializationDetection', get_param(origModel, 'UnderspecifiedInitializationDetection'));

% Perform the simplification and generate the simplification in logicSys
[newExpr, oldExpr] = doSimplification(logicSys, blocks, 'subsystem_rule', SUBSYSTEM_RULE);


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

% Save the resulting model - DO NOT MODIFY IT BELOW THIS
startDir = pwd;
resultsDir = 'Logic_Simplifier_Results';
mkdir(resultsDir) % Where we'll save results
addpath(resultsDir) % So that the saved model(s) is/are still on the path
try
    cd([startDir '/' resultsDir])
    save_system(logicSys)
    cd(startDir)
catch ME
    cd(startDir)
    rethrow(ME)
end

% Handle verification if needed
if verify
    if strcmp(parent, bdroot(parent)) % parent is the whole model
        % Call verification function on logicSys and parent
        makeVerificationModel([bdroot(parent) '_Verify'], bdroot(parent), getfullname(logicSys), [startDir '/' resultsDir]);
    else
        % Extract subsystem to new model

        copySysName = parentName;
        try
            copySys = new_system_makenameunique(copySysName, 'Model', parent);
            copySysName = getfullname(copySys);
        catch ME
            if strcmp(ME.identifier, 'Simulink:LoadSave:InvalidBlockDiagramName')
                % Name invalid so use some default
                copySysName = 'DefaultModel';
                copySys = new_system_makenameunique(copySysName, 'Model', parent);
                copySysName = getfullname(copySys);
            else
                rethrow(ME)
            end
        end
        open_system(copySys)
        set_param(copySys, 'Solver', get_param(origModel, 'Solver'));
        set_param(copySys, 'SolverType', get_param(origModel, 'SolverType'));
        set_param(copySys, 'ProdHWDeviceType', get_param(origModel, 'ProdHWDeviceType'));
        set_param(copySys, 'UnderspecifiedInitializationDetection', get_param(origModel, 'UnderspecifiedInitializationDetection'));
        
        try
            cd([startDir '/' resultsDir])
            save_system(copySys)
            cd(startDir)
        catch ME
            cd(startDir)
            rethrow(ME)
        end
        
        % Call verification function on logicSys and copySys
        makeVerificationModel([copySysName '_Verify'], copySysName, getfullname(logicSys), [startDir '/' resultsDir]);
    end
end

end