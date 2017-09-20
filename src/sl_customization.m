%% Register custom menu function to beginning of Simulink Editor's context menu
function sl_customization(cm)
	cm.addCustomMenuFcn('Simulink:PreContextMenu', @getMcMasterTool);
end

%% Define custom menu function
function schemaFcns = getMcMasterTool(callbackInfo)

    % Check that only Outports are selected
    if ~isempty(gcbs)
        outports = true;
        for i = 1:length(gcbs)
            if ~strcmp(get_param(gcb, 'BlockType'), 'Outport')
                outports = false;
            end
        end
        if outports
            schemaFcns = {@LogicSimplifier};
        else
            schemaFcns = {};
        end
    else
        schemaFcns = {};
    end
end

%% Define first item
function schema = LogicSimplifier(callbackInfo)
    schema = sl_container_schema;
    schema.label = 'Logic Simplifier';
    schema.childrenFcns = {@getSimplify, @getSimplifyWithVerify};
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

function SimplifyLogicCallback(callbackInfo)
    SimplifyLogic(gcbs);
end

function SimplifyLogicWithVerifyCallback(callbackInfo)
    verify = true;
    SimplifyLogic(gcbs, verify);
end