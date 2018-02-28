module namespace mbd = 'http://in.tum.de/basex/modules/manage-back-db';

import module namespace file = 'http://expath.org/ns/file';

import module namespace mbf = 'http://in.tum.de/basex/modules/manage-back-file';
import module namespace mbx = 'http://in.tum.de/basex/modules/manage-back-xml';
import module namespace mberr = 'http://in.tum.de/basex/modules/manage-back-error';


(:~ Reads each <Database> element specified in $dbXml
    as the database name to export, and exports them 
    into the directory  specified by $dstPath. 
    A directory for each database will automatically be created.

    Returns multiple results.
:)
declare
function mbd:export-dbs($dstPath as xs:string, $dbXml as element())
as element() {
  try {
    let $c := mbf:create-dir($dstPath)
    return mbx:results(
      if (mberr:has-error($c)) then $c else (
        for $db in $dbXml//Database
          (: Absolute path to the destination directory
             that will contain the database contents. :)
          let $dstPath := mbf:append-to-path($dstPath, $db)
        return (
          db:export($db, $dstPath), 
          mbx:result($db || " exported successfully.")
        )
      )
    )
  } catch * {
    mbx:error($err:code, $err:description, $err:module)
  }
};

(: 
    Imports all databases that are stored inside the directory
    specified in $srcPath. 

    Returns multiple results
:)
declare
%updating
function mbd:import-dbs($srcPath as xs:string)
as element() {
  try {
    if (file:exists($srcPath)) then (
      let $dbListing := mbf:list($srcPath, false(), "")
      return mbx:results(
        if (mberr:has-error($dbListing)) then $dbListing 
        else (
            (: Iterate over each database, construct the paths pointing
              to it's files and import them. :)
            for $db in $dbListing//file 
              let $dbPath := mbf:append-to-path($srcPath, file:name($db))

              (: Construct absolute paths pointing to every single
                file that will be imported into the database. 
                An error may also be returned. :)
              let $fileListing := mbf:list($dbPath, false(), "")
              let $paths := (
                if (mberr:has-error($fileListing)) then ()
                  else (
                    for $f in $fileListing//file 
                    return mbf:append-to-path($dbPath, $f)
                  )
              )

            return (
              if (mberr:has-error($fileListing)) then $fileListing
              else (
                db:create(file:name($db), $paths),
                mbx:result(file:name($db) || " imported successfully.")
              )
            )
        )
      )
    ) else mbx:results(mbx:result(""))
  } catch * {
    mbx:error($err:code, $err:description, $err:module)
  }
};

(: 
    Returns true if there are any databases 
    installed on the system. 

    Returns a single result.
:)
declare
function mbd:dbs-installed()
as element() {
  try {
    mbx:result(count(db:list()) > 0)
  } catch * {
    mbx:error($err:code, $err:description, $err:module)
  }
};

(:
    This function retrieves all databases installed on 
    the running BaseX instance via db:list() and then
    removes them by dropping each database.

    Returns multiple results.
:)
declare
function mbd:remove-dbs()
as element() {
  try {
    let $d := (
      for $db in db:list()
      return(
        db:drop($db),
        mbx:result("Successfully dropped database " || $db || ".")
      ) 
    )
    return mbx:results($d)
  } catch * {
    mbx:error($err:code, $err:description, $err:module)
  }
};

(:
    Returns a list of databases installed of the following format:
      <Databases count="n">
        <Database>db_name_1</Database>
        ...
        <Database>db_name_n</Database>
      </Databases>

    Returns a single result.
:)
declare
function mbd:list-db()
as element() {
  try {
    let $dbList := (
      for $db in db:list()
      return <Database>{$db}</Database>
    )
    return mbx:result(
      <Databases count="{count($dbList)}">
      {$dbList}
      </Databases>
    )
  } catch * {
    mbx:error($err:code, $err:description, $err:module)
  }
};