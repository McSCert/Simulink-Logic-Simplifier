%% Register custom menu function to beginning of Simulink Editor's context menu
function sl_customization(cm)
	cm.addCustomMenuFcn('Simulink:PreContextMenu', @getMcMasterTool);
end

%% Define custom menu function
function schemaFcns = getMcMasterTool(callbackInfo)

    % Check that at least 1 block is selected
    if ~isempty(gcbs)
        schemaFcns = {@LogicSimplifier};
    else
        schemaFcns = {};
    end
end

%% Define first item
function schema = LogicSimplifier(callbackInfo)
    schema = sl_container_schema;
    schema.label = 'Logic Simplifier';
    schema.childrenFcns = {@getSimplify, @getSimplifyWithVerify, @simplifierConfigMenu};
end

%% Define Simplify Logic Option
function schema = getSimplify(callbackInfo)
    schema = sl_action_schema;
    schema.label = 'Simplify Logic';
    schema.userdata = 'simplifylogic';
    schema.callback = @SimplifyLogicCallback;
end

%% Define Simplify Logic With Verify Option
function schema = getSimplifyWithVerify(callbackInfo)
    schema = sl_action_schema;
    schema.label = 'Simplify Logic and Verify Results';
    schema.userdata = 'simplifylogicandverify';
    schema.callback = @SimplifyLogicWithVerifyCallback;
end

%% Define Open Logic Simplifier Config Option
function schema = simplifierConfigMenu(callbackInfo)
    schema = sl_action_schema;
    schema.label = 'Configuration';
    schema.userdata = 'simplifierConfig';
    schema.callback = @simplifierConfigCallback;
end

function SimplifyLogicCallback(callbackInfo)
    SimplifyLogic(gcbs);
end

function SimplifyLogicWithVerifyCallback(callbackInfo)
    verify = true;
    SimplifyLogic(gcbs, verify);
end

function simplifierConfigCallback(callbackInfo)
% % TODO Open GUI
%     configGUI;

% Open file
    filePath = mfilename('fullpath');
    name = mfilename;
    filePath = filePath(1:end-length(name));
    fileName = [filePath 'config.txt'];
    open(fileName);
end