module namespace duf = 'http://in.tum.de/basex/modules/manage-back-file';

import module namespace file = 'http://expath.org/ns/file';

import module namespace mbx = 'http://in.tum.de/basex/modules/manage-back-xml';
import module namespace mberr = 'http://in.tum.de/basex/modules/manage-back-error';


(:~ Writes an xml element to the file specified in $path.
    
    Returns a single result containing xml that was
    wriiten.
:)
declare
function duf:write-xml($path as xs:string, $xml as element()) 
as element() {
  try {
    let $o := map { "method" : "xml" }
    let $w := file:write($path, $xml, $o)
    return mbx:result($xml)
  } catch * {
    mbx:error($err:code, $err:description, $err:module)
  }
};

(: Returns true if the file specified in $path
   is an XML document.
:)
declare 
function duf:is-xml($path as xs:string) 
as xs:boolean {
  try {
    let $c := fetch:xml($path)
    return true()
  } catch * {
    false()
  }
};

(:~ Writes an empty .ignore file to the destination directory
    specified in $path.

    Returns a single result.
:)
declare
function duf:create-ignore-file($path as xs:string) 
as element() {
  try {
    let $destFile := duf:append-to-path($path, ".ignore")
    return (
      file:write-text($destFile, ""),
      mbx:result(".ignore file created at: " || $path)
    )
  } catch * {
    mbx:error($err:code, $err:description, $err:module)
  }
};

(:~ Creates the directory specified by $dirPath. Does nothing if the
    directory already exists.

    Returns a single result..
:)
declare 
function duf:create-dir($dirPath as xs:string) 
as element() {
  try {
    let $dirExists := file:exists($dirPath) 
    return mbx:result(
      if ($dirExists) then 
        "Didn't create directory because " || $dirPath || " already exists."
      else (
        file:create-dir($dirPath),
        "Created directory at: " || $dirPath
      )
    )
  } catch * {
    mbx:error($err:code, $err:description, $err:module)
  }
};

(:~ Deletes a file or a directory specified by $path. 
    A directory will be deleted recursively (removes children).

    Returns a single result.
:)
declare 
function duf:delete-file-dir($path as xs:string) 
as element() {
  try {
    (: Only delete if the file or directory exists :)
    let $fileExists := file:exists($path)
    return mbx:result(
      if (not($fileExists)) then 
        "Couldn't delete " || $path || " because it doesn't exist." 
      else (
        file:delete($path, file:is-dir($path)),
        "Deleted file or dir: " || $path
      )
    )
  } catch * {
    mbx:error($err:code, $err:description, $err:module)
  }
};

(:~ Deletes all files and sub-directories located inside the directory
    specified by $path. 

    Returns multiple results.
:)
declare
function duf:delete-children($path as xs:string) 
as element() {
  try {
    let $isFile := file:is-file($path)
    return mbx:results(
      if ($isFile) then mbx:result(
        "Didn't delete children because" || $path || " is not a directory."
      )
      else (
        for $child in file:children($path) 
        return duf:delete-file-dir($child)
      )
    )
  } catch * {
    mbx:error($err:code, $err:description, $err:module)
  }
};

(:~ Appends $toAppend to $path with a directory separator in between :)
declare
function duf:append-to-path($path as xs:string, $toAppend as xs:string) 
as xs:string {
  $path || file:dir-separator() || $toAppend
};

(:~ Copies the directory specified by $srcPath to the directory specified by $destPath.
    Contents of $destPath will be erased before coping.
    If $delete is true, $dstPath will be deleted before copying.

    Returns multiple results
:)
declare
function duf:copy($srcPath as xs:string, $destPath as xs:string, $delete as xs:boolean) 
as element() {
  try {
    (: Before coping $srcPath to $dstPath, remove the target directory 
       if it already exists and create all required parent directories 
       (because otherwise an exception would occur if a file is copied and
        the parent directory does not exist).
    :)
    let $c := mbx:results((
      if ($delete) then (
        duf:delete-file-dir($destPath),
        duf:create-dir(file:parent($destPath))
      ) else mbx:result($destPath || " was not overwritten.")
    ))
    
    (: Attempt to copy otherwise return an error :)
    return (
      if (mberr:has-error($c)) then $c else (
        file:copy($srcPath, $destPath), 
        $c
      )
    )
  } catch * {
    mbx:error($err:code, $err:description, $err:module)
  }
};

