function bool = isSupportedMaskType(maskType)
%

supportedMaskTypes = {'Compare To Constant', 'Compare To Zero'};
bool = any(strcmp(maskType, supportedMaskTypes));
end