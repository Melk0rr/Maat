# Powershell: Maat


```
                        8b    d8    db       db    888888 
                        88b  d88   dPYb     dPYb     88   
                        88YbdP88  dP__Yb   dP__Yb    88   
                        88 YY 88 dP""""Yb dP""""Yb   88                  
     :-=+***+*#*++%##%*%#***%##%*%##%%*#%%####*********+++=-
  -*%+:-. : :+ : +-.+ -. - =-:= =-.=: :-                    
:##== :- = := = =..= =. = =.:= +..=  -                      
#%.*  + :- + - :- = =: + -:.+ +. =  =                       
#%.= :- *.=:        : -..= + :- +  +.                       
.#%+ := =-%=               . .  - .=

```

This project is a Powershell tool that retreive access ACLs on directories and optionaly retreive AD group data related to the attribution of those ACLs

## Requirements

This script requires Powershell 7.0 and ActiveDirectory module

## Getting Started

To install this module, you first need to download the project. You can then copy the module to your modules directory and then load it with:

`Import-Module Maat`

Symlink works perfectly too.

Alternatively, you can just import it directly from the project directory with:

`Import-Module C:\Path\To\Maat`

## Usage
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

      ---------------------------------------------------------------

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


## Examples

