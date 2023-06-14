# Powershell: Maat


```
                                           -=#@@@@@%+-      
                                       .=*@@@###+++*%@@*=   
                                     .*@@#=    .:===- =%@%- 
                                   :*@@= .-=====:   .==--%@=
                                  *@@+.--===-:  .-==-  .=*@@
                                :@@%=--:.    -+*=   .++  :@@
                               -@@+ ...:-====-  .-==: .+++@%
                             :%@%:----====-.  -=.*+--+ -*@%.
                            =@@*:--====-:. :==.  =%@@@@@%=  
                           *@%=------:. .:===.      .:.     
                         :%@@:.      :=**+:  .              
                        =@@* ::--====-:   :-:     ,8.       ,8.                             
                       *@@=---==--.   .-==::     ,888.     ,888.                                
                     .%@#=----:.  :-===-. .     .``8888.   .``8888.                            
                   .#@@#--:.  .:-===-.  ::     ,8.``8888. ,8.``8888.                             
                   #@@:. ..-=**+-    -*+ :    ,8'8.``8888,8^8.``8888.                              
                 :%@#+---===-:  .-===-. :    ,8' ``8.``8888' ``8.``8888.                            
                =@@*----:.   :-===:  .-:    ,8'   ``8.``88'   ``8.``8888.                               
              :@@%::    .:-===-:  .-=-.    ,8'  e  ``8.``'  e  ``8.``8888.                  
             =@@%==---==-:     .-==-.     ,8'  d8b  ``8   d8b  ``8.``8888.                                
            +@@::       .-=**-     .-    ,8'  /Y88b  ``  /Y88b  ``8.``8888.                               
          .*@%:              .-===:          /  Y88b   /  Y88b                             
         =@@*.                    :         /____Y88b /____Y88b                          
       .#@%-                               /      Y88b      Y88b                              
      :%@+                                                  
     *@@=                                8888888888 88888888888888888888                            
    *@@-                                          8 8888            
  :@@*.                                           8 8888           
 +@@-                                             8 8888            
%@#                                               8 8888

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
        Invoke-Maat
        Invoke-Maat -Help
        Invoke-Maat -Version
        
      Options:
        -Help                          show this help message and exit
        -Version                       show version and exit

      Help:
        For help using this tool, please open an issue on the Github repository:
        https://github.com/Melk0rr/Maat


## Examples

