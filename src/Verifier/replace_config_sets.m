function replace_config_sets(model1, model2)
% REPLACE_CONFIG_SETS Replace model1 configuration sets with those of model2.

    assert(bdIsLoaded(model1), 'model1 not loaded. Input models must be loaded to access their configuration sets.')
    assert(bdIsLoaded(model2), 'model2 not loaded. Input models must be loaded to access their configuration sets.')

    % Get current config sets for model1.
    actset1 = getActiveConfigSet(model1); % Set object
    sets1 = getConfigSets(model1); % Set names
    
    % Detach non-active configs of model1 (can't detach the active set).
    for i = 1:length(sets1)
        if ~strcmp(sets1{i}, actset1.Name)
            detachConfigSet(model1, sets1{i});
        end
    end
    
    % Get config sets for model2.
    actset2 = getActiveConfigSet(model2); % Config object
    sets2 = getConfigSets(model2); % Config names
    
    % Replace the active config set of model1 with the active config set of
    % model2
    allowRename = true; % Allow config set to be renamed initially
    newset1 = attachConfigSetCopy(model1, actset2, allowRename);
    setActiveConfigSet(model1, newset1.Name)
    detachConfigSet(model1, actset1.Name);
    newset1.Name = actset2.Name; % Rename active config since the copy may have changed it
    
    % Attach the remaining configs from model2 to model1
    allowRename = false; % Do not allow rename when attaching these configs
    for i = 1:length(sets2)
        if ~strcmp(sets2{i}, actset2.Name)
            set = getConfigSet(model2, sets2{i}); % Get config object from config name
            attachConfigSetCopy(model1, set, allowRename);
        end
    end
end