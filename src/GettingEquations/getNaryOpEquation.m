function newEqus = getNaryOpEquation(startSys, h, handleID, blocks, lhsTable, ...
        subsystem_rule, extraSupport, op, varargin)
    % GETNARYOPEQUATION Get the equation for an operator op which can be
    %   used in the following way:
    %       expr op ... op expr
    %   where expr is an arbitrary expression.
    %   Thus the operator is for 2 to N arguments (1 argument will not be
    %   an error, but the op won't be applied).
    %
    % Inputs:
    %   startSys
    %   h
    %   handleID
    %   blocks
    %   lhsTable
    %   subsystem_rule
    %   extraSupport
    %   op          Char array representing a valid operator for the
    %               expression.
    %   varargin{1} Cell array of values to input to the operator (the
    %               values should be given as valid char arrays for an
    %               equation). If there are inputs to the block
    %               corresponding to the given handle h, they are the first
    %               inputs to the operator, after that, elements of
    %               varargin act as inputs to the operator until varargin
    %               is empty.
    %
    % Outputs:
    %   newEqus     Set of new equations used to represent the handle h
    %
    
    % Get the block
    blk = getBlock(h);
    
    % Get the source ports of the blk (i.e. inport, enable, ifaction, etc.)
    ph = get_param(blk, 'PortHandles');
    pfields = fieldnames(ph);
    srcHandles = [];
    for i=setdiff(1:length(pfields), 2) % for all inport field types
        srcHandles = [srcHandles, ph.(pfields{i})];
    end
    
    % Calculate arity of the expression (number of inputs)
    if isempty(varargin)
        extraIns = {};
    else
        extraIns = varargin{1};
    end
    arity = length(srcHandles) + length(extraIns);
    
    % Set default output
    newEqus = {};
    equ = [handleID ' = ('];
    for i = 1:length(srcHandles)
        % Get the equation(s) for the source port
        [srceqs, sID] = getEqus(startSys, srcHandles(i), blocks, lhsTable, subsystem_rule, extraSupport);
        % Add source port equations to the output
        newEqus = [newEqus, srceqs];
        % sID is an input to the N-ary expression
        equ = [equ sID ')'];
        % Add the operator if there will be another input
        if arity > i
            equ = [equ ' ' op ' ('];
        end
    end
    arityRemain = arity - length(srcHandles); % Number of inputs not yet added
    for i = 1:length(extraIns)
        % No source equations, just update equ
        equ = [equ extraIns{i} ')'];
        % Add the operator if there will be another input
        if arityRemain > i
            equ = [equ ' ' op ' ('];
        end
    end
    
    newEqus = [{equ}, newEqus]; % Equations involved in this block's equations
end