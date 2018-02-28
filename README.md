# basex-manage

A component that allows managing web applications within a single BaseX framework. 

This project is an implementation of my Bachelor's thesis in computer science.


## Installation via Script ##

##### Download and run BaseX #####
1. Download [BaseX](www.basex.org) and [run](http://docs.basex.org/wiki/Startup#HTTP_Server) the BaseX HTTP server.
2. [Run](http://docs.basex.org/wiki/Startup#Client) the BaseX client and login using admin credentials.


##### Prepare the script #####
Open the `install.xqm` XQuery script and edit `$BasexHomePath` to point to the BaseX directory.


##### Execute the script #####
Execute the following command using the BaseX client:
```RUN /PATH-TO-INSTALL/install.xqm ```


 Note that `[PATH-TO-INSTALL]` denotes the full path to the directory containing the repository content.

 ##### Run the component #####
 1. Restart the server for changes to take effect.
 2. Call http://localhost:8984/manage to access the component (no '/' at the end).


## Manual Installation  ##
If the script does not work out, follow the following steps:

1. [Run](http://docs.basex.org/wiki/Startup#HTTP_Server) the BaseX HTTP server so that the `.basex` configuration file can be generated.
2. Open `.basex` and append `MIXUPDATES = true` at the end of the file.
3. Copy the contents of the `repo` folder included in this repository and paste them inside the `repo` folder of the BaseX framework.
4. Copy the `manage` folder to the `webapp` folder of the BaseX framework.
5. Open `landing-settings.xml`, which is located within the `webapp/manage` directory, and change the value of `BasexHomePath` so that it points to the home directory of the BaseX framework.
6. Navigate to the `webapp` directory and create a new folder called `restxq`.
7. Move every XQuery file located inside `webapp` to `restxq`.
8. Restart the server for changes to take effect and call http://localhost:8984/manage to access the component (no '/' at the end).