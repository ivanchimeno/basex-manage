module namespace e = 'http://in.tum.de/basex/modules/manage-back-export';

import module namespace db = 'http://basex.org/modules/db';
import module namespace random = 'http://basex.org/modules/random';
import module namespace file = 'http://expath.org/ns/file';
import module namespace archive = 'http://basex.org/modules/archive';

import module namespace mberr = 'http://in.tum.de/basex/modules/manage-back-error';
import module namespace mbrep = 'http://in.tum.de/basex/modules/manage-back-repository';
import module namespace mbd = 'http://in.tum.de/basex/modules/manage-back-db';
import module namespace mbx = 'http://in.tum.de/basex/modules/manage-back-xml';
import module namespace mbf = 'http://in.tum.de/basex/modules/manage-back-file';
import module namespace mbs = 'http://in.tum.de/basex/modules/manage-back-settings';

(:
    This functions exports a web application specified in $exportXml
    by copying all necessary data into the tmp directory of the component 
    and then creating a .manage archive inside the exports directory.

    $exportXml must have the following format:
      <WebAppSettings appIdentifier=''>
        <AppState>inactive</AppState>
        <AppName>APPLICATION NAME</AppName>
        <Author>APPLICATION AUTHOR</Author>
        <EntryUrl>ROOT URL OF APP</EntryUrl>
        <Databases>
          <Database>DATABASE_NAME_1</Database>
          ...
          <Database>DATABASE_NAME_N</Database>
        </Databases>
        <Packages>
          <Package>REL_PATH_TO_PKG_NAME_1</Package>
          ...
          <Package>REL_PATH_TO_PKG_NAME_N</Package>
        </Packages>
      </WebAppSettings>
    
    The function needs to know where the components of the web application
    are located. These are specified in $settings and have the following 
    format:
      <ExportSettings>
        <DbPath>/absolute/path/to/database/directory/</DbPath>
        <RestXQPath>/absolute/path/to/restxq/code/directory/</RestXQPath>
        <WebStaticPath>/absolute/path/to/static/directory/</WebStaticPath>
        <RepoPath>/absolute/path/to/repo/directory/</RepoPath>
      </ExportSettings>
    
    Returns multiple results.
:)
declare 
function e:export-xproject($BaseXHomePath as xs:string, $settings as element(), $exportXml as element()) 
as element() {
  try {
    (: Attempt to retrieve length of app identifier int.
       Otherwise return 0.:)
    let $maxInt := (
      let $s := mbs:get-settings-contents($BaseXHomePath)
      return (
        if (mberr:has-error($s)) 
        then 0 
        else xs:integer($s//MaxIntegerSeparator/text())
      )
    )

    (: Attempt to export web application to the temporary 
       directory and generate an application descriptor 
       file based on $exportXml. :)
    let $export := mbx:results((
      mberr:get-result(
        e:export-web-components($BaseXHomePath, $settings ,$exportXml)
      ),

      e:export-web-app-settings(
        $maxInt, 
        mbs:tmp-dir-path($BaseXHomePath),
        $exportXml
      )
    ))

    return (
      if (mberr:has-error($export)) then $export else (
        mbx:results((
          e:create-archive(
            mbs:tmp-dir-path($BaseXHomePath), 
            mbs:exports-dir-path($BaseXHomePath), 
            xs:string($export//WebAppSettings/@appIdentifier)
          ),
          mberr:get-result($export)
        ))
      )
    )
  } catch * {
    mbx:error($err:code, $err:description, $err:module)
  }
};

(:
    This function exports a web application based on information specified
    in $appIdentifier, $AppState, $appName, $appAuthor, and $entryUrl. It
    will automatically generate a descriptor and add the databases and
    repositories to it. 

    The paths specified in $dstSettingsXml will be used as source paths for
    the extraction.

    Returns multiple results
:)
declare
function e:export-xproject(
  $BaseXHomePath as xs:string, 
  $dstSettingsXml as element(),
  $appIdentifier as xs:string,
  $appState as xs:string,
  $appName as xs:string,
  $appAuthor as xs:string,
  $entryUrl as xs:string)
as element() {
  try {
    (: Retrieve a list of all installed external XQuery modules :)
    let $pkgs := mbrep:installed-repos($dstSettingsXml/RepoPath/text())
    return (
      if (mberr:has-error($pkgs)) then $pkgs
      else (
        (: Generate XML file describing the web application to export :)
        copy $ex := mbx:gen-app-settings()
        modify (
          replace value of node $ex/@appIdentifier with $appIdentifier,
          replace value of node $ex/Author with $appAuthor,
          replace value of node $ex/AppName with $appName,
          replace value of node $ex/AppState with $appState,
          replace value of node $ex/EntryUrl with $entryUrl,
          insert node (db:list() ! <Database>{.}</Database>) into $ex/Databases,
          insert node (for $p in $pkgs//Package return <Package>{xs:string($p/@path)}</Package>) into $ex/Packages
        )

        (: Export the application to the exports directory. :)
        return e:export-xproject($BaseXHomePath,$dstSettingsXml, $ex)
      )
    )
  }
  catch * {
    mbx:error($err:code, $err:description, $err:module)
  }
};

(: 
    This function generates the web application settings XML file by copying
    the contents of $exportXml, adding an application identifier if needed, and
    writing it to the directory specified in $dstPath.

    The xml file specified in $exportXml must have the following format:
      <WebAppSettings appIdentifier="">
        <AppState></AppState>
        <AppName></AppName>
        <Author></Author>
        <EntryUrl>/</EntryUrl>
        <Databases>
        <Database>DB</Database>
        </Databases>
        <Packages/>
      </WebAppSettings>

      Returns a single result
:)
declare
%private
function e:export-web-app-settings($maxInt as xs:integer, $dstPath as xs:string, $exportXml as element())
as element() {
  try {
    (: Generate the suffix that will serve as application identifer
       if the application identifier is empty :)
    let $maxInt := if ($maxInt <= 0) then 50 else $maxInt
    let $r := e:append-random-suffix(
      $maxInt, 
      $exportXml//AppName
    )
    
    return (
      if (mberr:has-error($r)) then $r else (
        (: Add the generated application identifier only if
           no identifier has already been specified. :)
        let $exportXml := (
          if (string-length($exportXml/@appIdentifier) <= 0) then (
            copy $xml := $exportXml
            modify(
              replace value of node $xml/@appIdentifier with $r//Contents
            )
            return $xml
          ) else $exportXml
        )

        return mbf:write-xml(
          mbf:append-to-path($dstPath, "WebAppSettings.xml"),
          $exportXml
        )
      )
    )
  } catch * {
    mbx:error($err:code, $err:description, $err:module)
  }
};

(:  
    The function exports all components of a web application and writes
    these to the tmp sub-directory of the manage component. The location of
    the BaseX home directory is therefore required and specified in $BaseXHomePath.

    Databases and repository to be exported are specified inside the $exportXml xml
    document. The function also searches for the location of the directories to be exported
    inside the $settings xml file.

    Returns multiple results.
:)
declare
%private
function e:export-web-components($BaseXHomePath as xs:string, $settings as element(), $exportXml as element()) 
as element() {
  try {
    (:  Use the 'tmp' directory of the component as the destination 
        for file writing. :)
    let $tmpDir := mbs:tmp-dir-path($BaseXHomePath)
    return mbx:results((
      (: Make sure the tmp directory is empty before
         copying files to it.:)
      mberr:get-result(mbf:delete-children($tmpDir)),
      mbf:create-ignore-file($tmpDir),

      (: Export databases to the ~/tmp/databases directory :)
      mberr:get-result(
        mbd:export-dbs(
          mbf:append-to-path($tmpDir, "databases"), 
          $exportXml)
      ),

      (: Export repository packages to the ~/tmp/repo directory. :)
      mberr:get-result(
        e:export-packages(
          $settings/RepoPath, 
          mbf:append-to-path($tmpDir, "repo"), 
          $exportXml)
      ),

      (: Export the static resource folder :)  
      mberr:get-result(
        mbf:copy(
          $settings/WebStaticPath,
          mbf:append-to-path($tmpDir, "static"),
          true()
        )
      ),
      
      (: Export the webapp restxq folder :)  
      mberr:get-result(
        mbf:copy(
          $settings/RestXQPath,
          mbf:append-to-path($tmpDir, "restxq"),
          true()
        )
      )
    ))
  } catch * {
    mbx:error($err:code, $err:description, $err:module)
  }
};

(:~ 
    Exports external XQuery modules located inside the repository system. The packages to
    be exported must be specified inside $exportXml xml file, which should be in the 
    following format:
      <Packages>
        <Package>RELATIVE_PATH_TO_PACKAGE/PACKAGE_NAME</Package>
      </Packages>

    The modules will be exported to the directory specified in $destPath. 

    Returns multiple results.
:)
declare 
%private
function e:export-packages($repoPath as xs:string, $dstPath as xs:string, $exportXml as element())
as element() {
  try {
    (: Create the directory that will hold the packages if it doesn't 
       already exist :)
    let $c := mbf:create-dir($dstPath)
    return (
      if (mberr:has-error($c)) then mbx:results($c) else (
        mbx:results((
          $c,
          for $p in $exportXml//Package/text()
            let $dstPath := mbf:append-to-path($dstPath, $p)
            let $srcPath := mbf:append-to-path($repoPath,$p)
          return mberr:get-result(mbf:copy($srcPath, $dstPath, true()))
        ))
      )
    )
  } catch * {
    mbx:error($err:code, $err:description, $err:module)
  }
};

(:
    This function appends a randomly-generated integer
    to the text specified in $text. The length of the 
    generated integer can be passed in $max.

    Returns a single result.
:)
declare
%private
function e:append-random-suffix($max as xs:integer, $text as xs:string) 
as element() {
  try {
    let $seed := random:integer($max)
    let $filename := $text || "-" || $seed
    return mbx:result($filename)
  } catch * {
    mbx:error($err:code, $err:description, $err:module)
  }
};

(:~ 
    Creates an archive with the .manage extension of the files located inside the directory specified by $srcPath 
    and saves it to the directory specified by $destPath. 
    The name of the archive is specified by $archName.

    Returns a single result.
:)
declare
%private
function e:create-archive($srcPath as xs:string, $destPath as xs:string, $archName as xs:string)
as element() {
  try {
    let $dirsExist := file:is-dir($srcPath) and file:is-dir($destPath)
    let $destPath := mbf:append-to-path($destPath, $archName || ".manage")
    return (
      if ($dirsExist) then (
        (: Build the archive and write it to disk :)
        mbx:result((
          file:write-binary(
            $destPath, 
            archive:create-from($srcPath)),
          "Successfully created archive " || $destPath
        ))
      ) else mbx:error(
        "create-archive()", 
        "Archive was not created because either " || $srcPath || " or " || $destPath || " do not exist.", 
        "manage-back-export.xqm")
    )
  } catch * {
    mbx:error($err:code, $err:description, $err:module)
  }
};




