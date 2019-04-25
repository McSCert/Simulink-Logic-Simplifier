function [noncompatible, all_params] = checkParamCompatibility(sys1, sys2)
% Check that Model Configuration Parameters are consistent between the models.
    
    load_system(sys1);
    load_system(sys2);
    
    sys1 = bdroot(sys1);
    sys2 = bdroot(sys2);
    
    [params_solver, all_solver] = configSolver(sys1, sys2);
    [params_hw, all_hw] = configHw(sys1, sys2);
    [params_math, all_math] = configMathDataTypes(sys1, sys2);
    [params_diag_solver, all_diag_solver] = configDiagnostics(sys1, sys2);
    [params_diag_datavalid, all_diag_datavalid] = configDiagnostics_DataValidity(sys1, sys2);
    [params_diag_modelref, all_diag_modelref] = configDiagnostics_ModelRef(sys1, sys2);
    [params_modelref, all_modelref] = configModelRef(sys1, sys2);
    
    noncompatible = [params_solver, params_hw, params_math, params_diag_solver, params_diag_datavalid, params_diag_modelref, params_modelref];
    all_params = [all_solver, all_hw, all_math, all_diag_solver, all_diag_datavalid, all_diag_modelref, all_modelref];
    
    if ~isempty(params_solver)
        fprintf('  Solver:\n');
        for i = 1:length(params_solver)
            fprintf('   %s\n', params_solver{i});
        end
    end

    if ~isempty(params_hw)
        fprintf('  Hardware Implementation:\n');
        for i = 1:length(params_hw)  
            fprintf('   %s\n', params_hw{i});
        end
    end

    if ~isempty(params_math)
        fprintf('  Math and Data Types:\n');
        for i = 1:length(params_math)  
            fprintf('   %s\n', params_math{i});
        end
    end

    if ~isempty(params_diag_solver)
        fprintf('  Diagnostics:\n');
        for i = 1:length(params_diag_solver)  
            fprintf('   %s\n', params_diag_solver{i});
        end
    end

    if ~isempty(params_diag_datavalid)
        fprintf('  Diagnostics - Data Validity:\n');
        for i = 1:length(params_diag_datavalid)  
            fprintf('   %s\n', params_diag_datavalid{i});
        end
    end

    if ~isempty(params_diag_modelref)
        fprintf('  Diagnostics - Model Referencing:\n');
        for i = 1:length(params_diag_modelref)  
            fprintf('   %s\n', params_diag_modelref{i});
        end
    end

    if ~isempty(params_modelref)
        fprintf('  Model Referencing:\n');
        for i = 1:length(params_modelref)  
            fprintf('   %s\n', params_modelref{i});
        end
    end
end