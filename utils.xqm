module namespace utils = 'http://in.tum.de/basex/modules/utils';

import module namespace file = 'http://expath.org/ns/file';


(:
    Returns the value of the key specified in $key. File must
    be a collection of key-value pairs separated by a $delimeter.
:)
declare
function utils:value-of-key($path as xs:string, $key as xs:string, $delimeter as xs:string) 
as xs:string {
    (: Read the file if it exists and conver it into a sequence of lines :)
    let $fileLines := file:read-text-lines($path)
    
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
      
      where ($k = $key) return normalize-space($v)
    )
};

declare
function utils:write-val($path as xs:string, $key as xs:string, $newVal as xs:string, $delimeter as xs:string) {
    
    (:  Functions that takes a $line as input. It splits
        the line into two parts using the $delimeter as
        the splitter and replaces the second part with
        $newVal. :)
    let $replace := function($line as xs:string) {
        let $s := fn:tokenize($line, $delimeter)
        return (
            if (compare($key, replace($s[1], " ", "")) = 0) 
                then $s[1] || $delimeter || " " || $newVal 
            else $line
        )
    }
    
    (:  Read $file, replace relevant lines, and write 
        updated values to file. :)
    return file:write-text-lines(
        $path,
        fn:for-each(
            file:read-text-lines($path), 
            $replace
        )
    )    
};

declare
function utils:copy($src as xs:string, $dst as xs:string)
as xs:string {
    if (file:exists($dst)) then
        "Skipped copying " || $src || " to " || $dst || " because it already exists."
    else (
        file:copy($src, $dst),
        "Copied from " || $src || " to " || $dst || " successfully."
    )
};

declare
function utils:write-xml($path as xs:string, $xml as document-node()) 
as xs:string {
    let $o := map { "method" : "xml" }
    let $w := file:write($path, $xml, $o)
    return "Wrote XML to " || $path
};