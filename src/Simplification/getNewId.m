function id = getNewId(existingIDs)
% GETNEWID Gets an identifier to use in an expression. The input argument
%   prohibits a list of identifiers.
%
%   Inputs:
%       existingIDs A cell array of identifiers to not be returned.
%
%   Output:
%       id          Character array for a new identifier that is not in
%                   existingIDs.

    i = 1; % Represents the number of characters in id
    id = '';
    while strcmp(id,'') % id stays empty when no id of i chars in length is available
        id = getNewId_Aux(i, '', existingIDs, true);
        i = i + 1;

        if i >= 4
            warning([mfilename ' is taking a longer than expected (there may be an infinite loop). Iteration #: ' i])
            % If this function causes the Logic Simplifier to be slow,
            % consider passing an integer indicating how many of the
            % id options are likely in existingIDs and use that information
            % to start at a different point (e.g. with a base of 4
            % characters because all 3 character options are likely taken).
            % Alternatively, get the length of existingIDs at the start of
            % this function and assume they are the same ids that this
            % function returns (i.e. using length of existingIDs instead of
            % an input to this function).
        end
    end
end

function id = getNewId_Aux(n, prefix, existingIDs, first)
% Get an id that's not in existingIDs, starts with a given prefix, and
%   following the prefix has a given number of characters from a given
%   array of characters.
%
%   Inputs:
%       n               Number of characters to add to the prefix.
%       prefix          Prefix to try for the id.
%       existingIDs     A cell array of identifiers to not be returned.
%       first           Logical indicating if this is the first iteration
%                       of this recrsive function.
%
%   Output:
%       id      Character array for an identifier. If no id is found,
%               id is ''.

    % Characters to try to use in id:
    idchars = char([48:57, 65:90]); % 48:57 are 0-9, 65:90 are A-Z
    % A complete set of characters that can be used in this way is given by
    % char([48:57, 95, 65:90, 97:122]), however this would ultimately make
    % debugging harder for the logic simplifier and the id we use doesn't
    % really matter.

    if n == 0 % prefix is the only possible id
        if isempty(find(strcmp(prefix,existingIDs), 1)) % Check if prefix is not in existingIDs
            % prefix is a suitable id
            id = prefix;
        else
            % prefix is not a suitable id
            id = '';
        end
    else
        if first
            % id can't start with a digit so the first 10 characters in
            % idchars will be skipped on this first recursive iteration
            i = 11;
        else
            i = 1;
        end
        id = '';
        while strcmp(id,'') && i<=length(idchars)
            newPrefix = [prefix, idchars(i)];
            id = getNewId_Aux(n-1, newPrefix, existingIDs, false);
            % if id is not '' then we have found the first available
            i = i + 1;
        end
        % if i > length(idchars) then the prefix did not find an id
    end
end