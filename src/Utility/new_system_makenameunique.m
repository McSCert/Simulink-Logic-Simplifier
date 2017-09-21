function h = new_system_makenameunique(baseName, varargin)
% Use varargin to pass additional arguments to the new_system command

name = baseName;
if exist(name, 'file') == 4
    n = 1;
    while exist(strcat(name, num2str(n)), 'file') == 4
        n = n + 1;
    end
    name = strcat(name, num2str(n));
end

h = new_system(name,varargin{:});
end