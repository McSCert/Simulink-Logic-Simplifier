function [newExpr, oldExpr] = SimplifyLogic2(blocks)
% SIMPLIFYLOGIC A function that takes a set of logic blocks and simplifies
%   them.
%
%   Input:
%       blocks  Cell array of blocks (indicated by fullname). All blocks
%               should be in the same system/subsystem. Input blocks should
%               be the outputs of the simplification (i.e. if the only only
%               block is an outport, it will simplify the blocks that
%               impact it).
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
REPLACE_EXISTING_MODEL = 'off'; % When creating the model for the simplification, it will replace a file with the same name if 'on' otherwise it will error

parent = get_param(blocks{1}, 'parent'); % Get name of system the blocks are in
origModel = bdroot(blocks{1});

assert(strcmp(get_param(origModel, 'UnderspecifiedInitializationDetection'), 'Classic'), ...
    ['The ' mfilename ' function only currently supports the ''UnderspecifiedInitializationDetection'' model parameter being set to ''Classic''.'])

% Create a new system for the simplification
parentName = get_param(parent, 'Name');
try
    logicSys = new_system([parentName '_newLogic']); % This will error if it's already open
catch ME
    if strcmp(REPLACE_EXISTING_MODEL, 'off')
        rethrow(ME)
    elseif strcmp(REPLACE_EXISTING_MODEL, 'on')
        close_system([parentName '_newLogic'], 0); % Don't save
        logicSys = new_system([parentName '_newLogic']);
    else
        error(['Error in ' mfilename ', REPLACE_EXISTING_MODEL should be ''on'' or ''off''.']);
    end
end
open_system(logicSys);
set_param(logicSys, 'Solver', get_param(origModel, 'Solver'));
set_param(logicSys, 'SolverType', get_param(origModel, 'SolverType'));
set_param(logicSys, 'ProdHWDeviceType', get_param(origModel, 'ProdHWDeviceType'));
set_param(logicSys, 'UnderspecifiedInitializationDetection', get_param(origModel, 'UnderspecifiedInitializationDetection'));

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
end