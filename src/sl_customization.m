%% Register custom menu function to beginning of Simulink Editor's context menu
function sl_customization(cm)
    cm.addCustomMenuFcn('Simulink:PreContextMenu', @getMcMasterTool);
end

%% Define custom menu function
function schemaFcns = getMcMasterTool(callbackInfo)
    
    schemaFcns = {@LogicSimplifier};
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
    
    % Check that at least 1 block is selected or that the tool is run on
    % unselected blocks.
    BLOCKS_TO_SIMPLIFY = getLogicSimplifierConfig('blocks_to_simplify', 'selected');
    if ~isempty(gcbs) || strcmp(BLOCKS_TO_SIMPLIFY, 'unselected')
        schema.state = 'Enabled';
    else
        schema.state = 'Disabled';
    end
end

%% Define Simplify Logic With Verify Option
function schema = getSimplifyWithVerify(callbackInfo)
    schema = sl_action_schema;
    schema.label = 'Simplify Logic and Verify Results';
    schema.userdata = 'simplifylogicandverify';
    schema.callback = @SimplifyLogicWithVerifyCallback;
    
    % Check that at least 1 block is selected or that the tool is run on
    % unselected blocks.
    BLOCKS_TO_SIMPLIFY = getLogicSimplifierConfig('blocks_to_simplify', 'selected');
    if (~isempty(gcbs) || strcmp(BLOCKS_TO_SIMPLIFY, 'unselected')) && license('test', 'Simulink_Design_Verifier')
        schema.state = 'Enabled';
    else
        schema.state = 'Disabled';
    end
end

%% Define Open Logic Simplifier Config Option
function schema = simplifierConfigMenu(callbackInfo)
    schema = sl_action_schema;
    schema.label = 'Configuration';
    schema.userdata = 'simplifierConfig';
    schema.callback = @simplifierConfigCallback;
end

function SimplifyLogicCallback(callbackInfo)
    try
        verify = false;
        parent = gcs;
        SimplifyLogic(gcbs, verify, parent);
    catch ME
        getReport(ME)
        rethrow(ME)
    end
end

function SimplifyLogicWithVerifyCallback(callbackInfo)
    try
        verify = true;
        SimplifyLogic(gcbs, verify);
    catch ME
        getReport(ME)
        rethrow(ME)
    end
end

function simplifierConfigCallback(callbackInfo)
    % Open file
    filePath = mfilename('fullpath');
    fileName = [fileparts(filePath) '\config.txt'];
    open(fileName);
end