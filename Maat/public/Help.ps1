$helpHeart = @"
Usage:
  Invoke-MaatHeart -XMLConfigPath CONFIGPATH -OutPath OUTPATH -Server SERVERLIST -DebubMode-Override
  Invoke-MaatHeart -Help
  Invoke-MaatHeart -Version

Options:
  -DebugMode                     toggle debug mode to show more log messages
  -Help                          show this help message and exit
  -Outpath OUTPATH               output file path
  -Override                      if toggled the date will not be mentioned in the result name
  -Server SERVERLIST             server list to use for ad queries
  -Version                       show version and exit
  -XMLConfigPath CONFIGPATH      path of the configuration

Help:
  For help using this tool, please open an issue on the Github repository:
  https://github.com/Melk0rr/Maat
"@

$helpWeighing = @"
Usage:
  Invoke-MaatWeighing -FeatherPath FEATHERPATH -HeartPath HEARTPATH
  Invoke-MaatWeighing -Help
  Invoke-MaatWeighing -Version
  
Options:
  -FeatherPath FEATHERPATH       path of the 'feather' result (base result)
  -HeartPath HEARTPATH           path of the 'heart' result (new result)
  -Help                          show this help message and exit
  -Version                       show version and exit

Help:
  For help using this tool, please open an issue on the Github repository:
  https://github.com/Melk0rr/Maat
"@