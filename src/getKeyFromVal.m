function key = getKeyFromVal(map, value)
% GETKEYFROMVALUE Gets the key of a given unique value in given
%   containers.Map.
%
%   Inputs:
%       map     is a containers.Map.
%       value   must be a unique value in map and be a character array.
%
%   Output:
%       key is a key in the given map or [] if not found; key == key should
%           return logical 1.

keys = map.keys;
for i = 1:length(keys)
    if strcmp(map(keys{i}), value)
        key = keys{i};
        break
    end
end

assert(strcmp(map(key), value), 'Something went wrong, the located key does not match the input value.');
end