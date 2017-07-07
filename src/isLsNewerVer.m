function isNewer = isLsNewerVer()
% Indicates if the logic simplifier was caller from a 'newer version'

ver = version('-release');
isNewer = str2num(ver(1:4)) >= 2015;
end