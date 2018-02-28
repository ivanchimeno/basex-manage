(: 
 : Provides functions for running web applications. By running
 : it is meant that inactive and active web application containers
 : are swapped with each other.
:)
module namespace mbr = 'http://in.tum.de/basex/modules/manage-back-run';

import module namespace mbd = 'http://in.tum.de/basex/modules/manage-back-db';
import module namespace mbe = 'http://in.tum.de/basex/modules/manage-back-export';
import module namespace mbs = 'http://in.tum.de/basex/modules/manage-back-settings';
import module namespace mbf = 'http://in.tum.de/basex/modules/manage-back-file';
import module namespace mbx = 'http://in.tum.de/basex/modules/manage-back-xml';
import module namespace mbrep = 'http://in.tum.de/basex/modules/manage-back-repository';
import module namespace mberr = 'http://in.tum.de/basex/modules/manage-back-error';
import module namespace mbi = 'http://in.tum.de/basex/modules/manage-back-import';

import module namespace file = 'http://expath.org/ns/file';
import module namespace fetch = 'http://basex.org/modules/fetch';


(:  Enables the web application using it's identifier specified in $appIdentifier

    The process is don using the following steps:
        1.  We disable any running application so that we save the
            changes.
        2.  We copy all files of the specified web application into the BaseX
            system.
:)
declare
function mbr:enable-webapp($BaseXHomePath as xs:string, $appIdentifier as xs:string)
as element() {
    let $SettingsXml := mbs:get-settings-contents($BaseXHomePath)
    let $eXml := mbs:get-webapp-listing-contents($BaseXHomePath)
    return (
        if (mberr:has-error($SettingsXml)) then $SettingsXml else
        if (mberr:has-error($eXml)) then $eXml 
        else (
            (: If an application is already running, disable it. :)
            let $trackedApp := mbr:get-active-app-id($eXml)
            return (
                if ($trackedApp = $appIdentifier) then (
                    mbx:error(
                        "enable-webapp",
                        "The application with identifier: " || $appIdentifier ||
                        " is already running.",
                        "manage-back-run.xqm"
                    )
                ) else if (string-length($appIdentifier) <= 0) then (
                    mbx:error(
                        "enable-webapp",
                        "The application identifier cannot be empty.",
                        "manage-back-run.xqm"
                    )
                ) else (
                    (: Disable any running web application :)
                    let $d := mbx:results(
                        if (string-length($trackedApp) > 0) then (
                            mberr:get-result(
                                mbr:disable-webapp($BaseXHomePath, $trackedApp)
                            )
                        ) else mbx:result("No application running.")
                    )

                    (: Copy all the files of the .manage directory to the
                       BaseX system. :)
                    let $importDir := mbf:append-to-path(
                        mbs:imports-dir-path($BaseXHomePath),
                        $appIdentifier || ".manage"
                    )

                    let $c := mbx:results(
                        if (mberr:has-error($d)) then mberr:get-result($d) else (
                            (: Install the databases to the BaseX instance :)
                            mberr:get-result(
                                mbd:import-dbs(mbf:append-to-path($importDir, "databases"))
                            ),
                            
                            (: Install the repositories to the BaseX instance :)
                            mberr:get-result(
                                mbf:copy-children(
                                    mbf:append-to-path($importDir, "repo"),
                                    $SettingsXml//Run/RepoPath,
                                    false()
                                )
                            ),

                            (: Install the restxqp files to the BaseX instance :)
                            mberr:get-result(
                                mbf:copy-children(
                                    mbf:append-to-path($importDir, "restxq"),
                                    $SettingsXml//Run/RestXQPath,
                                    false()
                                )
                            ),

                            (: Install the static resources to the BaseX instance :)
                            mberr:get-result(
                                mbf:copy-children(
                                    mbf:append-to-path($importDir, "static"),
                                    $SettingsXml//Run/WebStaticPath,
                                    false()
                                )
                            )
                        )
                    )

                    
                    return (
                        if (mberr:has-error($c)) then (
                            mbx:results((
                                mberr:get-result($c),
                                mberr:get-result(mbr:remove-installed-app($SettingsXml))
                            ))
                        ) else mbx:results((
                            mberr:get-result(mbr:set-tracked-app($BaseXHomePath, $appIdentifier)),
                            mberr:get-result($c)  
                        ))    
                    )
                )
            )
        )
    )
};

