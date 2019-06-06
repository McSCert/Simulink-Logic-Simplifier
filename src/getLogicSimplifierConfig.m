function val = getLogicSimplifierConfig(parameter, default)
% GETLOGICSIMPLIFIERCONFIG Get a parameter from the tool configuration file.
%
%   Inputs:
%       parameter   Configuration parameter to retrieve value for.
%       default     Value to use if parameter is not found.
%
%   Outputs:
%       val         Char configuration value.
%

    val = default;
    filePath = mfilename('fullpath');
    name = mfilename;
    filePath = filePath(1:end-length(name));
    fileName = [filePath 'config.txt'];
    file = fopen(fileName);
    line = fgetl(file);

    paramPattern = ['^' parameter ':\s*(.*)'];

    while ischar(line)
        token = regexp(line, paramPattern, 'tokens');
        if ~isempty(token)
            val = token{1}{1}; % Get value with parameter stripped
            val = num2str(val);
            if isempty(val) % No value specified
                val = default;
            end
            break
        end
        line = fgetl(file);
    end
    fclose(file);
end