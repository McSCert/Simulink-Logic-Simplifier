function bool = isSupportedMaskType(maskType)
%

supportedMaskTypes = {};
bool = any(strcmp(maskType, supportedMaskTypes));
end