module namespace mbe = 'http://in.tum.de/basex/modules/manage-back-import';

import module namespace archive = 'http://basex.org/modules/archive';
import module namespace file = 'http://expath.org/ns/file';
import module namespace fetch = 'http://basex.org/modules/fetch';

import module namespace mbx = 'http://in.tum.de/basex/modules/manage-back-xml';
import module namespace mbf = 'http://in.tum.de/basex/modules/manage-back-file';
import module namespace mbs = 'http://in.tum.de/basex/modules/manage-back-settings';
import module namespace mberr = 'http://in.tum.de/basex/modules/manage-back-error';
import module namespace mbr = 'http://in.tum.de/basex/modules/manage-back-run';



(:  
    Imports a web application into the manage component system.
    The web application name (including .manage extension) should be specified in $name
    and the contents of the .manage archive in $contents
    
    The application will be imported to the "imports" directory.

    Returns multiple results.
:)
declare
function mbe:import-archive(
    $BaseXHomePath as xs:string, 
    $name as xs:string, 
    $contents as xs:base64Binary, 
    $overwrite as xs:boolean)
as element() {
    try {
        let $extract := mbe:extract-archive(
            $name, 
            $contents, 
            mbs:imports-dir-path($BaseXHomePath), 
            $overwrite
        )

        return mbx:results(
            if (mberr:has-error($extract)) then $extract
            else (
                $extract, 
                mbe:restore-webapp-listing($BaseXHomePath)
            )
        )
    } catch * {
        mbx:error($err:code, $err:description, $err:module)
    }
};

(:  
    Extracts the contents of an archive specified in $contents into $dstPath.
    A new directory will be created using the name specified in $name. The
    archive has to end with the .manage file extension

    Returns a single result.
:)
declare
%private
function mbe:extract-archive(
    $name as xs:string, 
    $contents as xs:base64Binary, 
    $dstPath as xs:string, 
    $overwrite as xs:boolean
) as element() 
{
    try {
        (:  Create a directory that will host extracted files.
            Directory has the same name as the archive. :)
        let $dstPath := mbf:append-to-path($dstPath, $name)
        
        (: Returns false if directory already exist :)
        let $canImport := not(file:exists($dstPath)) or $overwrite
        return (
            if ($canImport) then (
                let $cDir := mbf:create-dir($dstPath)
                return (
                    if (mberr:has-error($cDir)) then $cDir 
                    else (
                        archive:extract-to($dstPath, $contents),
                        mbx:result($name || " successfully extracted to " || $dstPath)
                    ) 
                )
            ) else mbx:error(
                "extract-archive", 
                "Cannot extract archive because " || $dstPath || " already exists.",
                "manage-back-import.xqm"
            )
        )
    } catch * {
        mbx:error($err:code, $err:description, $err:module)
    }
};

(:
    Restores the state of the web application listings file by 
    scanning the imports directory for any application and copying
    its' descriptors to the file.

    Returns a single result.
:)
declare
function mbe:restore-webapp-listing($BaseXHomePath as xs:string)
as element()
{
    try {
        (:  Get the path to the 'imports' directory and 
            retrieve all .manage folders. :)
        let $iPath := mbs:imports-dir-path($BaseXHomePath)
        let $apps := mbf:list($iPath, false(), "*manage")
        return (
            if (mberr:has-error($apps)) then $apps else (
                (:  Sequence containing paths to WebAppSettings.xml
                    of each imported web application. :)
                let $paths := (
                    for $a in $apps//file return (
                        mbf:append-to-path(
                            mbf:append-to-path($iPath, file:name($a)),
                            "WebAppSettings.xml"
                        )
                    )
                )

                (:  Generate new web application listings xml file based
                    on imported web applications. :)
                let $x := (
                    copy $WebAppListingsXml := mbx:gen-webapp-listing()
                    modify (
                        for $p in $paths
                            let $contents := fetch:xml($p)
                        return insert node $contents into $WebAppListingsXml
                    )
                    return $WebAppListingsXml
                )
                return mbs:set-webapp-listing-contents($BaseXHomePath, $x)
            )
        )
    } catch * {
        mbx:error($err:code, $err:description, $err:module)
    }
};

(:  Removes a web application specified in $appFilename that has been imported by this tool.
    The function checks if the application is running, if it is then it will be removed.
    The function will also remove the application directory from the imports directory
    and removes the WebAppSettings entry from the webapp-listing.xml file.

    Returns multiple results.
:)
declare
function mbe:remove-webapp($BaseXHomePath as xs:string, $appFilename as xs:string) 
as element() {
    (: Path to web application directory:)
    let $appDirPath := mbf:append-to-path(
        mbs:imports-dir-path($BaseXHomePath), 
        $appFilename || ".manage"
    )

    let $WebAppListingsXml := mbs:get-webapp-listing-contents($BaseXHomePath)
    let $SettingsXml := mbs:get-settings-contents($BaseXHomePath)
    return (
        if (mberr:has-error($WebAppListingsXml)) then $WebAppListingsXml 
        else if (mberr:has-error($SettingsXml)) then $SettingsXml
        else mbx:results((
            (:  Remove the web application from the BaseX system if it is
                active.:)
            if (mbr:get-active-app-id($WebAppListingsXml) = $appFilename)
            then mberr:get-result(mbr:remove-installed-app($SettingsXml)) else (),

            (: Remove the web application from the imports directory, 
                and update the web app listings file.:)
            mbf:delete-file-dir($appDirPath),
            mbe:restore-webapp-listing($BaseXHomePath)    
        ))
    )
};

