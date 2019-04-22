function copyConfigParams(sys1, sys2)
% COPYCONFIGPARAMS Make sys2 configuration parameters like sys1 whenever they differ.
     noncompatible = checkParamCompatibility(sys1, sys2);
     
     for i = 1:length(noncompatible)
        set_param(sys2, noncompatible{i}, get_param(sys1, noncompatible{i}));
     end
end