(:
  Copies the contents of the directory specified in $srcPath into the directory specified by
  $dstPath. 
  This function does not copy the directory itself, instead it copies it's children.
  If $delete is set to true, the contents of $dstPath will be deleted before copying.

  Returns multiple results
:)
declare
function duf:copy-children($srcPath as xs:string, $destPath as xs:string, $delete as xs:boolean) 
as element() {
  try {
    if (file:exists($srcPath)) then (
      (:  Delete the children inside the destination directory
          before copying files. :)
      let $c := (
        if ($delete) then (
          duf:delete-children($destPath)
        ) else mbx:results(mbx:result(""))
      )

      return (
        if (mberr:has-error($c)) then $c else (
          (:  Iterate over every file inside directory specified by
              $srcPath and copy them to $destPath. :)
          mbx:results(
            (for $f in file:list($srcPath)
              let $srcPath := duf:append-to-path($srcPath, $f)
              let $destPath := duf:append-to-path($destPath, $f)
            return mbx:result(file:copy($srcPath, $destPath)),
            mberr:get-result($c)
            )
          )
        )
      )
    ) else mbx:results(mbx:result("Copying aborted because: " || $srcPath || " does not exist"))
  } catch * {
    mbx:error($err:code, $err:description, $err:module)
  }
};

(:
    Returns true if the directory specified in $dirPath
    is not empty. The function not count hidden files as
    files. 

    Returns a single result.
:)
declare
function duf:has-children($dirPath as xs:string)
as element() {
  try {
    if (file:is-file($dirPath)) then false() 
    else (
      (: Retrieve all non-hidden files :)
      let $c := (
        for $f in file:list($dirPath) 
        where substring(file:name($f),1,1) != '.'
        return $f
      ) 
      return mbx:result(count($c) > 0)
    )
  } catch * {
    mbx:error($err:code, $err:description, $err:module)
  }
};

(:
    List all files and directories found in the specified 
    $dirPath but ignores hidden files (filenames that have
    . as a prefix).

    $recursive and $pattern options are the same as the
    file:list() function.

    Returns a single result object with the following
    format:
      <Files>
        <file>FILE_NAME_1</file>
        ....
        <file>FILE_NAME_N</file>
      </Files>
:)
declare
function duf:list($dirPath as xs:string, $recursive as xs:boolean, $pattern as xs:string)
as element() {
  try {
    mbx:result(
      <Files>
      {
        for $f in file:list($dirPath, $recursive, $pattern)
        where substring(file:name($f),1,1) != '.'
        return <file>{$f}</file> 
      }
      </Files>
    )
  } catch * {
    mbx:error($err:code, $err:description, $err:module)
  }
};

(:~ 
    Reads and returns the value of the $key located inside the file specified
    in $filePath. The key and value must be sperated by a $delimeter.
:)
declare
function duf:value-of-key($filePath as xs:string, $key as xs:string, $delimeter as xs:string) 
as element() {
  try {
    (: Read the file if it exists and conver it into a sequence of lines :)
    let $fileLines := file:read-text-lines($filePath)
    
    (: Filter the sequence by removing any lines that do not contain the
       specified delimeter :)
    let $fileLines := fn:filter($fileLines, fn:contains(?,$delimeter))
    
    for $l in $fileLines
    return (
      (: Split the line using the delimeter :)
      let $s := fn:tokenize($l, $delimeter)

      (: Left hand side of delimeter is key, second 
         one is value :)
      let $k := fn:normalize-space($s[1])
      let $v := fn:normalize-space($s[2])
      
      where ($k = $key) return mbx:result($v)
    )
  } catch * {
    mbx:error($err:code, $err:description, $err:module)
  }
};