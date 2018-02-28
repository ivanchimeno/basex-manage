module namespace ds = 'http://in.tum.de/basex/modules/manage-back-settings';

import module namespace file = 'http://expath.org/ns/file';
import module namespace fetch = 'http://basex.org/modules/fetch';

import module namespace df = 'http://in.tum.de/basex/modules/manage-back-file';
import module namespace dxt = 'http://in.tum.de/basex/modules/manage-back-xml';

declare namespace x = 'http://java.sun.com/xml/ns/javaee';

(:~ Returns the path to the home directory of the manage component.
    The path is calculated using the following steps:

    1:  If the .basex file exists, the RESTXQPATH will be read.
    2:  If RESTXQPATH is empty, WEBPATH will be read and used as
        the root directory. 
    3:  If RESTXQPATH contains absolute path, it will be used as
        the root directory.
    4:  If RESTXQPATH contains relative path, it will be appended to
        WEBPATH and then used as the root directory.
    5:  If the .basex file does not exist (assumed to be .war distribution)
        it will just use the $baseXHomePath as root directory
:)
declare
function ds:manage-dir-path($baseXHomePath as xs:string) as xs:string {
    try {
        let $config := df:append-to-path($baseXHomePath, ".basex") 
        let $configExists := file:exists($config)
        return (
            if ($configExists)
            then (
                (: .basex file exists so read RESTXQPATH :)
                let $RESTXQPATH := dxt:to-string(df:value-of-key($config, "RESTXQPATH", "="))
                let $WEBPATH := dxt:to-string(df:value-of-key($config, "WEBPATH", "="))
                return (
                    (: WEBPATH used if RESTXQPATH is empty. :)
                    if (fn:string-length($RESTXQPATH) = 0) then df:append-to-path($WEBPATH, "manage")
                    else (
                        (: If $WEBPATH is relative, return absolute. :)
                        let $WEBPATH := (
                            if (file:is-absolute($WEBPATH)) 
                            then $WEBPATH 
                            else file:resolve-path($WEBPATH, $RESTXQPATH)
                        )
                        return df:append-to-path($WEBPATH, "manage")
                    )
                )
            )
            else (
                (: .basex does not exist, so .war distribution is assumed.
                    Just return the $baseXHomePath :)
                df:append-to-path($baseXHomePath, "manage")
            )   
        )
    }
    catch * {
        df:append-to-path($baseXHomePath, "manage")
    }
};

(:  Reads the .basex configuration file and returns a 
    map of all components.
:)
declare 
function ds:from-basex-config($file as xs:string) {
    try {
        map {
            "DBPATH" : dxt:to-string(df:value-of-key($file, "DBPATH", "=")),
            "REPOPATH" : dxt:to-string(df:value-of-key($file, "REPOPATH", "=")),
            "WEBPATH" : dxt:to-string(df:value-of-key($file, "WEBPATH", "=")),
            "RESTXQPATH" : dxt:to-string(df:value-of-key($file, "RESTXQPATH", "="))
        }
    } 
    catch * {
        dxt:error($err:code, $err:description, $err:module)
    }
};

declare
function ds:settings-dir-path($baseXHomePath as xs:string) 
as xs:string {
    df:append-to-path(
        ds:manage-dir-path($baseXHomePath), 
        "settings"
    )
};

declare
function ds:exports-dir-path($baseXHomePath as xs:string) 
as xs:string {
    df:append-to-path(
        ds:manage-dir-path($baseXHomePath), 
        "exports"
    )
};

declare
function ds:imports-dir-path($baseXHomePath as xs:string) 
as xs:string {
    df:append-to-path(
        ds:manage-dir-path($baseXHomePath), 
        "imports"
    )
};

declare
function ds:tmp-dir-path($baseXHomePath as xs:string) 
as xs:string {
    df:append-to-path(
        ds:manage-dir-path($baseXHomePath), 
        "tmp"
    )
};

declare
function ds:settings-file-path($baseXHomePath as xs:string) 
as xs:string {
    df:append-to-path(
        ds:settings-dir-path($baseXHomePath), 
        "settings.xml"
    )
};

declare
function ds:webapp-listing-file-path($baseXHomePath as xs:string) 
as xs:string {
    df:append-to-path(
        ds:settings-dir-path($baseXHomePath), 
        "webapp-listing.xml"
    )
};

declare
function ds:get-settings-contents($baseXHomePath as xs:string) 
as element() {
    try {
        (: Retrieve contents of the settings.xml file :)
        let $path := ds:settings-file-path($baseXHomePath)
        let $xml := fetch:xml($path)

        (:  Before returning the results, transform each path into a native
            one :)
        let $xml := ds:transform-paths-to-native($xml)

        (: Overwrite the settings.xml file with new contents :)
        let $write := (
            if (xs:boolean($xml//Success)) 
            then df:write-xml($path, $xml//Contents/*) 
            else $xml
        )
        return $write
    } catch * {
        dxt:error($err:code, $err:description, $err:module)
    }
};

(: Reads the contents of the webapp-listing.xml file.
:)
declare
function ds:get-webapp-listing-contents($baseXHomePath as xs:string) 
as element() {
    try {
        let $path := ds:webapp-listing-file-path($baseXHomePath)
        let $xml := fetch:xml($path)
        return dxt:result($xml)
    } catch * {
        dxt:error($err:code, $err:description, $err:module)
    }
};

declare
function ds:set-webapp-listing-contents($baseXHomePath as xs:string, $contents as element())
as element() {
    let $path := ds:webapp-listing-file-path($baseXHomePath)
    return df:write-xml($path, $contents)
};

(:~ Assuming that $settingsXml contains the contents of the settings.xml file that is available
    via this component, this functions reads each path and transforms it into a native one
    used by the operating system. The updated XML is returned.
:)
declare
%private
function ds:transform-paths-to-native($settingsXml as document-node()) 
as element() {
    try {
        copy $x := $settingsXml
        modify (
            for $xx in $x//DbPath
                return replace value of node $xx with file:path-to-native($xx),
            
            for $xx in $x//RestXQPath
                return replace value of node $xx with file:path-to-native($xx),

            for $xx in $x//WebStaticPath
                return replace value of node $xx with file:path-to-native($xx),

            for $xx in $x//RepoPath
                return replace value of node $xx with file:path-to-native($xx)
        )
        return dxt:result($x)
    } catch * {
        dxt:error($err:code, $err:description, $err:module)
    }
};