(:  Disables the web application using it's identifer
    specified in $appIdentifier.

    The proccess is done using the following steps:
        1.  Retrieve the web application descriptor file 
            via $appIdentifier located inside webapp-listing.xml
        
        2.  Set the application state to "inactive" and run the export
            process which will copy all files into a single .manage archive.
            Contains updated files too.
        
        3.  Import the exported .manage into the system which will automatically
            update the web application listings descriptor file.

        4.  Remove all files corresponding to the web application from the
            BaseX system (db, repos, restxq, static,...)

    
    Returns multiple results.
:)
declare
function mbr:disable-webapp($BaseXHomePath as xs:string, $appIdentifier as xs:string)
as element() {
    let $SettingsXml := mbs:get-settings-contents($BaseXHomePath)
    let $eXml := mbs:get-webapp-listing-contents($BaseXHomePath)
    return (
        if (mberr:has-error($SettingsXml)) then $SettingsXml else
        if (mberr:has-error($eXml)) then $eXml
        else (
            (: Attempt to export the web application :)
            let $eXml := $eXml//WebAppSettings[@appIdentifier=$appIdentifier]
            let $export := (
                if (xs:string($eXml/AppState) = "inactive") then (
                    mbx:error(
                        "disable-webapp",
                        "You cannot disable application with app identifier: " || $appIdentifier ||
                        " because it is already inactive.",
                        "manage-back-run.xqm"
                    )
                ) else (
                    mbe:export-xproject(
                        $BaseXHomePath, 
                        $SettingsXml//Run, 
                        xs:string($eXml/@appIdentifier),
                        "inactive",
                        $eXml/AppName,
                        $eXml/Author,
                        $eXml/EntryUrl
                    )
                )
            )

            (:  If no errors have occur, re-import the web application
                which will contains updated files. :)
            let $import := (
                if (mberr:has-error($export)) then $export 
                else (
                    mbi:import-archive(
                        $BaseXHomePath, 
                        $appIdentifier || ".manage",
                        file:read-binary(mbf:append-to-path(
                            mbs:exports-dir-path($BaseXHomePath),
                            $appIdentifier || ".manage")),
                        true()
                    )
                )
            )

            return (
                if (mberr:has-error($import)) then 
                    (:  The import has failed so remove exported app and
                        display an error.:)
                    mbx:results((
                        mbf:delete-file-dir(mbf:append-to-path(
                            mbs:exports-dir-path($BaseXHomePath),
                            $appIdentifier || ".manage"
                        )),
                        mberr:get-result($import)
                ))
                else mbx:results((
                    mberr:get-result(mbr:remove-installed-app($SettingsXml)),
                    mberr:get-result($import)
                ))
            )
        )
    )
};

