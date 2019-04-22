function [noncompatible, all_params] = configSolver(sys1, sys2)
% CONFIGSOLVER Check the model configuration parameters that deal with the solver.
%
%   Inputs:
%       sys1    Fullpath of first model to verify.
%       sys2    Fullpath of second model to verify.
%
%   Outputs:
%       params  Names of parameters that differ between the two models.

    sys = {bdroot(sys1), bdroot(sys2)};
    
    %% Parameters
    % Simulation time
    simtime = { ...
        'StartTime', ...
        'StopTime'};
    
    % Solver selection
    solver = { ...
        'Solver', ...
        'SolverType'};
    
    % Solver details
    solverDetails = { ...
        'FixedStep', ...
        'SampleTimeConstraint', ...
        'EnableMultiTasking', ...
        'ConcurrentTasks', ...
        'AutoInsertRateTranBlk', ...
        'PositivePriorityOrder'};
    
    % Advanced parameter
    adv = { ...
        'DecoupledContinuousIntegration', ...
        'MinimalZcImpactIntegration'};
    
	all_params = [simtime, solver, solverDetails, adv];

    %% Check params of both systems
    noncompatible = {};
    for i = 1:length(all_params)
        diff = false;
        try
            p = get_param(sys, all_params{i});

            if ischar(p{1}) && ischar(p{2})
                if ~strcmp(p{1}, p{2})
                    diff = true;
                end
            elseif isnumeric(p{1}) && isnumeric(p{2})
                if p{1} ~= p{2}
                    diff = true;
                end
            end

            if diff
                noncompatible{end+1} = all_params{i};
            end
        catch ME
            if ~strcmpi(ME.identifier, 'Simulink:Commands:GetParamInvalidFirstArgument')
                rethrow(ME)
            end
        end
    end
end