(:
    The function checks if an untracted web application is running. If this 
    is the case, it will be imported and tracked by the component as the 
    "default application".
:)
declare
function mbr:detect-default-app($BaseXHomePath as xs:string)
as element() {
    let $SettingsXml := mbs:get-settings-contents($BaseXHomePath)
    let $WebAppSettingsXml := mbs:get-webapp-listing-contents($BaseXHomePath)
    let $r := mbx:results(($SettingsXml,$WebAppSettingsXml))
    return (
        if (mberr:has-error($r)) then $r else (
            (:  Here we check if the BaseX instance has an application
                installed but not tracked by the manage component. :)
            let $untracked := mbr:untracked-app-installed(
                $WebAppSettingsXml, 
                $SettingsXml//Run
            )
            
            return (
                if (mberr:has-error($untracked)) then $untracked else
                if (xs:boolean($untracked//Contents)) then (
                    (: An application that has been installed but not yet 
                    tracked by the component has been detected, so we export
                    it using the "default" identifier, and import it into 
                    the system.:)
                    let $export := (
                        mbe:export-xproject(
                            $BaseXHomePath,
                            $SettingsXml//Run,
                            "default",
                            "active",
                            "Unknown Application",
                            "-",
                            "/"
                        )
                    )
                    return (
                        if (mberr:has-error($export)) then $export
                        else mbx:results((
                            mberr:get-result($export),
                            mberr:get-result(mbr:import-default-webapp($BaseXHomePath))
                        ))
                    )
                )
                else mbx:results(mbx:result("No untracked application installed."))
            )
        )
    )
};

(:
    The function reads paths of the web application components that are installed
    in the current BaseX instance. 
    These are specified specified by $SettingsXml using the following format:
        <Settings>
            <RestXQPath>/absolute/path/to/restxq/code/directory/</RestXQPath>
            <WebStaticPath>/absolute/path/to/static/directory/</WebStaticPath>
            <RepoPath>/absolute/path/to/repo/directory/</RepoPath>
        </Settings>
    The function then removes each directory from these paths.

    Returns multiple results.
:)
declare 
function mbr:remove-installed-app($SettingsXml as element())
as element() {
    mbx:results((
        mberr:get-result(
            mbrep:remove-repos($SettingsXml//Run/RepoPath)
        ),
                        
        mberr:get-result(
            mbd:remove-dbs()
        ),

        mberr:get-result(
            mbf:delete-children($SettingsXml//Run/RestXQPath)
        ),

        mberr:get-result(
            mbf:delete-children($SettingsXml//Run/WebStaticPath)
        )
    ))
};

(:
    Imports the "Default Application" into the manage component. The
    function assumes that the "default.manage" archive is available
    inside the "exports" directory. The import does not overwrite
    if a default application is already installed.

    Returns multiple results.
:)
declare
%private
function mbr:import-default-webapp($BaseXHomePath as xs:string)
as element() {
    try {
        let $fileName := "default.manage"
        let $filePath := mbf:append-to-path(
            mbs:exports-dir-path($BaseXHomePath), 
            $fileName
        )
        
        return mbi:import-archive(
            $BaseXHomePath, 
            $fileName,
            file:read-binary($filePath),
            false()
        )
    } catch * {
        mbx:error($err:code, $err:description, $err:module)
    }
};

(:
    Returns true if a web application is installed inside
    the current BaseX instance. 

    Installed means that no component from the web application
    is empty.

    $SettingsXml specifies the directories of each web 
    application component, and has the following format:
        <Settings>
            <DbPath>/absolute/path/to/database/directory/</DbPath>
            <RestXQPath>/absolute/path/to/restxq/code/directory/</RestXQPath>
            <WebStaticPath>/absolute/path/to/static/directory/</WebStaticPath>
            <RepoPath>/absolute/path/to/repo/directory/</RepoPath>
        </Settings>

    Returns a multiple results.
:)
declare
%private
function mbr:is-app-installed($SettingsXml as element())
as element()
{
    (:  If every directory 
        is empty, we assume that no web application has been 
        created. :)
    let $r := mbx:results((
        mbd:dbs-installed(),
        mbf:has-children($SettingsXml/RestXQPath/text()),
        mbf:has-children($SettingsXml/WebStaticPath/text()),
        mbrep:has-installed-repos($SettingsXml/RepoPath/text())
    ))

    (:  Assuming no errors have occured, we check if at least
        one directory contains files. If that's the case, return
        true otherwise false. :)
    return (
        if (mberr:has-error($r)) then $r 
        else mbx:results(
            mbx:result(count($r//Result[Contents="true"]) > 0)
        )
    )
};

(:
    Returns true if an untracked web application (application that
    has not been previously exported by the component) exists and
    is installed into the current BaseX instance.

    $SettingsXml specifies the directories of each web 
    application component, and has the following format:
        <Settings>
            <DbPath>/absolute/path/to/database/directory/</DbPath>
            <RestXQPath>/absolute/path/to/restxq/code/directory/</RestXQPath>
            <WebStaticPath>/absolute/path/to/static/directory/</WebStaticPath>
            <RepoPath>/absolute/path/to/repo/directory/</RepoPath>
        </Settings>

    Returns multiple results.
:)
declare
%private
function mbr:untracked-app-installed($WebAppSettingsXml as element(), $SettingsXml as element())
as element() {
    let $r := mbr:is-app-installed($SettingsXml)
    let $a := mbr:get-active-app-id($WebAppSettingsXml)
    return (
        if (mberr:has-error($r)) then $r else
        mbx:results(
            mbx:result(
                xs:boolean($r//Contents) and string-length($a) < 1
            )
        )
    )
};

(: 
    Returns the application identifer of the active application
    or an empty string if no application is currently active.
:)
declare
function mbr:get-active-app-id($WebAppSettingsXml as element()) 
as xs:string {
    let $active := $WebAppSettingsXml//WebAppSettings[AppState="active"]
    return (
        if (count($active) < 1) then "" else (
             xs:string($active[1]/@appIdentifier)
        )
    )
};

declare
%private
function mbr:set-tracked-app($BaseXHomePath as xs:string, $appIdentifier as xs:string)
as element() {
    try {
        (: Construct absolute path to the application :)
        let $appFile := mbf:append-to-path(
            mbs:imports-dir-path($BaseXHomePath),
            $appIdentifier || ".manage"
        )

        (:  Retrieve the descriptor file of the application which will be
            updated.:)
        let $appDescriptorPath := mbf:append-to-path(
            $appFile,
            "WebAppSettings.xml"
        )
        let $WebAppSettingsXml := fetch:xml($appDescriptorPath)

        return (
            let $WebAppSettingsXml := (
                copy $x := $WebAppSettingsXml
                modify(
                    replace value of node $x//AppState with "active"
                )
                return mbx:result($x)
            )
            return mbx:results((
                mbf:write-xml($appDescriptorPath, $WebAppSettingsXml//WebAppSettings),
                mbi:restore-webapp-listing($BaseXHomePath)
            ))
        )
    } catch * {
        mbx:error($err:code, $err:description, $err:module)
    }
};
